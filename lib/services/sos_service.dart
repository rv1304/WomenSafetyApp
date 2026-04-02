import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../app_config.dart';
import 'contact_service.dart';

/// Callback type for SOS status updates
typedef SosStatusCallback = void Function(String message);

/// Main SOS orchestration service.
/// Handles GPS capture, Twilio SMS/Call, fallback native SMS,
/// auto-escalation timer, and offline queueing.
class SosService {
  static final SosService _instance = SosService._internal();
  factory SosService() => _instance;
  SosService._internal();

  static const String _pendingAlertsKey = 'pending_sos_alerts';
  static const Duration _escalationDelay = Duration(minutes: 2);

  Timer? _escalationTimer;
  SosStatusCallback? onStatusUpdate;
  bool _isSendingSOS = false;

  bool get isSendingSOS => _isSendingSOS;

  // ---------------------------------------------------------------------------
  // MAIN ENTRY POINT — called from SOS button / voice trigger / volume key
  // ---------------------------------------------------------------------------
  Future<void> triggerSOS({
    SosStatusCallback? statusCallback,
    bool silentMode = false,
  }) async {
    if (_isSendingSOS) return;
    _isSendingSOS = true;
    onStatusUpdate = statusCallback;

    try {
      _report('📍 Capturing your location…');

      // 1. Get GPS coordinates
      Position? position = await _getLocation();
      String locationUrl = position != null
          ? 'https://maps.google.com/?q=${position.latitude},${position.longitude}'
          : 'Location unavailable';

      _report('📍 Location: ${position?.latitude.toStringAsFixed(4)}, ${position?.longitude.toStringAsFixed(4)}');

      // 2. Build SOS message
      final prefs = await SharedPreferences.getInstance();
      final customMsg =
          prefs.getString('custom_sos_message') ?? AppConfig.defaultSosMessage;
      final fullMessage = '$customMsg $locationUrl';

      // 3. Get contacts
      final contacts = await ContactService().getContacts();
      final phoneNumbers = contacts.map((c) => c['phone'] ?? '').where((p) => p.isNotEmpty).toList();

      // also include .env fallback contacts
      for (var env in AppConfig.emergencyContacts) {
        if (!phoneNumbers.contains(env)) phoneNumbers.add(env);
      }

      if (phoneNumbers.isEmpty) {
        _report('⚠️ No contacts configured! Opening native SMS…');
        await _fallbackNativeSMS(fullMessage, null);
        return;
      }

      // 4. Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      final hasInternet = connectivity != ConnectivityResult.none;

      if (!hasInternet) {
        _report('📵 No internet. Queuing alert for retry…');
        await _queueOfflineAlert(fullMessage, phoneNumbers);
        await _fallbackNativeSMS(fullMessage, phoneNumbers.first);
        return;
      }

      // 5. Send Twilio SMS + Call to each contact
      for (String phone in phoneNumbers) {
        _report('📨 Sending SMS to $phone…');
        bool smsSent = await _sendTwilioSMS(phone, fullMessage);
        if (smsSent) {
          _report('✅ SMS delivered to $phone');
        } else {
          _report('⚠️ SMS failed for $phone — using fallback…');
          await _fallbackNativeSMS(fullMessage, phone);
        }

        _report('📞 Calling $phone…');
        await _makeTwilioCall(phone);
        await Future.delayed(const Duration(seconds: 1));
      }

      // 6. Start escalation timer (2 min → call emergency services)
      _startEscalationTimer();

      _report('🆘 SOS sent to ${phoneNumbers.length} contacts! Escalation in 2 min if no response.');
    } catch (e) {
      debugPrint('SOS Error: $e');
      _report('❌ Error: $e');
    } finally {
      _isSendingSOS = false;
    }
  }

  // ---------------------------------------------------------------------------
  // CANCEL — stops escalation timer
  // ---------------------------------------------------------------------------
  void cancelSOS() {
    _escalationTimer?.cancel();
    _escalationTimer = null;
    _isSendingSOS = false;
    _report('✅ SOS cancelled. Stay safe!');
  }

  // ---------------------------------------------------------------------------
  // ACK — contact acknowledged; cancel escalation
  // ---------------------------------------------------------------------------
  void acknowledgeReceived() {
    _escalationTimer?.cancel();
    _escalationTimer = null;
    _report('✅ Contact acknowledged. Escalation cancelled.');
  }

  // ---------------------------------------------------------------------------
  // GPS
  // ---------------------------------------------------------------------------
  Future<Position?> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Location error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // TWILIO SMS
  // ---------------------------------------------------------------------------
  Future<bool> _sendTwilioSMS(String to, String body) async {
    try {
      final sid = AppConfig.twilioAccountSid;
      final token = AppConfig.twilioAuthToken;
      final from = AppConfig.twilioPhoneNumber;
      if (sid.isEmpty || token.isEmpty || from.isEmpty) return false;

      final auth = base64Encode(utf8.encode('$sid:$token'));
      final response = await http
          .post(
            Uri.parse(
                'https://api.twilio.com/2010-04-01/Accounts/$sid/Messages.json'),
            headers: {
              'Authorization': 'Basic $auth',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {'From': from, 'To': to, 'Body': body},
          )
          .timeout(const Duration(seconds: 15));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('Twilio SMS error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // TWILIO VOICE CALL
  // ---------------------------------------------------------------------------
  Future<void> _makeTwilioCall(String to) async {
    try {
      final sid = AppConfig.twilioAccountSid;
      final token = AppConfig.twilioAuthToken;
      final from = AppConfig.twilioPhoneNumber;
      final twimlUrl = AppConfig.twilioTwimlUrl;
      if (sid.isEmpty || token.isEmpty || from.isEmpty) return;

      final auth = base64Encode(utf8.encode('$sid:$token'));
      final response = await http
          .post(
            Uri.parse(
                'https://api.twilio.com/2010-04-01/Accounts/$sid/Calls.json'),
            headers: {
              'Authorization': 'Basic $auth',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {'From': from, 'To': to, 'Url': twimlUrl},
          )
          .timeout(const Duration(seconds: 15));
      debugPrint('Call to $to: ${response.statusCode}');
    } catch (e) {
      debugPrint('Twilio call error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // FALLBACK — Open native SMS app with pre-filled body
  // ---------------------------------------------------------------------------
  Future<void> _fallbackNativeSMS(String body, String? to) async {
    try {
      final uri = Uri(
        scheme: 'sms',
        path: to ?? '',
        queryParameters: {'body': body},
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Native SMS error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // AUTO-ESCALATION — If no contact responds in 2 min, call emergency services
  // ---------------------------------------------------------------------------
  void _startEscalationTimer() {
    _escalationTimer?.cancel();
    _escalationTimer = Timer(_escalationDelay, () async {
      _report('🚨 No response! Escalating to emergency services…');
      final emergencyNumber = AppConfig.escalationNumber;
      await _makeTwilioCall(emergencyNumber);
      final uri = Uri(scheme: 'tel', path: emergencyNumber);
      if (await canLaunchUrl(uri)) launchUrl(uri);
    });
  }

  // ---------------------------------------------------------------------------
  // OFFLINE QUEUEING
  // ---------------------------------------------------------------------------
  Future<void> _queueOfflineAlert(
      String message, List<String> phones) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingAlertsKey) ?? [];
    pending.add(jsonEncode({'message': message, 'phones': phones}));
    await prefs.setStringList(_pendingAlertsKey, pending);
  }

  /// Call this when connectivity is restored to retry queued alerts
  Future<void> retryPendingAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList(_pendingAlertsKey) ?? [];
    if (pending.isEmpty) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;

    for (final raw in List.from(pending)) {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final msg = data['message'] as String;
      final phones = (data['phones'] as List).cast<String>();
      for (final phone in phones) {
        await _sendTwilioSMS(phone, msg);
        await _makeTwilioCall(phone);
      }
    }
    await prefs.remove(_pendingAlertsKey);
    debugPrint('✅ Retried ${pending.length} queued SOS alerts');
  }

  void _report(String msg) {
    debugPrint('[SOS] $msg');
    onStatusUpdate?.call(msg);
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_config.dart';

class SafetyCheckScreen extends StatefulWidget {
  final int initialInterval; // Custom interval passed from settings

  SafetyCheckScreen({this.initialInterval = 15}); // Default to 15 seconds

  @override
  _SafetyCheckScreenState createState() => _SafetyCheckScreenState();
}

class _SafetyCheckScreenState extends State<SafetyCheckScreen> {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  int _attempts = 0;
  int _maxAttempts = 3;
  Timer? _timer;
  late int _notificationInterval; // Interval for notifications

  List<String> get emergencyContacts => AppConfig.emergencyContacts;

  @override
  void initState() {
    super.initState();
    _notificationInterval = widget.initialInterval; // Set initial interval
    _initializeNotifications();
    _startSafetyCheck();
  }

  void _initializeNotifications() async {
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initSettings =
        InitializationSettings(android: androidInitSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload == "yes") {
          _terminateProcess();
        } else if (response.payload == "no") {
          _handleNoResponse();
        }
      },
    );
  }

  void _startSafetyCheck() {
    _sendNotification();
  }

  Future<void> _sendNotification() async {
    _attempts++;

    if (_attempts > _maxAttempts) {
      _triggerSOS();
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'safety_channel', // Channel ID
      'Safety Check', // Channel Name
      importance: Importance.high,
      priority: Priority.high,
      fullScreenIntent: true,
      actions: [
        AndroidNotificationAction('yes', 'Yes', showsUserInterface: true),
        AndroidNotificationAction('no', 'No', showsUserInterface: true),
      ],
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      0,
      'Safety Check',
      'Are you safe?',
      notificationDetails,
      payload: 'waiting',
    );

    _timer = Timer(Duration(seconds: _notificationInterval), () {
      _sendNotification(); // Resend notification if no response
    });
  }

  void _handleNoResponse() {
    _timer?.cancel();
    _triggerSOS();
  }

  void _terminateProcess() {
    _timer?.cancel();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('User is safe. Process terminated.')),
    );
    print("User is safe. Process terminated.");
  }

  void _triggerSOS() {
    print("No response received after $_maxAttempts attempts. Triggering SOS...");
    for (String number in emergencyContacts) {
      _makeSOSCall(number);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SOS triggered to ${emergencyContacts.length} contacts!')),
    );
  }

  Future<void> _makeSOSCall(String number) async {
    final Uri url = Uri.parse("tel:$number");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      print("Could not launch $url");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to call $number')),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Safety Check'),
        backgroundColor: Color(0xFF5B21B6),
        foregroundColor: Color(0xFFFFFFFF),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Safety Check Running...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Notifications will be sent every $_notificationInterval seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Text(
              'Attempts: $_attempts / $_maxAttempts',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
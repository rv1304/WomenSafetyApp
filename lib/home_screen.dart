import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'app_config.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<Map<String, String>> safeContacts = [];
  bool _isSendingSOS = false;

  // Notification plugin
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _scheduleDailyNotification();
    _showTestNotification();
  }

  // Initialize notifications with iOS and Android support
  Future<void> _initializeNotifications() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings darwinInitSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: darwinInitSettings,
    );

    bool? initialized = await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint('Notification response received: ${response.payload}');
        if (response.payload == 'check') {
          _showSafetyCheckDialog();
        }
      },
    );
    debugPrint('Notifications initialized: $initialized');

    final iosPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      bool? granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('iOS notification permissions granted: $granted');
    }

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      bool? granted = await androidPlugin.requestNotificationsPermission();
      debugPrint('Android notification permissions granted: $granted');
    }
  }

  // Schedule daily notification at 1:05 AM (10 seconds for testing)
  Future<void> _scheduleDailyNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_safety_channel',
      'Daily Safety Check',
      channelDescription: 'Daily safety check notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    tz.TZDateTime scheduledTime =
        tz.TZDateTime.now(tz.local).add(Duration(seconds: 10));
    // For 1:05 AM production schedule, replace above with:
    // final now = tz.TZDateTime.now(tz.local);
    // tz.TZDateTime scheduledTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, 1, 5);

    await _notificationsPlugin.zonedSchedule(
      0,
      'Daily Safety Check',
      'Are you safe?',
      scheduledTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'check',
    );
    debugPrint('Notification scheduled for: $scheduledTime');
  }

  // Show safety check dialog
  Future<void> _showSafetyCheckDialog() async {
    if (!mounted) return;

    final bool? isSafe = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Safety Check'),
          content: Text('Are you safe?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Yes'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No'),
            ),
          ],
        );
      },
    );

    if (isSafe == false) {
      _scheduleEmergencyCall();
    }
  }

  // Schedule emergency call after 20 seconds (or 1:19 AM in production)
  Future<void> _scheduleEmergencyCall() async {
    tz.TZDateTime callTime =
        tz.TZDateTime.now(tz.local).add(Duration(seconds: 20));
    final durationUntilCall = callTime.difference(tz.TZDateTime.now(tz.local));
    await Future.delayed(durationUntilCall);
    await _sendSOSAlert();
    debugPrint('Emergency call triggered at: $callTime');
  }

  // Test notification to verify setup
  Future<void> _showTestNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notification',
      channelDescription: 'Test notification channel',
      importance: Importance.high,
      priority: Priority.high,
    );
    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      1,
      'Test Notification',
      'SafetyHub is active!',
      notificationDetails,
    );
    debugPrint('Test notification triggered');
  }

  Future<void> _sendSOSAlert() async {
    setState(() {
      _isSendingSOS = true;
    });

    try {
      final String message = 'EMERGENCY ALERT! I need help!';
      final List<String> emergencyNumbers = AppConfig.emergencyContacts;

      if (emergencyNumbers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No emergency contacts configured in .env!')),
        );
        return;
      }

      final String accountSid = AppConfig.twilioAccountSid;
      final String authToken = AppConfig.twilioAuthToken;
      final String twilioNumber = AppConfig.twilioPhoneNumber;
      final String basicAuth =
          base64Encode(utf8.encode('$accountSid:$authToken'));

      for (String number in emergencyNumbers) {
        // Send SMS
        var smsResponse = await http.post(
          Uri.parse(
              'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json'),
          headers: {
            'Authorization': 'Basic $basicAuth',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'From': twilioNumber,
            'To': number,
            'Body': message,
          },
        );
        debugPrint(
            'SMS to $number: Status ${smsResponse.statusCode}, Body ${smsResponse.body}');

        // Make Call
        var callResponse = await http.post(
          Uri.parse(
              'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Calls.json'),
          headers: {
            'Authorization': 'Basic $basicAuth',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'From': twilioNumber,
            'To': number,
            'Url':
                'https://handler.twilio.com/twiml/EH30ac234a3509bcde2c56b7fa1100b33f',
          },
        );
        debugPrint(
            'Call to $number: Status ${callResponse.statusCode}, Body ${callResponse.body}');

        await Future.delayed(Duration(seconds: 1));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('SOS alert sent to ${emergencyNumbers.length} contacts!')),
      );
      await Clipboard.setData(ClipboardData(text: message));
    } catch (e) {
      debugPrint('Error sending SOS: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending SOS: $e')),
      );
      await Clipboard.setData(
          ClipboardData(text: 'EMERGENCY ALERT! I need help!'));
    } finally {
      setState(() {
        _isSendingSOS = false;
      });
    }
  }

  void _showSOSModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Emergency Alert',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF020817)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Are you sure you want to send an emergency alert to your trusted contacts?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16, color: Color(0xFF5D616A), height: 1.4),
              ),
              if (_isSendingSOS)
                Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFF5F5F5),
                      foregroundColor: Color(0xFF5D616A),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSendingSOS
                        ? null
                        : () {
                            Navigator.of(context).pop();
                          },
                    child: Text('Cancel',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF5B21B6),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSendingSOS
                        ? null
                        : () async {
                            await _sendSOSAlert();
                            Navigator.of(context).pop();
                          },
                    child: Text(
                      'Confirm',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFFFFFF)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _shareLocationWithContacts() async {
    if (safeContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No safe contacts available! Add contacts in Network screen.')),
      );
      return;
    }

    for (var contact in safeContacts) {
      String message = 'Emergency Alert! I need help!';
      await Clipboard.setData(ClipboardData(text: message));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message copied for ${contact['name']}')),
      );
      await Future.delayed(Duration(seconds: 1));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Message shared with ${safeContacts.length} contacts!')),
    );
  }

  void _startSafetyCheck() {
    Navigator.pushNamed(context, '/safety');
  }

  void _onNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 1) {
      Navigator.pushNamed(context, '/route');
    } else if (index == 2) {
      Navigator.pushNamed(context, '/safety');
    } else if (index == 3) {
      Navigator.pushNamed(context, '/network').then((value) {
        if (value != null && value is List<Map<String, String>>) {
          setState(() {
            safeContacts = value;
          });
        }
      });
    } else if (index == 4) {
      Navigator.pushNamed(context, '/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SafetyHub',
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFFFFF)),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5B21B6), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none, color: Color(0xFFFFFFFF)),
            onPressed: () {},
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF8B5CF6),
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3F4F6), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _isSendingSOS ? null : _showSOSModal,
                  child: Container(
                    width: 140,
                    height: 140,
                    margin: EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0xFFEF4444), Color(0xFF991B1B)],
                        center: Alignment.center,
                        radius: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFEF4444).withValues(alpha: 0.5),
                          spreadRadius: 6,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isSendingSOS
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'SOS',
                              style: TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    ActionButton(
                      title: 'Share Message',
                      icon: Icons.share,
                      color: Color(0xFF5B21B6),
                      bgColor: Color(0xFFE0E7FF),
                      onTap: _shareLocationWithContacts,
                    ),
                    ActionButton(
                      title: 'Contacts',
                      icon: Icons.people,
                      color: Color(0xFF10B981),
                      bgColor: Color(0xFFD1FAE5),
                      onTap: () => _onNavTapped(3),
                    ),
                    ActionButton(
                      title: 'Safety Check',
                      icon: Icons.security,
                      color: Color(0xFF10B981),
                      bgColor: Color(0xFFD1FAE5),
                      onTap: _startSafetyCheck,
                    ),
                    ActionButton(
                      title: 'Route Planner',
                      icon: Icons.map,
                      color: Color(0xFF5B21B6),
                      bgColor: Color(0xFFE0E7FF),
                      onTap: () => Navigator.pushNamed(context, '/route'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trusted Contacts',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF020817),
                      ),
                    ),
                    SizedBox(height: 12),
                    if (safeContacts.isEmpty)
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Color(0xFF5D616A), size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No trusted contacts yet. Go to Network to add contacts.',
                                style: TextStyle(
                                    fontSize: 14, color: Color(0xFF5D616A)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...safeContacts
                          .map((contact) => ContactCard(
                                name: contact['name']!,
                                phone: contact['phone'] ?? '',
                                relation: 'Safe Contact',
                              ))
                          .toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Color(0xFFFFFFFF),
        selectedItemColor: Color(0xFF5B21B6),
        unselectedItemColor: Color(0xFF5D616A),
        showUnselectedLabels: true,
        elevation: 8,
        currentIndex: _selectedIndex,
        onTap: _onNavTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Routes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security_outlined),
            label: 'Safety',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'Network',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action Button Widget
// ---------------------------------------------------------------------------
class ActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const ActionButton({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2),
              spreadRadius: 2,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    spreadRadius: 1,
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5D616A),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contact Card Widget
// ---------------------------------------------------------------------------
class ContactCard extends StatelessWidget {
  final String name;
  final String phone;
  final String relation;

  const ContactCard({
    Key? key,
    required this.name,
    required this.phone,
    required this.relation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFE0E7FF),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5B21B6),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF020817),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  phone.isNotEmpty ? phone : relation,
                  style: TextStyle(fontSize: 14, color: Color(0xFF5D616A)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.phone, color: Color(0xFF5B21B6)),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
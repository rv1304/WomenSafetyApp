import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central configuration loaded from the .env file at startup.
/// All API keys, secrets, and configurable values live here.
class AppConfig {
  // ---------------------------------------------------------------------------
  // Twilio — SMS & Voice calls for SOS
  // ---------------------------------------------------------------------------
  static String get twilioAccountSid =>
      dotenv.env['TWILIO_ACCOUNT_SID'] ?? '';

  static String get twilioAuthToken =>
      dotenv.env['TWILIO_AUTH_TOKEN'] ?? '';

  static String get twilioPhoneNumber =>
      dotenv.env['TWILIO_PHONE_NUMBER'] ?? '';

  /// TwiML Bin URL that Twilio calls to get the emergency voice message
  static String get twilioTwimlUrl =>
      dotenv.env['TWILIO_TWIML_URL'] ??
      'http://twimlets.com/message?Message%5B0%5D=This+is+an+emergency+alert.+Please+help+immediately.';

  // ---------------------------------------------------------------------------
  // Geoapify — Route mapping
  // ---------------------------------------------------------------------------
  static String get geoapifyApiKey =>
      dotenv.env['GEOAPIFY_API_KEY'] ?? '';

  // ---------------------------------------------------------------------------
  // Emergency Contacts (from .env — fallback if SharedPrefs empty)
  // ---------------------------------------------------------------------------
  static List<String> get emergencyContacts {
    final List<String> contacts = [];
    int i = 1;
    while (dotenv.env.containsKey('EMERGENCY_CONTACT_$i')) {
      final contact = dotenv.env['EMERGENCY_CONTACT_$i']!;
      if (contact.isNotEmpty) contacts.add(contact);
      i++;
    }
    return contacts;
  }

  // ---------------------------------------------------------------------------
  // Custom SOS Message (overridable in Settings screen)
  // ---------------------------------------------------------------------------
  static String get defaultSosMessage =>
      dotenv.env['DEFAULT_SOS_MESSAGE'] ??
      '🚨 EMERGENCY ALERT! I need immediate help! My location: ';

  // ---------------------------------------------------------------------------
  // Escalation number — called if no contact acknowledges in 2 min
  // ---------------------------------------------------------------------------
  static String get escalationNumber =>
      dotenv.env['ESCALATION_NUMBER'] ?? '100'; // 100 = Police India

  // ---------------------------------------------------------------------------
  // Validation helper — call on startup to warn about missing keys
  // ---------------------------------------------------------------------------
  static List<String> validateConfig() {
    final List<String> missing = [];
    if (twilioAccountSid.isEmpty) missing.add('TWILIO_ACCOUNT_SID');
    if (twilioAuthToken.isEmpty) missing.add('TWILIO_AUTH_TOKEN');
    if (twilioPhoneNumber.isEmpty) missing.add('TWILIO_PHONE_NUMBER');
    if (emergencyContacts.isEmpty) missing.add('EMERGENCY_CONTACT_1');
    return missing;
  }
}

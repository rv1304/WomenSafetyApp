import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_config.dart';
import 'home_screen.dart' as home;
import 'language_screen.dart' as lang;
import 'login_screen.dart' as login;
import 'signup_screen.dart' as signup;
import 'profile_screen.dart' as profile;
import 'starting_page.dart' as start;
import 'network_screen.dart';
import 'route_screen.dart';
import 'safety_check_settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file
  await dotenv.load(fileName: '.env');

  // Warn in debug mode if any keys are missing
  final missingKeys = AppConfig.validateConfig();
  if (missingKeys.isNotEmpty) {
    debugPrint(
      '⚠️  WARNING: Missing .env keys: ${missingKeys.join(', ')}',
    );
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafetyHub',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => start.StartingPage(),
        '/home': (context) => home.HomeScreen(),
        '/language': (context) => lang.LanguageScreen(),
        '/login': (context) => login.LoginScreen(),
        '/signup': (context) => signup.SignupScreen(),
        '/profile': (context) => profile.ProfileScreen(),
        '/route': (context) => RouteScreen(),
        '/network': (context) => NetworkScreen(),
        '/safety': (context) => SafetyCheckScreen(),
      },
    );
  }
}
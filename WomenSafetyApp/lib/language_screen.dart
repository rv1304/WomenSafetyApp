import 'package:flutter/material.dart';

class LanguageScreen extends StatefulWidget {
  @override
  _LanguageScreenState createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String? selectedLanguage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF5B21B6), Color(0xFF8B5CF6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Select Language',
                  style: Theme.of(context).textTheme.headlineLarge!.copyWith(color: Colors.white),
                ),
                SizedBox(height: 40),
                _buildLanguageOption('English'),
                SizedBox(height: 16),
                _buildLanguageOption('Español'),
                SizedBox(height: 16),
                _buildLanguageOption('Français'),
                SizedBox(height: 40),
                ElevatedButton(
                  onPressed: selectedLanguage != null
                      ? () => Navigator.pushReplacementNamed(context, '/login')
                      : null,
                  child: Text('Continue', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language) {
    bool isSelected = selectedLanguage == language;
    return GestureDetector(
      onTap: () => setState(() => selectedLanguage = language),
      child: Card(
        elevation: isSelected ? 12 : 8,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                language,
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: isSelected ? Color(0xFF5B21B6) : Color(0xFF5D616A),
                    ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: Color(0xFF5B21B6)),
            ],
          ),
        ),
      ),
    );
  }
}
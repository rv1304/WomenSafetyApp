import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

class ProfileScreen extends StatelessWidget {
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  SizedBox(height: 30),
                  Center(
                    child: SizedBox(
                      width: double.infinity,
                      child: _buildProfileCard(context),
                    ),
                  ),
                  SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: _buildOptionsContainer(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Ionicons.arrow_back_outline, color: Color(0xFFFFFFFF), size: 28),
          onPressed: () {
            Navigator.pushNamed(context, '/home');
          },
        ),
        Text(
          'Profile',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFFFFF),
          ),
        ),
        IconButton(
          icon: Icon(Ionicons.settings_outline, color: Color(0xFFFFFFFF), size: 28),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: Color(0xFFFFFFFF),
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Color(0xFFF3F4F6),
              child: Icon(
                Ionicons.person_outline,
                size: 60,
                color: Color(0xFF5D616A),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'John Doe',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF020817),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'johndoe@example.com',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF5D616A),
                fontStyle: FontStyle.italic,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF5B21B6),
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              onPressed: () {},
              child: Text(
                'Edit Profile',
                style: TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsContainer(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: Color(0xFFFFFFFF),
      child: Container(
        padding: EdgeInsets.all(8),
        child: Column(
          children: [
            _buildProfileOption(Ionicons.person_outline, 'Account Details'),
            Divider(height: 1, color: Color(0xFFE5E7EB)),
            _buildProfileOption(Ionicons.lock_closed_outline, 'Privacy Settings'),
            Divider(height: 1, color: Color(0xFFE5E7EB)),
            _buildProfileOption(Ionicons.notifications_outline, 'Notifications'),
            Divider(height: 1, color: Color(0xFFE5E7EB)),
            _buildProfileOption(Ionicons.help_circle_outline, 'Help & Support'),
            Divider(height: 1, color: Color(0xFFE5E7EB)),
            _buildProfileOption(
              Ionicons.log_out_outline,
              'Logout',
              color: Color(0xFFEF4444),
              onTap: () {
                Navigator.pushNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
    );
  }

  static const Color _defaultTextColor = Color(0xFF5D616A);

  Widget _buildProfileOption(IconData icon, String text,
      {Color color = _defaultTextColor, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 24),
      title: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Color(0xFF5D616A),
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      onTap: onTap,
    );
  }
}
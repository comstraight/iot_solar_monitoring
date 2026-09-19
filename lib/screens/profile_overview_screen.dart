import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'editable_profile_screen.dart';

// --- DATA MODEL ---
class ProfileData extends ChangeNotifier {
  String name = 'Andrei Esporlas';
  String role = 'Solar Telemetry Administrator';
  String email = 'andrei@example.com';
  String phone = '+63 912 345 6789';
  String userId = '423002684';

  void updateProfile(
    String newName,
    String newEmail,
    String newPhone,
    String newUserId,
  ) {
    name = newName;
    email = newEmail;
    phone = newPhone;
    userId = newUserId;
    notifyListeners();
  }
}

// --- ENTRY POINT ---
void main() {
  runApp(
    ChangeNotifierProvider<ProfileData>(
      create: (_) => ProfileData(),
      builder: (context, _) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ProfileOverviewScreen(),
      ),
    ),
  );
}

// ==================== 1. PROFILE OVERVIEW SCREEN ====================
class ProfileOverviewScreen extends StatelessWidget {
  final ProfileData? profile;
  final VoidCallback? onEditPressed;

  const ProfileOverviewScreen({super.key, this.profile, this.onEditPressed});

  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color borderGreen = Color(0xFF20341E);
  static const Color lightGreenBg = Color(0xFFE8F5E9);
  static const Color pageBg = Colors.white;

  @override
  Widget build(BuildContext context) {
    ProfileData profile;
    if (this.profile != null) {
      profile = this.profile!;
    } else {
      try {
        profile = context.watch<ProfileData>();
      } catch (_) {
        profile = ProfileData();
      }
    }

    return Scaffold(
      backgroundColor: pageBg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildTopHeader(context),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // USER SUMMARY CARD
                _buildFloatingCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: lightGreenBg,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: darkGreen,
                              child: Text(
                                _getInitials(profile.name),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  profile.role,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                _buildSectionHeader('Personal Information'),

                // DETAILED INFO CARD
                _buildFloatingCard(
                  children: [
                    _buildInfoListTile(
                      icon: CupertinoIcons.mail_solid,
                      label: 'EMAIL ADDRESS',
                      value: profile.email,
                    ),
                    _buildDivider(),
                    _buildInfoListTile(
                      icon: CupertinoIcons.phone_fill,
                      label: 'PHONE NUMBER',
                      value: profile.phone,
                    ),
                    _buildDivider(),
                    _buildInfoListTile(
                      icon: CupertinoIcons.person_badge_minus_fill,
                      label: 'STUDENT / USER ID',
                      value: profile.userId,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ACTION BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed:
                        onEditPressed ??
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const EditableProfileScreen(),
                            ),
                          );
                        },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Edit Profile Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }

  Widget _buildTopHeader(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 16,
        left: 16,
        right: 16,
        bottom: 25,
      ),
      decoration: const BoxDecoration(
        color: darkGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        gradient: LinearGradient(
          colors: [darkGreen, midGreen],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.38, 1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Back',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: borderGreen, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      CupertinoIcons.chevron_left,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Account Profile',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            'Personal identity details & credentials',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 18, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoListTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: lightGreenBg.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: midGreen, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: darkGreen,
        ),
      ),
    );
  }

  Widget _buildFloatingCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Colors.grey.withValues(alpha: 0.2),
    );
  }
}

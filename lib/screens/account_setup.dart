import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class AccountSetupScreen extends StatefulWidget {
  const AccountSetupScreen({super.key});

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  // Theme Color Constants matching design guide
  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color pageBg = Color(0xFFF8FAF8);
  static const Color cardBg = Colors.white;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isNameFilled = false;
  bool _isNameReadOnly = false;
  bool _isContactReadOnly = false;
  bool _isEmailReadOnly = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _nameController.addListener(() {
      setState(() {
        _isNameFilled = _nameController.text.trim().isNotEmpty;
      });
    });
  }

  // Read existing profile data from Firestore & Auth if available
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.email != null && user.email!.isNotEmpty) {
        _emailController.text = user.email!;
        _isEmailReadOnly = true;
      }
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        _contactController.text = user.phoneNumber!;
        _isContactReadOnly = true;
      }
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        _nameController.text = user.displayName!;
        _isNameReadOnly = true;
      }

      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          if (data['name'] != null &&
              data['name'].toString().trim().isNotEmpty) {
            _nameController.text = data['name'];
            _isNameReadOnly = true;
          }
          if (data['phone'] != null &&
              data['phone'].toString().trim().isNotEmpty) {
            _contactController.text = data['phone'];
            _isContactReadOnly = true;
          }
          if (data['email'] != null &&
              data['email'].toString().trim().isNotEmpty) {
            _emailController.text = data['email'];
            _isEmailReadOnly = true;
          }
        }
      } catch (_) {}
      setState(() {
        _isNameFilled = _nameController.text.trim().isNotEmpty;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // Write profile data to Firestore & Auth securely and navigate to Home
  Future<void> _onSaveAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.updateDisplayName(_nameController.text.trim());
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': _nameController.text.trim(),
          'phone': _contactController.text.trim(),
          'email': _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : (user.email ?? ''),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Welcome, ${_nameController.text.trim()}!',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Navigate to Home Screen after completing setup
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) =>
            const HomeScreen(currentPercentage: 20, cardCount: 1),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: Stack(
        children: [
          // ==================== 1. GREEN HERO HEADER ====================
          Container(
            width: double.infinity,
            height: 250,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
            decoration: const BoxDecoration(
              color: darkGreen,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
              gradient: LinearGradient(
                colors: [darkGreen, midGreen],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Row(
                children: [
                  if (Navigator.canPop(context))
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Account Setup',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: darkGreen,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ==================== 2. MAIN CARD CONTENT ====================
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 110),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PROFILE DETAILS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // --- REQUIRED FIELD ---
                          _buildModernTextField(
                            controller: _nameController,
                            label: 'Full Name *',
                            hint: 'e.g., Alex Morgan',
                            icon: Icons.person_rounded,
                            enabled: !_isNameReadOnly,
                          ),
                          const SizedBox(height: 24),

                          Divider(color: Colors.grey.shade200, height: 1),
                          const SizedBox(height: 24),

                          // --- OPTIONAL FIELDS (BOTTOM) ---
                          _buildModernTextField(
                            controller: _contactController,
                            label: 'Contact Number (Optional)',
                            hint: 'e.g., +1 555-0199',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                            enabled: !_isContactReadOnly,
                          ),
                          const SizedBox(height: 16),

                          _buildModernTextField(
                            controller: _emailController,
                            label: 'Email Address (Optional)',
                            hint: 'e.g., alex@example.com',
                            icon: Icons.email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_isEmailReadOnly,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ==================== 3. BOTTOM BUTTON ====================
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isNameFilled
                            ? midGreen
                            : Colors.grey.shade300,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: _isNameFilled ? _onSaveAccount : null,
                      child: Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isNameFilled
                              ? Colors.white
                              : Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: enabled ? darkGreen : Colors.grey.shade600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: enabled ? Colors.grey.shade700 : Colors.grey.shade500,
          fontSize: 14,
        ),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(
          icon,
          color: enabled ? midGreen : Colors.grey,
          size: 22,
        ),
        filled: true,
        fillColor: enabled ? const Color(0xFFF4F7F4) : Colors.grey.shade200,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: midGreen, width: 1.5),
        ),
      ),
    );
  }
}

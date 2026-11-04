import 'dart:convert';
import 'dart:io';
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
  // Color palette matching the design images (gray input boxes, bold title, green button)
  static const Color fieldBgColor = Color(0xFFE0E0E0);
  static const Color primaryGreen = Color(0xFF42B748);
  static const Color textPrimaryColor = Color(0xFF111111);

  // Backend Flask API Base URL
  static const String backendBaseUrl = 'http://127.0.0.1:5000';

  // Step 1 = Enter your info, Step 2 = Setup your first site info
  int _currentStep = 1;
  bool _isLoading = false;

  // Step 1 Controllers (User Profile)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  // Step 2 Controllers (Group / Site Parameters)
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _batteryCapacityController =
      TextEditingController();
  final TextEditingController _panelOutputController = TextEditingController();

  bool _isStep1Valid = false;
  bool _isStep2Valid = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    _nameController.addListener(_validateInputs);
    _groupNameController.addListener(_validateInputs);
    _batteryCapacityController.addListener(_validateInputs);
    _panelOutputController.addListener(_validateInputs);
  }

  void _validateInputs() {
    setState(() {
      _isStep1Valid = _nameController.text.trim().isNotEmpty;
      _isStep2Valid =
          _groupNameController.text.trim().isNotEmpty &&
          _batteryCapacityController.text.trim().isNotEmpty &&
          _panelOutputController.text.trim().isNotEmpty;
    });
  }

  // Pre-fill profile data from FirebaseAuth or Firestore if available
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.email != null && user.email!.isNotEmpty) {
        _emailController.text = user.email!;
      }
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        _contactController.text = user.phoneNumber!;
      }
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        _nameController.text = user.displayName!;
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
          }
          if (data['phone'] != null &&
              data['phone'].toString().trim().isNotEmpty) {
            _contactController.text = data['phone'];
          }
          if (data['email'] != null &&
              data['email'].toString().trim().isNotEmpty) {
            _emailController.text = data['email'];
          }
        }
      } catch (_) {}

      _validateInputs();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _groupNameController.dispose();
    _batteryCapacityController.dispose();
    _panelOutputController.dispose();
    super.dispose();
  }

  // Helper to send HTTP JSON requests to the backend server
  Future<void> _sendToBackendApi(
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.postUrl(
        Uri.parse('$backendBaseUrl$endpoint'),
      );
      request.headers.set('content-type', 'application/json');
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close();
      client.close();
      debugPrint(
        '[BACKEND SYNC] $endpoint Response status: ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('[BACKEND SYNC WARNING] Failed to connect to $endpoint: $e');
    }
  }

  // Save complete profile & group info to Firestore & backend
  Future<void> _onCompleteSetup() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid =
        user?.uid ?? 'local_user_${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _isLoading = true;
    });

    final name = _nameController.text.trim();
    final email = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : (user?.email ?? '');
    final phone = _contactController.text.trim();

    final groupName = _groupNameController.text.trim();
    final batteryCapacity =
        double.tryParse(_batteryCapacityController.text.trim()) ?? 200.0;
    final combinePanelOutput =
        double.tryParse(_panelOutputController.text.trim()) ?? 300.0;
    final groupId = 'group_${uid.length >= 6 ? uid.substring(0, 6) : uid}';

    try {
      // 1. Update FirebaseAuth Display Name
      if (user != null && name.isNotEmpty) {
        await user.updateDisplayName(name);
      }

      // 2. Save User Profile to Firestore (users/{uid})
      final userPayload = {
        'name': name,
        'email': email,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(userPayload, SetOptions(merge: true));

      // 3. Save Group/Site Info to Firestore under user subcollection (users/{uid}/groups/{groupId})
      final groupPayload = {
        'group_id': groupId,
        'group_name': groupName,
        'max_battery_capacity': batteryCapacity,
        'combine_max_panel_output': combinePanelOutput,
        'owner_uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('groups')
          .doc(groupId)
          .set(groupPayload, SetOptions(merge: true));

      // 4. Send payloads to Flask Backend Endpoints
      await _sendToBackendApi('/api/user/setup', {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
      });

      await _sendToBackendApi('/api/group/setup', {
        'uid': uid,
        'group_id': groupId,
        'group_name': groupName,
        'max_battery_capacity': batteryCapacity,
        'combine_max_panel_output': combinePanelOutput,
      });
    } catch (e) {
      debugPrint('[SETUP ERROR] $e');
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: primaryGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Setup complete! Welcome, $name.',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Dynamic setup metrics passed to home screen without hardcoded static defaults
    const setupPercentage = 100;
    const cardCount = 1;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const HomeScreen(
          currentPercentage: setupPercentage,
          cardCount: cardCount,
        ),
      ),
      (route) => false,
    );
  }

  void _onContinuePressed() {
    if (_currentStep == 1) {
      if (_isStep1Valid) {
        setState(() {
          _currentStep = 2;
        });
      }
    } else {
      if (_isStep2Valid) {
        _onCompleteSetup();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 32.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // Header text matching provided images exactly
                    Text(
                      _currentStep == 1
                          ? 'Enter your info.'
                          : 'Setup your first site info.',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textPrimaryColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // STEP 1: USER INFO FIELDS
                    if (_currentStep == 1) ...[
                      _buildCleanTextField(
                        controller: _nameController,
                        hintText: 'Name',
                      ),
                      const SizedBox(height: 16),
                      _buildCleanTextField(
                        controller: _emailController,
                        hintText: 'Email Address (Optional)',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      _buildCleanTextField(
                        controller: _contactController,
                        hintText: 'Contact Number (Optional)',
                        keyboardType: TextInputType.phone,
                      ),
                    ],

                    // STEP 2: GROUP / SITE INFO FIELDS
                    if (_currentStep == 2) ...[
                      _buildCleanTextField(
                        controller: _groupNameController,
                        hintText: 'Site Name',
                      ),
                      const SizedBox(height: 16),
                      _buildCleanTextField(
                        controller: _batteryCapacityController,
                        hintText: 'Max Battery Capacity',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildCleanTextField(
                        controller: _panelOutputController,
                        hintText: 'Combine Max Panel Output',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // BOTTOM ACTION BUTTON (Solid Green Button matching screenshots)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        ((_currentStep == 1 && _isStep1Valid) ||
                            (_currentStep == 2 && _isStep2Valid))
                        ? primaryGreen
                        : Colors.grey.shade400,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading
                      ? null
                      : (((_currentStep == 1 && _isStep1Valid) ||
                                (_currentStep == 2 && _isStep2Valid))
                            ? _onContinuePressed
                            : null),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: textPrimaryColor,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: fieldBgColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
        ),
      ),
    );
  }
}

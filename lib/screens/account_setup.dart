import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'home_screen.dart';

// =============================================================================
// CONFIGURATION & ENVIRONMENT
// =============================================================================
abstract class AppConfig {
  static const Duration networkTimeout = Duration(seconds: 12);
}

// =============================================================================
// DATA LAYER & SERVICE
// =============================================================================
class AccountSetupService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final http.Client _httpClient;

  AccountSetupService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    http.Client? httpClient,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _httpClient = httpClient ?? http.Client();

  /// Dispose client when service lifecycle ends
  void dispose() {
    _httpClient.close();
  }

  /// Fetches cached or server user profile securely via standard SDK cache-first handling
  Future<Map<String, dynamic>?> fetchUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      debugPrint('[AccountSetupService] Firestore fetch error: $e');
      return null;
    }
  }

  /// Saves user personal information directly to Firestore
  Future<void> saveUserProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'NO_USER',
        message: 'User session expired. Please re-authenticate.',
      );
    }

    final uid = user.uid;
    final userRef = _firestore.collection('users').doc(uid);

    // Commit personal info to Firestore
    await userRef.set({
      'name': name,
      'email': email,
      'phone': phone,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Update Auth Profile Display Name
    if (name.isNotEmpty && user.displayName != name) {
      await user.updateProfile(displayName: name);
    }
  }
}

// =============================================================================
// PRESENTATION / UI LAYER
// =============================================================================
class AccountSetupScreen extends StatefulWidget {
  const AccountSetupScreen({super.key});

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  // Theme Constants
  static const Color fieldBgColor = Color(0xFFF2F2F7);
  static const Color primaryGreen = Color(0xFF42B748);
  static const Color textPrimaryColor = Color(0xFF111111);
  static const Color disabledButtonColor = Color(0xFFBDBDBD);
  static const Color hintTextColor = Color(0xFF757575);

  static const OutlineInputBorder _defaultBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide.none,
  );

  static const OutlineInputBorder _focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: primaryGreen, width: 1.5),
  );

  static const RoundedRectangleBorder _buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  // Email Validation Regex
  static final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );

  late final AccountSetupService _setupService;

  bool _isLoading = false;
  bool _isProfileHydrated = false;

  // Form Controllers (Site and hardware controllers removed)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _setupService = AccountSetupService();

    _loadInitialUserData();

    _nameController.addListener(_validateInputs);
    _emailController.addListener(_validateInputs);
    _contactController.addListener(_validateInputs);
  }

  Future<void> _loadInitialUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (user.email != null && user.email!.isNotEmpty) {
      _emailController.text = user.email!;
    }
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      _contactController.text = user.phoneNumber!;
    }
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      _nameController.text = user.displayName!;
    }

    final profile = await _setupService.fetchUserProfile(user.uid);
    if (profile != null && mounted && !_isProfileHydrated) {
      if (_nameController.text.isEmpty && profile['name'] != null) {
        _nameController.text = profile['name'].toString().trim();
      }
      if (_contactController.text.isEmpty && profile['phone'] != null) {
        _contactController.text = profile['phone'].toString().trim();
      }
      if (_emailController.text.isEmpty && profile['email'] != null) {
        _emailController.text = profile['email'].toString().trim();
      }
      _isProfileHydrated = true;
    }

    _validateInputs();
  }

  void _validateInputs() {
    final nameVal = _nameController.text.trim();
    final emailVal = _emailController.text.trim();

    final isEmailValid = emailVal.isEmpty || _emailRegExp.hasMatch(emailVal);
    final newFormValid = nameVal.isNotEmpty && isEmailValid;

    if (_isFormValid != newFormValid) {
      if (!mounted) return;
      setState(() {
        _isFormValid = newFormValid;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _setupService.dispose();
    super.dispose();
  }

  Future<void> _onCompleteSetup() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    final name = _nameController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    final email = _emailController.text.trim().isNotEmpty
        ? _emailController.text.trim()
        : (user?.email ?? '');
    final phone = _contactController.text.trim();

    try {
      await _setupService.saveUserProfile(
        name: name,
        email: email,
        phone: phone,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: primaryGreen,
          shape: _buttonShape,
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

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) =>
              const HomeScreen(currentPercentage: 100, cardCount: 1),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      final errorMessage = e is TimeoutException
          ? 'Network request timed out. Please check your connection.'
          : 'Failed to complete setup. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 32.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter your info.',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textPrimaryColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          hintText: 'Name',
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _emailController,
                          hintText: 'Email Address (Optional)',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _contactController,
                          hintText: 'Contact Number (Optional)',
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (_isFormValid && !_isLoading) {
                              _onCompleteSetup();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: _isFormValid ? primaryGreen : disabledButtonColor,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    shape: _buttonShape,
                  ),
                  onPressed: _isLoading
                      ? null
                      : (_isFormValid ? _onCompleteSetup : null),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isLoading
                        ? const SizedBox(
                            key: ValueKey('loading'),
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Continue',
                            key: ValueKey('text'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    bool enableSuggestions = true,
    bool autocorrect = true,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      enableSuggestions: enableSuggestions,
      autocorrect: autocorrect,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: textPrimaryColor,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: hintTextColor,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: fieldBgColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: _defaultBorder,
        enabledBorder: _defaultBorder,
        focusedBorder: _focusedBorder,
      ),
    );
  }
}

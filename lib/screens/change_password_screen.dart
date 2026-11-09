import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final _uppercaseRegex = RegExp(r'[A-Z]');
final _lowercaseRegex = RegExp(r'[a-z]');

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final ValueNotifier<bool> _isCurrentPasswordVisible = ValueNotifier(false);
  final ValueNotifier<bool> _isNewPasswordVisible = ValueNotifier(false);
  final ValueNotifier<bool> _isConfirmPasswordVisible = ValueNotifier(false);

  bool _isLoading = false;

  // Real-time password requirement tracker states
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;

  // Extracted constants
  static const int _minPasswordLength = 8;
  static const String _passwordProviderId = 'password';

  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color lightGreenBg = Color(0xFFE8F5E9);
  static const Color snackBarSuccessColor = Color(0xFF00FF22);

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_updatePasswordStrength);
  }

  void _updatePasswordStrength() {
    final text = _newPasswordController.text;
    final minLengthMet = text.length >= _minPasswordLength;
    final upperMet = _uppercaseRegex.hasMatch(text);
    final lowerMet = _lowercaseRegex.hasMatch(text);

    if (_hasMinLength != minLengthMet ||
        _hasUppercase != upperMet ||
        _hasLowercase != lowerMet) {
      setState(() {
        _hasMinLength = minLengthMet;
        _hasUppercase = upperMet;
        _hasLowercase = lowerMet;
      });
    }
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_updatePasswordStrength);
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _isCurrentPasswordVisible.dispose();
    _isNewPasswordVisible.dispose();
    _isConfirmPasswordVisible.dispose();
    super.dispose();
  }

  Future<void> _handleSavePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null || user.email == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('No active user session found.', isError: true);
        }
        return;
      }

      final isEmailUser = user.providerData.any(
        (p) => p.providerId == _passwordProviderId,
      );
      if (!isEmailUser) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar(
            'This account uses social sign-in and cannot change password here.',
            isError: true,
          );
        }
        return;
      }

      final currentPassword = _currentPasswordController.text;
      final newPassword = _newPasswordController.text;

      if (currentPassword == newPassword) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar(
            'New password cannot be the same as current password.',
            isError: true,
          );
        }
        return;
      }

      // Re-authenticate & update in Firebase Auth
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      // Record password change timestamp in Firestore synced with server.py schema
      final nowTimestamp = FieldValue.serverTimestamp();
      try {
        final batch = FirebaseFirestore.instance.batch();

        final userDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        batch.set(userDocRef, {
          'passwordLastChanged': nowTimestamp,
          'password_timestamp': nowTimestamp,
          'updatedAt': nowTimestamp,
        }, SetOptions(merge: true));

        final statusDocRef = FirebaseFirestore.instance
            .collection('system_status')
            .doc('current');
        batch.set(statusDocRef, {
          'account_info': {'password_timestamp': nowTimestamp},
        }, SetOptions(merge: true));

        await batch.commit();
      } catch (e) {
        debugPrint('Firestore timestamp update failed: $e');
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'passwordLastChanged': nowTimestamp,
                'password_timestamp': nowTimestamp,
                'updatedAt': nowTimestamp,
              }, SetOptions(merge: true));
        } catch (innerError) {
          debugPrint('Firestore fallback set failed: $innerError');
        }
      }

      // Trigger OS password manager update prompt
      TextInput.finishAutofillContext();

      if (!mounted) return;
      setState(() => _isLoading = false);

      _showSnackBar('Password updated successfully!');

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      final String errorMessage = switch (e.code) {
        'wrong-password' ||
        'invalid-credential' => 'Current password is incorrect.',
        'weak-password' => 'The new password provided is too weak.',
        'requires-recent-login' =>
          'Session expired. Please log out and log in again.',
        'network-request-failed' =>
          'Network error. Please check your connection.',
        'too-many-requests' => 'Too many requests. Please try again later.',
        _ => e.message ?? 'Failed to update password. Please try again.',
      };

      _showSnackBar(errorMessage, isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('An unexpected error occurred.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red[800] : darkGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            Icon(
              isError
                  ? CupertinoIcons.exclamationmark_circle_fill
                  : CupertinoIcons.checkmark_circle_fill,
              color: isError ? Colors.white : snackBarSuccessColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityToggle(bool visible, VoidCallback onTap) {
    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          visible ? CupertinoIcons.eye_fill : CupertinoIcons.eye_slash_fill,
          key: ValueKey<bool>(visible),
          color: Colors.grey,
          size: 18,
        ),
      ),
      onPressed: onTap,
    );
  }

  Widget _buildRequirementPill(String label, bool isMet) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isMet
            ? midGreen.withOpacity(0.12)
            : Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMet ? midGreen : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isMet
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              key: ValueKey<bool>(isMet),
              size: 12,
              color: isMet ? midGreen : Colors.grey,
            ),
          ),
          const SizedBox(width: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 10,
              fontWeight: isMet ? FontWeight.bold : FontWeight.normal,
              color: isMet ? darkGreen : Colors.grey[600],
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _HeaderWidget(topPadding: topPadding),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Update Credentials',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 1,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _InputLabel(text: 'CURRENT PASSWORD'),
                            const SizedBox(height: 6),
                            ValueListenableBuilder<bool>(
                              valueListenable: _isCurrentPasswordVisible,
                              builder: (context, visible, _) {
                                return TextFormField(
                                  controller: _currentPasswordController,
                                  obscureText: !visible,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  keyboardType: TextInputType.visiblePassword,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.password],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  decoration: _buildInputDecoration(
                                    hint: 'Enter current password',
                                    prefixIcon: CupertinoIcons.lock_fill,
                                    suffixIcon: _buildVisibilityToggle(
                                      visible,
                                      () => _isCurrentPasswordVisible.value =
                                          !visible,
                                    ),
                                  ),
                                  validator: (val) => val == null || val.isEmpty
                                      ? 'Please enter your current password'
                                      : null,
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            const _InputLabel(text: 'NEW PASSWORD'),
                            const SizedBox(height: 6),
                            ValueListenableBuilder<bool>(
                              valueListenable: _isNewPasswordVisible,
                              builder: (context, visible, _) {
                                return TextFormField(
                                  controller: _newPasswordController,
                                  obscureText: !visible,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  keyboardType: TextInputType.visiblePassword,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  decoration: _buildInputDecoration(
                                    hint: 'Enter new password',
                                    prefixIcon: CupertinoIcons.lock_shield_fill,
                                    suffixIcon: _buildVisibilityToggle(
                                      visible,
                                      () => _isNewPasswordVisible.value =
                                          !visible,
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.isEmpty) {
                                      return 'Please enter a new password';
                                    }
                                    if (val.length < _minPasswordLength) {
                                      return 'Password must be at least $_minPasswordLength characters';
                                    }
                                    if (!_uppercaseRegex.hasMatch(val)) {
                                      return 'Must contain at least one uppercase letter';
                                    }
                                    if (!_lowercaseRegex.hasMatch(val)) {
                                      return 'Must contain at least one lowercase letter';
                                    }
                                    return null;
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            // Modern Dynamic Password Strength Indicator
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildRequirementPill(
                                  '8+ Characters',
                                  _hasMinLength,
                                ),
                                _buildRequirementPill(
                                  'Uppercase',
                                  _hasUppercase,
                                ),
                                _buildRequirementPill(
                                  'Lowercase',
                                  _hasLowercase,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const _InputLabel(text: 'CONFIRM NEW PASSWORD'),
                            const SizedBox(height: 6),
                            ValueListenableBuilder<bool>(
                              valueListenable: _isConfirmPasswordVisible,
                              builder: (context, visible, _) {
                                return TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: !visible,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  keyboardType: TextInputType.visiblePassword,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [
                                    AutofillHints.newPassword,
                                  ],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  onFieldSubmitted: (_) =>
                                      _handleSavePassword(),
                                  decoration: _buildInputDecoration(
                                    hint: 'Re-enter new password',
                                    prefixIcon: CupertinoIcons.lock_shield_fill,
                                    suffixIcon: _buildVisibilityToggle(
                                      visible,
                                      () => _isConfirmPasswordVisible.value =
                                          !visible,
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.isEmpty) {
                                      return 'Please confirm your new password';
                                    }
                                    if (val != _newPasswordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading ? null : _handleSavePassword,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: animation,
                                  child: child,
                                ),
                              ),
                          child: _isLoading
                              ? const SizedBox(
                                  key: ValueKey('loading_spinner'),
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save New Password',
                                  key: ValueKey('save_text'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(prefixIcon, color: midGreen, size: 18),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: lightGreenBg.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _InputLabel extends StatelessWidget {
  final String text;
  const _InputLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
      ),
    );
  }
}

class _HeaderWidget extends StatelessWidget {
  final double topPadding;
  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color borderGreen = Color(0xFF20341E);

  const _HeaderWidget({required this.topPadding});

  @override
  Widget build(BuildContext context) {
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
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
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
          const SizedBox(height: 18),
          const Text(
            'Change Password',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            'Set a secure new password for your account',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

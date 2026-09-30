import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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

  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color lightGreenBg = Color(0xFFE8F5E9);

  @override
  void dispose() {
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
        (p) => p.providerId == 'password',
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

      // Record password change timestamp in Firestore for SecuritySettingsScreen
      try {
        final userDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);
        await userDocRef.update({
          'passwordLastChanged': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Firestore timestamp update failed: $e');
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'passwordLastChanged': FieldValue.serverTimestamp(),
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
              color: isError ? Colors.white : const Color(0xFF00FF22),
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
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        visible
                                            ? CupertinoIcons.eye_fill
                                            : CupertinoIcons.eye_slash_fill,
                                        color: Colors.grey,
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          _isCurrentPasswordVisible.value =
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
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        visible
                                            ? CupertinoIcons.eye_fill
                                            : CupertinoIcons.eye_slash_fill,
                                        color: Colors.grey,
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          _isNewPasswordVisible.value =
                                              !visible,
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.isEmpty) {
                                      return 'Please enter a new password';
                                    }
                                    if (val.length < 8) {
                                      return 'Password must be at least 8 characters';
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
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        visible
                                            ? CupertinoIcons.eye_fill
                                            : CupertinoIcons.eye_slash_fill,
                                        color: Colors.grey,
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          _isConfirmPasswordVisible.value =
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
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save New Password',
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

//finally done
//firestore optimized

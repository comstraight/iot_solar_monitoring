import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

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

  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  bool _isLoading = false;

  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color borderGreen = Color(0xFF20341E);
  static const Color lightGreenBg = Color(0xFFE8F5E9);
  static const Color pageBg = Colors.white;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSavePassword() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      Future.delayed(const Duration(seconds: 1, milliseconds: 500), () {
        if (!mounted) return;
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: darkGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            content: const Row(
              children: [
                Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  color: Color(0xFF00FF22),
                ),
                SizedBox(width: 10),
                Text('Password updated successfully!'),
              ],
            ),
          ),
        );
        Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildTopHeader(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildSectionHeader('Update Credentials'),
                  _buildFloatingCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInputLabel('CURRENT PASSWORD'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _currentPasswordController,
                              obscureText: !_isCurrentPasswordVisible,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              decoration: _buildInputDecoration(
                                hint: '',
                                prefixIcon: CupertinoIcons.lock_fill,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isCurrentPasswordVisible
                                        ? CupertinoIcons.eye_fill
                                        : CupertinoIcons.eye_slash_fill,
                                    color: Colors.grey,
                                    size: 18,
                                  ),
                                  onPressed: () => setState(
                                    () => _isCurrentPasswordVisible =
                                        !_isCurrentPasswordVisible,
                                  ),
                                ),
                              ),
                              validator: (val) => val == null || val.isEmpty
                                  ? 'Please enter your current password'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            _buildInputLabel('NEW PASSWORD'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: !_isNewPasswordVisible,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              decoration: _buildInputDecoration(
                                hint: '',
                                prefixIcon: CupertinoIcons.lock_shield_fill,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isNewPasswordVisible
                                        ? CupertinoIcons.eye_fill
                                        : CupertinoIcons.eye_slash_fill,
                                    color: Colors.grey,
                                    size: 18,
                                  ),
                                  onPressed: () => setState(
                                    () => _isNewPasswordVisible =
                                        !_isNewPasswordVisible,
                                  ),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Please enter a new password';
                                }
                                if (val.length < 8) {
                                  return 'Password must be at least 8 characters';
                                }
                                if (!val.contains(RegExp(r'[A-Z]'))) {
                                  return 'Must contain at least one uppercase letter';
                                }
                                if (!val.contains(RegExp(r'[a-z]'))) {
                                  return 'Must contain at least one lowercase letter';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildInputLabel('CONFIRM NEW PASSWORD'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: !_isConfirmPasswordVisible,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              decoration: _buildInputDecoration(
                                hint: '',
                                prefixIcon: CupertinoIcons.lock_shield_fill,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isConfirmPasswordVisible
                                        ? CupertinoIcons.eye_fill
                                        : CupertinoIcons.eye_slash_fill,
                                    color: Colors.grey,
                                    size: 18,
                                  ),
                                  onPressed: () => setState(
                                    () => _isConfirmPasswordVisible =
                                        !_isConfirmPasswordVisible,
                                  ),
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
                            ),
                          ],
                        ),
                      ),
                    ],
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
        ],
      ),
    );
  }

  Widget _buildInputLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: Colors.grey,
    ),
  );

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 45, left: 16, right: 16, bottom: 25),
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
            onTap: () => Navigator.pop(context),
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

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, top: 18, bottom: 8),
    child: Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    ),
  );

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

  Widget _buildFloatingCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Screen Step State (0: Email, 1: Verification Code, 2: New Password)
  int _currentStep = 0;

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // Theme Constants
  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color inputBg = Color(0xFFF4F7F4);
  static const Color pageBg = Color(0xFFF8FAF8);

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleNextStep() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      Future.delayed(const Duration(seconds: 1, milliseconds: 500), () {
        if (!mounted) return;
        setState(() => _isLoading = false);

        if (_currentStep < 2) {
          setState(() {
            _currentStep++;
            _formKey.currentState?.reset();
          });
        } else {
          // Final Password Reset Success
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: darkGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                  SizedBox(width: 12),
                  Text('Password reset successfully! You can now sign in.'),
                ],
              ),
            ),
          );
          Navigator.maybePop(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: darkGreen),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep--;
                _formKey.currentState?.reset();
              });
            } else {
              Navigator.maybePop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                boxShadow: [
                  BoxShadow(
                    color: darkGreen.withValues(alpha: 0.06),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // STEP PROGRESS BAR
                    Row(
                      children: List.generate(3, (index) {
                        final isActive = index <= _currentStep;
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: EdgeInsets.only(right: index < 2 ? 6 : 0),
                            decoration: BoxDecoration(
                              color: isActive ? midGreen : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),

                    // STEP HEADER TITLES
                    Text(
                      _getStepTitle(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: darkGreen,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStepSubtitle(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // STEP CONTENT FIELDS
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _buildCurrentStepFields(),
                    ),
                    const SizedBox(height: 28),

                    // SUBMIT / ACTION BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: _isLoading ? null : _handleNextStep,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _getButtonLabel(),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Reset Password';
      case 1:
        return 'Enter Security Code';
      case 2:
        return 'Create New Password';
      default:
        return '';
    }
  }

  String _getStepSubtitle() {
    switch (_currentStep) {
      case 0:
        return 'Enter your account email to receive a recovery code.';
      case 1:
        return 'We sent a 6-digit code to ${_emailController.text.isNotEmpty ? _emailController.text : "your email"}.';
      case 2:
        return 'Set your new account password below.';
      default:
        return '';
    }
  }

  String _getButtonLabel() {
    switch (_currentStep) {
      case 0:
        return 'Send Verification Code';
      case 1:
        return 'Verify Code';
      case 2:
        return 'Reset Password';
      default:
        return 'Next';
    }
  }

  Widget _buildCurrentStepFields() {
    switch (_currentStep) {
      // STEP 1: EMAIL INPUT
      case 0:
        return Column(
          key: const ValueKey(0),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Email address',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: darkGreen,
                fontSize: 14,
              ),
              decoration: _buildInputDecoration(
                hint: 'name@example.com',
                prefixIcon: Icons.mail_outline_rounded,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter your email';
                }
                if (!val.contains('@')) {
                  return 'Invalid email address';
                }
                return null;
              },
            ),
          ],
        );

      // STEP 2: VERIFICATION CODE INPUT
      case 1:
        return Column(
          key: const ValueKey(1),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verification Code',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: darkGreen,
                fontSize: 18,
                letterSpacing: 4.0,
              ),
              decoration: _buildInputDecoration(
                hint: '123456',
                prefixIcon: Icons.pin_outlined,
              ).copyWith(counterText: ''),
              validator: (val) {
                if (val == null || val.trim().length < 6) {
                  return 'Enter the 6-digit verification code';
                }
                return null;
              },
            ),
          ],
        );

      // STEP 3: NEW PASSWORD INPUT
      case 2:
        return Column(
          key: const ValueKey(2),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New Password',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _newPasswordController,
              obscureText: !_isPasswordVisible,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: darkGreen,
                fontSize: 14,
              ),
              decoration: _buildInputDecoration(
                hint: '••••••••••••',
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey.shade500,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() => _isPasswordVisible = !_isPasswordVisible);
                  },
                ),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Please enter your new password';
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
            const SizedBox(height: 18),
            const Text(
              'Confirm New Password',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_isPasswordVisible,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: darkGreen,
                fontSize: 14,
              ),
              decoration: _buildInputDecoration(
                hint: '••••••••••••',
                prefixIcon: Icons.lock_clock_outlined,
              ),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Please confirm your password';
                }
                if (val != _newPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      prefixIcon: Icon(prefixIcon, color: midGreen, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: midGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}

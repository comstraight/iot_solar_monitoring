import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Centralized Regular Expressions
abstract class _AppRegex {
  static final RegExp email = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
}

/// Centralized Color Palette
abstract class _AppColors {
  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color inputBg = Color(0xFFF4F7F4);
  static const Color pageBg = Color(0xFFF8FAF8);
  static const Color cardBg = Colors.white;
  static const Color textDark = Color(0xFF092508);
  static final Color textSubtle = Colors.grey.shade600;
  static final Color hintText = Colors.grey.shade400;
  static const Color iconGreen = Color(0xFF20831B);
  static final Color errorBg = Colors.red.shade900;
  static const Color errorIcon = Colors.white;
  static const Color successIcon = Colors.greenAccent;
  static const Color borderError = Colors.redAccent;
}

/// Centralized UI Text & Messages
abstract class _AppStrings {
  static const String resetPasswordTitle = 'Reset Password';
  static const String resetPasswordSubtitle =
      'Enter your account email below. We will send you an official link to reset your password.';
  static const String emailFieldLabel = 'Email address';
  static const String emailFieldHint = 'name@example.com';
  static const String sendResetButtonText = 'Send Reset Link';

  static const String successMessage =
      'Password reset link sent! Please check your email inbox.';
  static const String defaultErrorMessage = 'Failed to send reset email.';
  static const String userNotFoundMessage =
      'No account exists with this email address.';
  static const String invalidEmailMessage =
      'Please enter a valid email address';
  static const String emptyEmailMessage = 'Please enter your email address';
  static const String unexpectedErrorMessage = 'An unexpected error occurred.';

  static const String firebaseUserNotFoundCode = 'user-not-found';
  static const String firebaseInvalidEmailCode = 'invalid-email';
}

/// Centralized Layout Dimensions & Magic Numbers
abstract class _AppDimensions {
  static const double pagePaddingHorizontal = 24.0;
  static const double pagePaddingVertical = 16.0;
  static const double cardPadding = 24.0;

  static const double cardBorderRadius = 32.0;
  static const double inputBorderRadius = 16.0;
  static const double buttonBorderRadius = 18.0;

  static const double spacingExtraSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 12.0;
  static const double spacingLarge = 24.0;
  static const double spacingExtraLarge = 28.0;

  static const double buttonHeight = 54.0;
  static const double progressIndicatorSize = 20.0;
  static const double progressStrokeWidth = 2.5;

  static const double prefixIconSize = 20.0;
  static const double arrowIconSize = 18.0;

  static const double titleFontSize = 20.0;
  static const double subtitleFontSize = 12.0;
  static const double labelFontSize = 13.0;
  static const double inputFontSize = 14.0;
  static const double hintFontSize = 13.0;
  static const double buttonFontSize = 15.0;

  static const double cardBorderAlpha = 0.04;
  static const double shadowAlpha = 0.06;
  static const double shadowBlurRadius = 30.0;
  static const Offset shadowOffset = Offset(0, 12);
  static const double inputBorderWidth = 1.5;
  static const double subtitleLineHeight = 1.3;
  static const double titleLetterSpacing = -0.3;
}

/// Centralized Text Styles
abstract class _AppStyles {
  static const TextStyle title = TextStyle(
    fontSize: _AppDimensions.titleFontSize,
    fontWeight: FontWeight.bold,
    color: _AppColors.textDark,
    letterSpacing: _AppDimensions.titleLetterSpacing,
  );

  static TextStyle subtitle = TextStyle(
    fontSize: _AppDimensions.subtitleFontSize,
    color: _AppColors.textSubtle,
    height: _AppDimensions.subtitleLineHeight,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontSize: _AppDimensions.labelFontSize,
    fontWeight: FontWeight.bold,
    color: _AppColors.textDark,
  );

  static const TextStyle inputText = TextStyle(
    fontWeight: FontWeight.w600,
    color: _AppColors.textDark,
    fontSize: _AppDimensions.inputFontSize,
  );

  static TextStyle hintText = TextStyle(
    color: _AppColors.hintText,
    fontSize: _AppDimensions.hintFontSize,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: _AppDimensions.buttonFontSize,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle snackBarText = TextStyle(color: Colors.white);
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Uses built-in Firebase Authentication Password Reset Email Template
  Future<void> _handleResetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      TextInput.finishAutofillContext();

      if (!mounted) return;

      _showSnackBar(message: _AppStrings.successMessage, isError: false);

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String errorMessage = _AppStrings.defaultErrorMessage;
      if (e.code == _AppStrings.firebaseUserNotFoundCode) {
        errorMessage = _AppStrings.userNotFoundMessage;
      } else if (e.code == _AppStrings.firebaseInvalidEmailCode) {
        errorMessage = _AppStrings.invalidEmailMessage;
      } else if (e.message != null && e.message!.isNotEmpty) {
        errorMessage = e.message!;
      }

      _showSnackBar(message: errorMessage, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar(message: _AppStrings.unexpectedErrorMessage, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar({required String message, bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? _AppColors.errorBg : _AppColors.darkGreen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_AppDimensions.inputBorderRadius),
        ),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: isError ? _AppColors.errorIcon : _AppColors.successIcon,
            ),
            const SizedBox(width: _AppDimensions.spacingMedium),
            Expanded(child: Text(message, style: _AppStyles.snackBarText)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: _AppColors.darkGreen,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: _AppDimensions.pagePaddingHorizontal,
              vertical: _AppDimensions.pagePaddingVertical,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(_AppDimensions.cardPadding),
              decoration: BoxDecoration(
                color: _AppColors.cardBg,
                borderRadius: BorderRadius.circular(
                  _AppDimensions.cardBorderRadius,
                ),
                border: Border.all(
                  color: Colors.black.withValues(
                    alpha: _AppDimensions.cardBorderAlpha,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _AppColors.darkGreen.withValues(
                      alpha: _AppDimensions.shadowAlpha,
                    ),
                    blurRadius: _AppDimensions.shadowBlurRadius,
                    offset: _AppDimensions.shadowOffset,
                  ),
                ],
              ),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        _AppStrings.resetPasswordTitle,
                        style: _AppStyles.title,
                      ),
                      const SizedBox(height: _AppDimensions.spacingExtraSmall),
                      Text(
                        _AppStrings.resetPasswordSubtitle,
                        style: _AppStyles.subtitle,
                      ),
                      const SizedBox(height: _AppDimensions.spacingLarge),

                      // EMAIL FIELD
                      const Text(
                        _AppStrings.emailFieldLabel,
                        style: _AppStyles.fieldLabel,
                      ),
                      const SizedBox(height: _AppDimensions.spacingSmall),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        onFieldSubmitted: (_) => _handleResetPassword(),
                        style: _AppStyles.inputText,
                        decoration: InputDecoration(
                          hintText: _AppStrings.emailFieldHint,
                          hintStyle: _AppStyles.hintText,
                          prefixIcon: const Icon(
                            Icons.mail_outline_rounded,
                            color: _AppColors.iconGreen,
                            size: _AppDimensions.prefixIconSize,
                          ),
                          filled: true,
                          fillColor: _AppColors.inputBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: _AppDimensions.pagePaddingVertical,
                            vertical: _AppDimensions.pagePaddingVertical,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              _AppDimensions.inputBorderRadius,
                            ),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              _AppDimensions.inputBorderRadius,
                            ),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              _AppDimensions.inputBorderRadius,
                            ),
                            borderSide: const BorderSide(
                              color: _AppColors.midGreen,
                              width: _AppDimensions.inputBorderWidth,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              _AppDimensions.inputBorderRadius,
                            ),
                            borderSide: const BorderSide(
                              color: _AppColors.borderError,
                              width: _AppDimensions.inputBorderWidth,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              _AppDimensions.inputBorderRadius,
                            ),
                            borderSide: const BorderSide(
                              color: _AppColors.borderError,
                              width: _AppDimensions.inputBorderWidth,
                            ),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return _AppStrings.emptyEmailMessage;
                          }
                          if (!_AppRegex.email.hasMatch(val.trim())) {
                            return _AppStrings.invalidEmailMessage;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: _AppDimensions.spacingExtraLarge),

                      // SEND EMAIL BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: _AppDimensions.buttonHeight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _AppColors.darkGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                _AppDimensions.buttonBorderRadius,
                              ),
                            ),
                          ),
                          onPressed: _isLoading ? null : _handleResetPassword,
                          child: _isLoading
                              ? const SizedBox(
                                  height: _AppDimensions.progressIndicatorSize,
                                  width: _AppDimensions.progressIndicatorSize,
                                  child: CircularProgressIndicator(
                                    strokeWidth:
                                        _AppDimensions.progressStrokeWidth,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _AppStrings.sendResetButtonText,
                                      style: _AppStyles.buttonText,
                                    ),
                                    SizedBox(
                                      width: _AppDimensions.spacingSmall,
                                    ),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: _AppDimensions.arrowIconSize,
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
      ),
    );
  }
}

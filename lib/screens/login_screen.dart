import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';
import 'account_setup.dart';

class SlickLoginScreen extends StatefulWidget {
  const SlickLoginScreen({super.key});

  // Color Palette Constants
  static const Color headerGreen = Color(0xFF10CE2C);
  static const Color buttonGreen = Color(0xFF4CAE50);
  static const Color inputBg = Color(0xFFD9D9D9);
  static const Color darkGreen = Color(0xFF092508);
  static const Color snackbarErrorBg = Color(0xFFB71C1C);
  static const Color successIconColor = Colors.greenAccent;

  // SharedPreferences Keys
  static const String prefSavedEmail = 'saved_email';
  static const String prefRememberMe = 'remember_me';

  // Firestore Collections and Fields
  static const String colUsers = 'users';
  static const String fieldLastLogin = 'last_login';
  static const String fieldName = 'name';
  static const String fieldUid = 'uid';
  static const String fieldEmail = 'email';
  static const String fieldCreatedAt = 'created_at';
  static const String fieldAssignedGroups = 'assigned_groups';
  static const String fieldRole = 'role';
  static const String defaultUserRole = 'user';

  // Navigation Defaults
  static const double defaultHomePercentage = 20.0;
  static const int defaultHomeCardCount = 1;

  // Validation Limits
  static const int minPasswordLength = 8;

  // Validation Patterns
  static final RegExp emailRegExp = RegExp(
    r'^[a-zA-Z0-9.!#$%&'
    "'"
    r'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
  );
  static final RegExp uppercaseRegExp = RegExp(r'[A-Z]');
  static final RegExp lowercaseRegExp = RegExp(r'[a-z]');
  static final RegExp numberRegExp = RegExp(r'[0-9]');
  static final RegExp specialCharRegExp = RegExp(r'[!@#$%^&*(),.?":{}|<>]');

  // UI Strings
  static const String titleSignIn = 'Sign In';
  static const String titleSignUp = 'Sign Up';
  static const String welcomeBackText = 'Welcome Back!';
  static const String hintEmail = 'Email Address';
  static const String hintPassword = 'Password';
  static const String hintConfirmPassword = 'Confirm Password';
  static const String rememberMeText = 'Remember Me';
  static const String forgotPasswordText = 'Forgot Password';
  static const String buttonLogIn = 'Log In';
  static const String buttonCreateAccount = 'Create Account';

  // Messages & Error Strings
  static const String msgEnterEmail = 'Please enter your email address';
  static const String msgEnterValidEmail = 'Please enter a valid email address';
  static const String msgEnterPassword = 'Please enter your password';
  static const String msgPasswordMinLength =
      'Password must be at least 8 characters long';
  static const String msgPasswordUppercase =
      'Password must contain at least one uppercase letter';
  static const String msgPasswordLowercase =
      'Password must contain at least one lowercase letter';
  static const String msgPasswordNumber =
      'Password must contain at least one number';
  static const String msgPasswordSpecialChar =
      'Password must contain at least one special character';
  static const String msgConfirmPassword = 'Please confirm your password';
  static const String msgPasswordsDoNotMatch = 'Passwords do not match';
  static const String msgAuthSuccess = 'Authenticated successfully';
  static const String msgRegisterSuccess =
      'Account registered successfully! Please sign in.';

  // Auth Exception Messages
  static const String errUserNotFound = 'No account exists for this email.';
  static const String errWrongPassword = 'Incorrect email or password.';
  static const String errEmailInUse =
      'An account already exists with this email.';
  static const String errWeakPassword =
      'Password should be at least 8 characters.';
  static const String errInvalidEmail = 'Please enter a valid email address.';
  static const String errDefaultAuth =
      'An error occurred during authentication.';

  @override
  State<SlickLoginScreen> createState() => _SlickLoginScreenState();
}

class _SlickLoginScreenState extends State<SlickLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _selectedTab = 0; // 0 = Sign In, 1 = Register
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString(SlickLoginScreen.prefSavedEmail);
    final remember = prefs.getBool(SlickLoginScreen.prefRememberMe) ?? false;

    if (remember && savedEmail != null && mounted) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = true;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- VALIDATORS ---

  String? _validateEmail(String? val) {
    if (val == null || val.trim().isEmpty) {
      return SlickLoginScreen.msgEnterEmail;
    }
    if (!SlickLoginScreen.emailRegExp.hasMatch(val.trim())) {
      return SlickLoginScreen.msgEnterValidEmail;
    }
    return null;
  }

  String? _validatePassword(String? val) {
    if (val == null || val.trim().isEmpty) {
      return SlickLoginScreen.msgEnterPassword;
    }

    if (_selectedTab == 1) {
      if (val.length < SlickLoginScreen.minPasswordLength) {
        return SlickLoginScreen.msgPasswordMinLength;
      }
      if (!SlickLoginScreen.uppercaseRegExp.hasMatch(val)) {
        return SlickLoginScreen.msgPasswordUppercase;
      }
      if (!SlickLoginScreen.lowercaseRegExp.hasMatch(val)) {
        return SlickLoginScreen.msgPasswordLowercase;
      }
      if (!SlickLoginScreen.numberRegExp.hasMatch(val)) {
        return SlickLoginScreen.msgPasswordNumber;
      }
      if (!SlickLoginScreen.specialCharRegExp.hasMatch(val)) {
        return SlickLoginScreen.msgPasswordSpecialChar;
      }
    }
    return null;
  }

  String? _validateConfirmPassword(String? val) {
    if (_selectedTab == 1) {
      if (val == null || val.isEmpty) {
        return SlickLoginScreen.msgConfirmPassword;
      }
      if (val != _passwordController.text) {
        return SlickLoginScreen.msgPasswordsDoNotMatch;
      }
    }
    return null;
  }

  Future<void> _handleAuth() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    try {
      if (_selectedTab == 0) {
        // --- SIGN IN FLOW ---
        final UserCredential credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);

        // Save or clear remember me preference
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString(SlickLoginScreen.prefSavedEmail, email);
          await prefs.setBool(SlickLoginScreen.prefRememberMe, true);
        } else {
          await prefs.remove(SlickLoginScreen.prefSavedEmail);
          await prefs.setBool(SlickLoginScreen.prefRememberMe, false);
        }

        TextInput.finishAutofillContext();

        bool isProfileIncomplete = true;

        if (credential.user != null) {
          // Update last login timestamp in Firestore
          final userDocRef = FirebaseFirestore.instance
              .collection(SlickLoginScreen.colUsers)
              .doc(credential.user!.uid);

          await userDocRef.set({
            SlickLoginScreen.fieldLastLogin: FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // Check if user has completed their profile name
          final docSnap = await userDocRef.get();
          if (docSnap.exists && docSnap.data() != null) {
            final data = docSnap.data()!;
            final name = data[SlickLoginScreen.fieldName];
            if (name != null && name.toString().trim().isNotEmpty) {
              isProfileIncomplete = false;
            }
          }
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: SlickLoginScreen.darkGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: SlickLoginScreen.successIconColor,
                ),
                SizedBox(width: 12),
                Text(SlickLoginScreen.msgAuthSuccess),
              ],
            ),
          ),
        );

        // ROUTING BASED ON PROFILE COMPLETION STATUS
        if (isProfileIncomplete) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AccountSetupScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                currentPercentage: SlickLoginScreen.defaultHomePercentage
                    .toInt(),
                cardCount: SlickLoginScreen.defaultHomeCardCount,
              ),
            ),
          );
        }
      } else {
        // --- REGISTER FLOW ---
        final UserCredential credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        if (credential.user != null) {
          await FirebaseFirestore.instance
              .collection(SlickLoginScreen.colUsers)
              .doc(credential.user!.uid)
              .set({
                SlickLoginScreen.fieldUid: credential.user!.uid,
                SlickLoginScreen.fieldEmail: email,
                SlickLoginScreen.fieldCreatedAt: FieldValue.serverTimestamp(),
                SlickLoginScreen.fieldAssignedGroups: [],
                SlickLoginScreen.fieldRole: SlickLoginScreen.defaultUserRole,
              });
        }

        TextInput.finishAutofillContext();

        // Sign out immediately so Firebase session doesn't auto-login
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        // Reset password fields and switch tab to Sign In
        _passwordController.clear();
        _confirmPasswordController.clear();
        setState(() {
          _selectedTab = 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: SlickLoginScreen.darkGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: SlickLoginScreen.successIconColor,
                ),
                SizedBox(width: 12),
                Expanded(child: Text(SlickLoginScreen.msgRegisterSuccess)),
              ],
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String errorMessage = SlickLoginScreen.errDefaultAuth;
      if (e.code == 'user-not-found') {
        errorMessage = SlickLoginScreen.errUserNotFound;
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = SlickLoginScreen.errWrongPassword;
      } else if (e.code == 'email-already-in-use') {
        errorMessage = SlickLoginScreen.errEmailInUse;
      } else if (e.code == 'weak-password') {
        errorMessage = SlickLoginScreen.errWeakPassword;
      } else if (e.code == 'invalid-email') {
        errorMessage = SlickLoginScreen.errInvalidEmail;
      } else if (e.message != null) {
        errorMessage = e.message!;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: SlickLoginScreen.snackbarErrorBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(errorMessage)),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: SlickLoginScreen.snackbarErrorBg,
          content: Text('Unexpected error: ${e.toString()}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SlickLoginScreen.headerGreen,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // TOP GREEN HEADER SECTION
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _selectedTab == 0
                      ? SlickLoginScreen.titleSignIn
                      : SlickLoginScreen.titleSignUp,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // WHITE CURVED BODY CONTAINER
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(36),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28.0),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          // HEADER TEXT
                          const Text(
                            SlickLoginScreen.welcomeBackText,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // EMAIL FIELD
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                            decoration: _buildInputDecoration(
                              hint: SlickLoginScreen.hintEmail,
                            ),
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 16),

                          // PASSWORD FIELD
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            textInputAction: _selectedTab == 0
                                ? TextInputAction.done
                                : TextInputAction.next,
                            autofillHints: [
                              _selectedTab == 0
                                  ? AutofillHints.password
                                  : AutofillHints.newPassword,
                            ],
                            onFieldSubmitted: (_) {
                              if (_selectedTab == 0) _handleAuth();
                            },
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                            decoration: _buildInputDecoration(
                              hint: SlickLoginScreen.hintPassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: Colors.black87,
                                  size: 22,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _isPasswordVisible =
                                        !_isPasswordVisible,
                                  );
                                },
                              ),
                            ),
                            validator: _validatePassword,
                          ),

                          // CONFIRM PASSWORD FIELD (Shown only during registration)
                          if (_selectedTab == 1) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: !_isConfirmPasswordVisible,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              onFieldSubmitted: (_) => _handleAuth(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                              decoration: _buildInputDecoration(
                                hint: SlickLoginScreen.hintConfirmPassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isConfirmPasswordVisible
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.black87,
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () => _isConfirmPasswordVisible =
                                          !_isConfirmPasswordVisible,
                                    );
                                  },
                                ),
                              ),
                              validator: _validateConfirmPassword,
                            ),
                          ],

                          const SizedBox(height: 12),

                          // REMEMBER ME & FORGOT PASSWORD ROW
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      activeColor: SlickLoginScreen.buttonGreen,
                                      side: const BorderSide(
                                        color: Colors.black38,
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      onChanged: (bool? value) {
                                        setState(() {
                                          _rememberMe = value ?? false;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    SlickLoginScreen.rememberMeText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: _navigateToForgotPassword,
                                child: const Text(
                                  SlickLoginScreen.forgotPasswordText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: SlickLoginScreen.buttonGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // ACTION BUTTON
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: SlickLoginScreen.buttonGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _isLoading ? null : _handleAuth,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _selectedTab == 0
                                          ? SlickLoginScreen.buttonLogIn
                                          : SlickLoginScreen
                                                .buttonCreateAccount,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // BOTTOM SEGMENTED TAB SWITCHER
                          Container(
                            height: 48,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: SlickLoginScreen.inputBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_selectedTab != 0) {
                                        setState(() {
                                          _selectedTab = 0;
                                          _formKey.currentState?.reset();
                                        });
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _selectedTab == 0
                                            ? Colors.white
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        SlickLoginScreen.titleSignIn,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: _selectedTab == 0
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_selectedTab != 1) {
                                        setState(() {
                                          _selectedTab = 1;
                                          _formKey.currentState?.reset();
                                        });
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _selectedTab == 1
                                            ? Colors.white
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        SlickLoginScreen.titleSignUp,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: _selectedTab == 1
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: Colors.black87,
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

  InputDecoration _buildInputDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black45, fontSize: 14),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: SlickLoginScreen.inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
        borderSide: const BorderSide(
          color: SlickLoginScreen.buttonGreen,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }
}

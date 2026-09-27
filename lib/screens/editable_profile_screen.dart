import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

class EditableProfileScreen extends StatefulWidget {
  const EditableProfileScreen({super.key});

  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color lightGreenBg = Color(0xFFE8F5E9);

  @override
  State<EditableProfileScreen> createState() => _EditableProfileScreenState();
}

class _EditableProfileScreenState extends State<EditableProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _studentIdController;

  final ValueNotifier<bool> _isFormDirtyNotifier = ValueNotifier(false);

  String _initialName = '';
  String _initialEmail = '';
  String _initialPhone = '';
  String _initialStudentId = '';

  bool _isFetching = true;
  bool _isLoading = false;
  bool _isEmailEditable = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _studentIdController = TextEditingController();

    _nameController.addListener(_checkDirtyState);
    _emailController.addListener(_checkDirtyState);
    _phoneController.addListener(_checkDirtyState);
    _studentIdController.addListener(_checkDirtyState);

    _loadUserProfile();
  }

  void _checkDirtyState() {
    final isDirty =
        _nameController.text != _initialName ||
        _emailController.text != _initialEmail ||
        _phoneController.text != _initialPhone ||
        _studentIdController.text != _initialStudentId;

    if (_isFormDirtyNotifier.value != isDirty) {
      _isFormDirtyNotifier.value = isDirty;
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_checkDirtyState);
    _emailController.removeListener(_checkDirtyState);
    _phoneController.removeListener(_checkDirtyState);
    _studentIdController.removeListener(_checkDirtyState);

    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _studentIdController.dispose();
    _isFormDirtyNotifier.dispose();
    super.dispose();
  }

  /// Fetches profile data and syncs pending email confirmations
  Future<void> _loadUserProfile() async {
    var currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (mounted) setState(() => _isFetching = false);
      return;
    }

    try {
      // Reload user token to get latest email verification status
      await currentUser.reload();
      currentUser = FirebaseAuth.instance.currentUser ?? currentUser;

      // Disable email modification if signed in via social OAuth provider
      _isEmailEditable = currentUser.providerData.any(
        (p) => p.providerId == 'password',
      );

      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!mounted) return;

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        _initialName = data['name'] ?? currentUser.displayName ?? '';
        _initialEmail = data['email'] ?? currentUser.email ?? '';
        _initialPhone = data['phone'] ?? '';
        _initialStudentId = data['studentId'] ?? '';

        // Auto-resolve pending email if user verified it in Auth since last visit
        if (currentUser.email != null && currentUser.email != _initialEmail) {
          _initialEmail = currentUser.email!;
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({
                'email': _initialEmail,
                'pendingEmail': FieldValue.delete(),
              });
        }
      } else {
        _initialName = currentUser.displayName ?? '';
        _initialEmail = currentUser.email ?? '';
      }

      _nameController.text = _initialName;
      _emailController.text = _initialEmail;
      _phoneController.text = _initialPhone;
      _studentIdController.text = _initialStudentId;
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading profile details.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  /// Writes user updates safely
  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showSnackBar('No active user session found.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String updatedName = _nameController.text.trim();
      final String updatedEmail = _emailController.text.trim();
      final String updatedPhone = _phoneController.text.trim();
      final String updatedStudentId = _studentIdController.text.trim();

      final bool isEmailChanged =
          _isEmailEditable &&
          currentUser.email != null &&
          currentUser.email != updatedEmail;

      // 1. First trigger Firebase Auth updates (if required) before Firestore write
      if (currentUser.displayName != updatedName) {
        await currentUser.updateDisplayName(updatedName);
      }

      if (!mounted) return;

      if (isEmailChanged) {
        await currentUser.verifyBeforeUpdateEmail(updatedEmail);
      }

      if (!mounted) return;

      // 2. Prepare and commit Firestore payload
      final Map<String, dynamic> updateData = {
        'name': updatedName,
        'phone': updatedPhone,
        'studentId': updatedStudentId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!isEmailChanged) {
        updateData['email'] = updatedEmail;
      } else {
        updateData['pendingEmail'] = updatedEmail;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set(updateData, SetOptions(merge: true));

      TextInput.finishAutofillContext();

      if (!mounted) return;

      _nameController.text = updatedName;
      _phoneController.text = updatedPhone;
      _studentIdController.text = updatedStudentId;
      _emailController.text = updatedEmail;

      _initialName = updatedName;
      _initialPhone = updatedPhone;
      _initialStudentId = updatedStudentId;
      if (!isEmailChanged) _initialEmail = updatedEmail;

      _checkDirtyState();

      setState(() => _isLoading = false);

      final message = isEmailChanged
          ? 'Profile saved! Confirmation link sent to $updatedEmail.'
          : 'Profile changes saved successfully!';

      _showSnackBar(message);
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      final String errorMessage = switch (e.code) {
        'requires-recent-login' =>
          'Session expired. Please log in again to change your email.',
        'email-already-in-use' =>
          'This email address is already in use by another account.',
        'invalid-email' => 'The email address provided is invalid.',
        'network-request-failed' =>
          'Network error. Please check your internet connection.',
        _ => e.message ?? 'Failed to update credentials.',
      };

      _showSnackBar(errorMessage, isError: true);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar(
        e.message ?? 'Failed to save profile changes.',
        isError: true,
      );
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
        backgroundColor: isError
            ? Colors.red[800]
            : EditableProfileScreen.darkGreen,
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

  Future<bool> _onWillPop() async {
    if (!_isFormDirtyNotifier.value) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return ValueListenableBuilder<bool>(
      valueListenable: _isFormDirtyNotifier,
      builder: (context, isDirty, child) {
        return PopScope(
          canPop: !isDirty,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final navigator = Navigator.of(context);
            final shouldLeave = await _onWillPop();
            if (shouldLeave && mounted) {
              navigator.pop();
            }
          },
          child: child!,
        );
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _HeaderWidget(topPadding: topPadding),
            if (_isFetching)
              const Padding(
                padding: EdgeInsets.only(top: 80.0),
                child: Center(
                  child: CircularProgressIndicator(
                    color: EditableProfileScreen.midGreen,
                  ),
                ),
              )
            else
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
                          'Edit Details',
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
                                const _InputLabel(text: 'FULL NAME'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _nameController,
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.name],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  decoration: _buildInputDecoration(
                                    hint: 'Full Name',
                                    prefixIcon: CupertinoIcons.person_fill,
                                  ),
                                  validator: (val) =>
                                      val == null || val.trim().isEmpty
                                      ? 'Name cannot be empty'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                const _InputLabel(text: 'EMAIL ADDRESS'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _emailController,
                                  enabled: _isEmailEditable,
                                  keyboardType: TextInputType.emailAddress,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: _isEmailEditable
                                        ? Colors.black
                                        : Colors.grey,
                                  ),
                                  decoration: _buildInputDecoration(
                                    hint: _isEmailEditable
                                        ? 'Email Address'
                                        : 'Managed by social login',
                                    prefixIcon: CupertinoIcons.mail_solid,
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Email cannot be empty';
                                    }
                                    if (!_emailRegex.hasMatch(val.trim())) {
                                      return 'Please enter a valid email address';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                const _InputLabel(text: 'PHONE NUMBER'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.telephoneNumber,
                                  ],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  decoration: _buildInputDecoration(
                                    hint: 'Phone Number',
                                    prefixIcon: CupertinoIcons.phone_fill,
                                  ),
                                  validator: (val) =>
                                      val == null || val.trim().isEmpty
                                      ? 'Phone number cannot be empty'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                const _InputLabel(text: 'STUDENT / USER ID'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _studentIdController,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _handleSave(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  decoration: _buildInputDecoration(
                                    hint: 'User ID',
                                    prefixIcon:
                                        CupertinoIcons.person_badge_minus_fill,
                                  ),
                                  validator: (val) =>
                                      val == null || val.trim().isEmpty
                                      ? 'User ID cannot be empty'
                                      : null,
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
                              backgroundColor: EditableProfileScreen.darkGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _isLoading ? null : _handleSave,
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
                                    'Save Profile Changes',
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
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        prefixIcon,
        color: EditableProfileScreen.midGreen,
        size: 18,
      ),
      filled: true,
      fillColor: EditableProfileScreen.lightGreenBg.withValues(alpha: 0.4),
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
        color: EditableProfileScreen.darkGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        gradient: LinearGradient(
          colors: [
            EditableProfileScreen.darkGreen,
            EditableProfileScreen.midGreen,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.38, 1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(CupertinoIcons.chevron_left, color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(height: 20),
          const Text(
            'Edit Profile',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            'Update account credentials & personal details',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

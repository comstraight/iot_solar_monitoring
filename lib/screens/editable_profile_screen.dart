import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditableProfileScreen extends StatefulWidget {
  const EditableProfileScreen({super.key});

  @override
  State<EditableProfileScreen> createState() => _EditableProfileScreenState();
}

class _EditableProfileScreenState extends State<EditableProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _studentIdController;

  bool _isFetching = true;
  bool _isLoading = false;

  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color borderGreen = Color(0xFF20341E);
  static const Color lightGreenBg = Color(0xFFE8F5E9);
  static const Color pageBg = Colors.white;

  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _studentIdController = TextEditingController();

    _loadUserProfile();
  }

  /// READ OPERATION: Fetch current user profile data from Firestore
  Future<void> _loadUserProfile() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _isFetching = false);
      return;
    }

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        _nameController.text = data['name'] ?? _currentUser.displayName ?? '';
        _emailController.text = data['email'] ?? _currentUser.email ?? '';
        _phoneController.text = data['phone'] ?? '';
        _studentIdController.text = data['studentId'] ?? '';
      } else {
        // Pre-fill from Auth if Firestore document does not exist yet
        _nameController.text = _currentUser.displayName ?? '';
        _emailController.text = _currentUser.email ?? '';
      }
    } catch (e) {
      _showSnackBar('Error loading profile details.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  /// WRITE OPERATION: Update user profile in Firestore & Firebase Auth
  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_currentUser == null) {
      _showSnackBar('No active user session.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String updatedName = _nameController.text.trim();
      final String updatedEmail = _emailController.text.trim();
      final String updatedPhone = _phoneController.text.trim();
      final String updatedStudentId = _studentIdController.text.trim();

      // 1. Update Firestore Document (Merge ensures non-editable fields remain intact)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser.uid)
          .set({
            'name': updatedName,
            'email': updatedEmail,
            'phone': updatedPhone,
            'studentId': updatedStudentId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // 2. Update Firebase Auth Display Name
      await _currentUser.updateDisplayName(updatedName);

      if (!mounted) return;
      setState(() => _isLoading = false);

      _showSnackBar('Profile changes saved successfully!');
      Navigator.pop(context);
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
    return Scaffold(
      backgroundColor: pageBg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildTopHeader(),
          if (_isFetching)
            const Padding(
              padding: EdgeInsets.only(top: 80.0),
              child: Center(child: CircularProgressIndicator(color: midGreen)),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildSectionHeader('Edit Details'),
                    _buildFloatingCard(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel('FULL NAME'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _nameController,
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
                              _buildInputLabel('EMAIL ADDRESS'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                decoration: _buildInputDecoration(
                                  hint: 'Email Address',
                                  prefixIcon: CupertinoIcons.mail_solid,
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Email cannot be empty';
                                  }
                                  if (!val.contains('@')) {
                                    return 'Invalid email address';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildInputLabel('PHONE NUMBER'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
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
                              _buildInputLabel('STUDENT / USER ID'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _studentIdController,
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
            child: const Icon(CupertinoIcons.chevron_left, color: Colors.white),
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
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(prefixIcon, color: midGreen, size: 18),
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
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

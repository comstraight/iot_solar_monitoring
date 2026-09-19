import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

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

  bool _isLoading = false;

  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color borderGreen = Color(0xFF20341E);
  static const Color lightGreenBg = Color(0xFFE8F5E9);
  static const Color pageBg = Colors.white;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Andrei Esporlas');
    _emailController = TextEditingController(text: 'andrei@example.com');
    _phoneController = TextEditingController(text: '+63 912 345 6789');
    _studentIdController = TextEditingController(text: '423002684');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  void _handleSave() {
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
                Text('Profile changes saved successfully!'),
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

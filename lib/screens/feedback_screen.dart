import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final _emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

class FeedbackScreen extends StatefulWidget {
  final String receiverEmail;

  const FeedbackScreen({
    super.key,
    this.receiverEmail = 'support@yourdomain.com',
  });

  static const Color primaryGreen = Color(0xFF15803D);
  static const Color darkGreen = Color(0xFF032212);
  static const Color lightGreenBg = Color(0xFFDCFCE7);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  int _selectedCategoryIndex = 0;
  bool _isLoading = false;
  bool _isSubmitted = false;
  String _initialEmail = '';

  late final TextEditingController _feedbackController;
  late final TextEditingController _emailController;

  final ValueNotifier<int> _charCountNotifier = ValueNotifier(0);
  final ValueNotifier<bool> _isEmailValidNotifier = ValueNotifier(true);
  final ValueNotifier<bool> _isFormDirtyNotifier = ValueNotifier(false);

  final List<String> _categories = const [
    'General',
    'Bug Report',
    'Feature Request',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _feedbackController = TextEditingController();
    _emailController = TextEditingController();

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.email != null && currentUser!.email!.isNotEmpty) {
      _initialEmail = currentUser.email!;
      _emailController.text = _initialEmail;
    }

    _feedbackController.addListener(_onFeedbackChanged);
    _emailController.addListener(_onEmailChanged);
  }

  void _onFeedbackChanged() {
    _charCountNotifier.value = _feedbackController.text.trim().length;
    _updateDirtyState();
  }

  void _onEmailChanged() {
    final text = _emailController.text.trim();
    if (text.isEmpty) {
      _isEmailValidNotifier.value = true;
    } else {
      _isEmailValidNotifier.value = _emailRegex.hasMatch(text);
    }
    _updateDirtyState();
  }

  void _updateDirtyState() {
    if (_isSubmitted) {
      _isFormDirtyNotifier.value = false;
      return;
    }
    final isMessageEntered = _feedbackController.text.trim().isNotEmpty;
    final isEmailChanged = _emailController.text.trim() != _initialEmail;
    final isCategoryChanged = _selectedCategoryIndex != 0;

    _isFormDirtyNotifier.value =
        isMessageEntered || isEmailChanged || isCategoryChanged;
  }

  @override
  void dispose() {
    _feedbackController.removeListener(_onFeedbackChanged);
    _emailController.removeListener(_onEmailChanged);
    _feedbackController.dispose();
    _emailController.dispose();
    _charCountNotifier.dispose();
    _isEmailValidNotifier.dispose();
    _isFormDirtyNotifier.dispose();
    super.dispose();
  }

  bool _validateForm() {
    final len = _charCountNotifier.value;
    final isTextValid = len >= 10 && len <= 1000;
    final isEmailValid = _isEmailValidNotifier.value;
    return isTextValid && isEmailValid;
  }

  /// WRITE OPERATION: Submits feedback payload to Firestore
  Future<void> _handleSubmit() async {
    if (!_validateForm() || _isLoading) return;

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() => _isLoading = true);

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      final String inputEmail = _emailController.text.trim();

      await FirebaseFirestore.instance.collection('feedback').add({
        'category': _categories[_selectedCategoryIndex],
        'message': _feedbackController.text.trim(),
        'senderEmail': inputEmail.isNotEmpty
            ? inputEmail
            : (currentUser?.email ?? 'Anonymous'),
        'targetReceiverEmail': widget.receiverEmail,
        'userId': currentUser?.uid ?? 'anonymous',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      TextInput.finishAutofillContext();

      if (!mounted) return;
      _isSubmitted = true;
      _updateDirtyState();
      setState(() => _isLoading = false);

      _showSuccessBottomSheet();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorSnackBar(
        e.message ?? 'Network error. Failed to submit feedback.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to submit feedback. Please try again.');
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red[800],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_circle_fill,
              color: Colors.white,
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

  void _showSuccessBottomSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: FeedbackScreen.lightGreenBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.checkmark_alt,
                color: FeedbackScreen.primaryGreen,
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Feedback Sent!',
              style: TextStyle(
                color: FeedbackScreen.textDark,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Thank you for helping us improve our app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: FeedbackScreen.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FeedbackScreen.primaryGreen,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(sheetContext); // Close bottom sheet
                  if (mounted) {
                    Navigator.pop(context); // Pop feedback screen safely
                  }
                },
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard Feedback?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  @override
  Widget build(BuildContext context) {
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
              _isFormDirtyNotifier.value = false; // Disable guard to pop safely
              navigator.pop();
            }
          },
          child: child!,
        );
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP GREEN GRADIENT HEADER
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  bottom: 28,
                  left: 20,
                  right: 20,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      FeedbackScreen.darkGreen,
                      Color(0xFF0F5229),
                      FeedbackScreen.primaryGreen,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.chevron_left,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Feedback',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'We\'d love to hear your thoughts & suggestions',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 2. MAIN CONTENT BODY
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SECTION 1: CATEGORY SELECTION
                      const Text(
                        'Feedback Category',
                        style: TextStyle(
                          color: FeedbackScreen.textDark,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: List.generate(_categories.length, (index) {
                          final isSelected = _selectedCategoryIndex == index;
                          return ChoiceChip(
                            label: Text(_categories[index]),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategoryIndex = index;
                                });
                                _updateDirtyState();
                              }
                            },
                            selectedColor: FeedbackScreen.lightGreenBg,
                            backgroundColor: const Color(0xFFF8FAFC),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? FeedbackScreen.primaryGreen
                                  : FeedbackScreen.textMuted,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? FeedbackScreen.primaryGreen
                                  : FeedbackScreen.borderColor,
                              width: isSelected ? 1.5 : 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            showCheckmark: false,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 28),

                      // SECTION 2: MESSAGE INPUT CARD
                      const Text(
                        'Your Message',
                        style: TextStyle(
                          color: FeedbackScreen.textDark,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: FeedbackScreen.borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _feedbackController,
                          maxLines: 5,
                          maxLength: 1000,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            fontSize: 14,
                            color: FeedbackScreen.textDark,
                          ),
                          decoration: const InputDecoration(
                            hintText:
                                'Describe what you love or how we can improve (at least 10 characters)...',
                            hintStyle: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                            counterStyle: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),

                      ValueListenableBuilder<int>(
                        valueListenable: _charCountNotifier,
                        builder: (context, length, _) {
                          if (length > 0 && length < 10) {
                            final remaining = 10 - length;
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: 6.0,
                                left: 4.0,
                              ),
                              child: Text(
                                'Please enter at least $remaining more character${remaining == 1 ? '' : 's'}',
                                style: TextStyle(
                                  color: Colors.amber[900],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),

                      const SizedBox(height: 20),

                      // SECTION 3: EMAIL ADDRESS (OPTIONAL)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: FeedbackScreen.borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(
                            fontSize: 14,
                            color: FeedbackScreen.textDark,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Email Address (Optional)',
                            labelStyle: TextStyle(
                              color: FeedbackScreen.textMuted,
                              fontSize: 13,
                            ),
                            hintText: 'name@example.com',
                            hintStyle: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),

                      ValueListenableBuilder<bool>(
                        valueListenable: _isEmailValidNotifier,
                        builder: (context, isValid, _) {
                          if (!isValid) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 6.0, left: 4.0),
                              child: Text(
                                'Please enter a valid email address',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),

                      const SizedBox(height: 32),

                      // SUBMIT BUTTON
                      ListenableBuilder(
                        listenable: Listenable.merge([
                          _charCountNotifier,
                          _isEmailValidNotifier,
                        ]),
                        builder: (context, _) {
                          final canSubmit = _validateForm();

                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (canSubmit && !_isLoading)
                                  ? _handleSubmit
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FeedbackScreen.primaryGreen,
                                disabledBackgroundColor:
                                    FeedbackScreen.borderColor,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Submit Feedback',
                                      style: TextStyle(
                                        color: canSubmit
                                            ? Colors.white
                                            : const Color(0xFF94A3B8),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

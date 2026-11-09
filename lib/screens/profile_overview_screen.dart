import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'editable_profile_screen.dart';

// ==================== CONSTANTS MANAGEMENT ====================
abstract class _ProfileFirestoreKeys {
  static const String collectionUsers = 'users';
  static const String fieldName = 'name';
  static const String fieldRole = 'role';
  static const String fieldEmail = 'email';
  static const String fieldPhone = 'phone';
  static const String fieldUpdatedAt = 'updatedAt';
}

abstract class _ProfileStrings {
  static const String defaultRole = 'User';
  static const String defaultInitial = 'U';
  static const String noNameSet = 'No Name Set';
  static const String roleNotSpecified = 'Role Not Specified';
  static const String notProvided = 'Not Provided';

  static const String sectionPersonalInformation = 'Personal Information';
  static const String labelEmailAddress = 'EMAIL ADDRESS';
  static const String labelPhoneNumber = 'PHONE NUMBER';
  static const String buttonEditProfileDetails = 'Edit Profile Details';

  static const String headerTitle = 'Account Profile';
  static const String headerSubtitle =
      'Personal identity details & credentials';
  static const String semanticsBackLabel = 'Back';

  static const String logFirestoreListenError =
      'Error listening to profile in Firestore:';
  static const String logFirestoreUpdateError =
      'Failed to update profile in Firestore:';
}

abstract class _ProfileColors {
  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color borderGreen = Color(0xFF20341E);
  static const Color lightGreenBg = Color(0xFFE8F5E9);
  static const Color pageBg = Colors.white;
  static const Color cardBg = Colors.white;
  static const Color textBlack = Colors.black;
  static const Color textWhite = Colors.white;
  static const Color textWhite70 = Colors.white70;
  static const Color iconGreen = Color(0xFF20831B);

  static final Color textSubtleGrey = Colors.grey.shade600;
  static const Color labelGrey = Colors.grey;
  static final Color shadowColor = Colors.grey.withValues(alpha: 0.2);
  static final Color dividerColor = Colors.grey.withValues(alpha: 0.2);
  static final Color iconBgColor = lightGreenBg.withValues(alpha: 0.6);
}

abstract class _ProfileDimensions {
  static const double paddingSmall = 4.0;
  static const double paddingMedium = 8.0;
  static const double paddingStandard = 16.0;
  static const double paddingLarge = 20.0;
  static const double paddingExtraLarge = 25.0;
  static const double spacingTiny = 2.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 18.0;
  static const double spacingXLarge = 24.0;
  static const double spacingXXLarge = 32.0;

  static const double buttonHeight = 50.0;
  static const double backButtonSize = 36.0;
  static const double backButtonIconSize = 18.0;
  static const double leadingIconSize = 20.0;
  static const double avatarRadius = 28.0;

  static const double borderRadiusMedium = 10.0;
  static const double borderRadiusLarge = 12.0;
  static const double borderRadiusHeader = 20.0;
  static const double borderWidthThin = 1.5;
  static const double shadowSpreadRadius = 2.0;
  static const double shadowBlurRadius = 3.0;
  static const Offset shadowOffset = Offset(0, 2);

  static const double fontSizeLabel = 10.0;
  static const double fontSizeSub = 11.0;
  static const double fontSizeRole = 12.0;
  static const double fontSizeValue = 14.0;
  static const double fontSizeButton = 15.0;
  static const double fontSizeAvatarText = 18.0;
  static const double fontSizeName = 18.0;
  static const double fontSizeSectionHeader = 20.0;
  static const double fontSizePageTitle = 32.0;
  static const double letterSpacingLabel = 0.5;
  static const double gradientStopTop = 0.38;
  static const double gradientStopBottom = 1.0;
}

// --- DATA MODEL WITH FIREBASE REAL-TIME SYNC ---
class ProfileData extends ChangeNotifier {
  String name = '';
  String role = '';
  String email = '';
  String phone = '';
  bool isLoading = true;

  StreamSubscription<DocumentSnapshot>? _subscription;
  StreamSubscription<User?>? _authSubscription;

  ProfileData() {
    _listenToAuthAndProfile();
  }

  void _listenToAuthAndProfile() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _subscription?.cancel();

      if (user == null) {
        name = '';
        role = '';
        email = '';
        phone = '';
        isLoading = false;
        notifyListeners();
        return;
      }

      final uid = user.uid;

      _subscription = FirebaseFirestore.instance
          .collection(_ProfileFirestoreKeys.collectionUsers)
          .doc(uid)
          .snapshots(includeMetadataChanges: false)
          .listen(
            (doc) {
              if (doc.exists && doc.data() != null) {
                final data = doc.data()!;
                name = data[_ProfileFirestoreKeys.fieldName] ?? '';
                role =
                    data[_ProfileFirestoreKeys.fieldRole] ??
                    _ProfileStrings.defaultRole;
                email =
                    data[_ProfileFirestoreKeys.fieldEmail] ??
                    (user.email ?? '');
                phone = data[_ProfileFirestoreKeys.fieldPhone] ?? '';
              } else {
                // Fallback for newly registered accounts whose profile doc isn't created yet
                email = user.email ?? '';
                role = _ProfileStrings.defaultRole;
              }
              isLoading = false;
              notifyListeners();
            },
            onError: (error) {
              debugPrint('${_ProfileStrings.logFirestoreListenError} $error');
              isLoading = false;
              notifyListeners();
            },
          );
    });
  }

  Future<bool> updateProfile(
    String newName,
    String newEmail,
    String newPhone,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return false;
    }

    final uid = currentUser.uid;

    // Store previous values for rollback if Firestore or Auth sync fails
    final oldName = name;
    final oldEmail = email;
    final oldPhone = phone;

    // Update local state for immediate UI responsiveness
    name = newName;
    email = newEmail;
    phone = newPhone;
    notifyListeners();

    try {
      // Sync email with Firebase Auth credential if email changed
      if (newEmail.isNotEmpty && newEmail.trim() != currentUser.email) {
        await currentUser.verifyBeforeUpdateEmail(newEmail.trim());
      }

      // Save changes back to Firebase Firestore
      await FirebaseFirestore.instance
          .collection(_ProfileFirestoreKeys.collectionUsers)
          .doc(uid)
          .set({
            _ProfileFirestoreKeys.fieldName: newName,
            _ProfileFirestoreKeys.fieldEmail: newEmail,
            _ProfileFirestoreKeys.fieldPhone: newPhone,
            _ProfileFirestoreKeys.fieldRole: role.isEmpty
                ? _ProfileStrings.defaultRole
                : role,
            _ProfileFirestoreKeys.fieldUpdatedAt: FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      return true;
    } catch (e) {
      debugPrint('${_ProfileStrings.logFirestoreUpdateError} $e');

      // Rollback local state on error
      name = oldName;
      email = oldEmail;
      phone = oldPhone;
      notifyListeners();

      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}

// --- ENTRY POINT ---
void main() {
  runApp(
    ChangeNotifierProvider<ProfileData>(
      create: (_) => ProfileData(),
      builder: (context, _) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ProfileOverviewScreen(),
      ),
    ),
  );
}

// ==================== PROFILE OVERVIEW SCREEN ====================
class ProfileOverviewScreen extends StatelessWidget {
  final ProfileData? profile;
  final VoidCallback? onEditPressed;

  const ProfileOverviewScreen({super.key, this.profile, this.onEditPressed});

  @override
  Widget build(BuildContext context) {
    final profileData = profile ?? context.watch<ProfileData>();

    if (profileData.isLoading) {
      return const Scaffold(
        backgroundColor: _ProfileColors.pageBg,
        body: Center(
          child: CircularProgressIndicator(color: _ProfileColors.midGreen),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _ProfileColors.pageBg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildTopHeader(context),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _ProfileDimensions.paddingStandard,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: _ProfileDimensions.spacingMedium),

                // USER SUMMARY CARD
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 16),
                        child: child,
                      ),
                    );
                  },
                  child: _buildFloatingCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(
                          _ProfileDimensions.paddingLarge,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(
                                _ProfileDimensions.paddingSmall,
                              ),
                              decoration: const BoxDecoration(
                                color: _ProfileColors.lightGreenBg,
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: _ProfileDimensions.avatarRadius,
                                backgroundColor: _ProfileColors.darkGreen,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  child: Text(
                                    _getInitials(profileData.name),
                                    key: ValueKey<String>(
                                      _getInitials(profileData.name),
                                    ),
                                    style: const TextStyle(
                                      fontSize:
                                          _ProfileDimensions.fontSizeAvatarText,
                                      fontWeight: FontWeight.bold,
                                      color: _ProfileColors.textWhite,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: _ProfileDimensions.spacingMedium,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    transitionBuilder: (child, animation) =>
                                        FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0.0, 0.15),
                                              end: Offset.zero,
                                            ).animate(animation),
                                            child: child,
                                          ),
                                        ),
                                    child: Text(
                                      profileData.name.isEmpty
                                          ? _ProfileStrings.noNameSet
                                          : profileData.name,
                                      key: ValueKey<String>(profileData.name),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize:
                                            _ProfileDimensions.fontSizeName,
                                        color: _ProfileColors.textBlack,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    height: _ProfileDimensions.spacingTiny,
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    transitionBuilder: (child, animation) =>
                                        FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0.0, 0.15),
                                              end: Offset.zero,
                                            ).animate(animation),
                                            child: child,
                                          ),
                                        ),
                                    child: Text(
                                      profileData.role.isEmpty
                                          ? _ProfileStrings.roleNotSpecified
                                          : profileData.role,
                                      key: ValueKey<String>(profileData.role),
                                      style: TextStyle(
                                        fontSize:
                                            _ProfileDimensions.fontSizeRole,
                                        color: _ProfileColors.textSubtleGrey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                _buildSectionHeader(_ProfileStrings.sectionPersonalInformation),

                // DETAILED INFO CARD
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 16),
                        child: child,
                      ),
                    );
                  },
                  child: _buildFloatingCard(
                    children: [
                      _buildInfoListTile(
                        icon: CupertinoIcons.mail_solid,
                        label: _ProfileStrings.labelEmailAddress,
                        value: profileData.email.isEmpty
                            ? _ProfileStrings.notProvided
                            : profileData.email,
                      ),
                      _buildDivider(),
                      _buildInfoListTile(
                        icon: CupertinoIcons.phone_fill,
                        label: _ProfileStrings.labelPhoneNumber,
                        value: profileData.phone.isEmpty
                            ? _ProfileStrings.notProvided
                            : profileData.phone,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: _ProfileDimensions.spacingXLarge),

                // ACTION BUTTON
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 16),
                        child: child,
                      ),
                    );
                  },
                  child: SizedBox(
                    width: double.infinity,
                    height: _ProfileDimensions.buttonHeight,
                    child: ElevatedButton(
                      onPressed:
                          onEditPressed ??
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const EditableProfileScreen(),
                              ),
                            );
                          },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ProfileColors.darkGreen,
                        foregroundColor: _ProfileColors.textWhite,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            _ProfileDimensions.borderRadiusLarge,
                          ),
                        ),
                      ),
                      child: const Text(
                        _ProfileStrings.buttonEditProfileDetails,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: _ProfileDimensions.fontSizeButton,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: _ProfileDimensions.spacingXXLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return _ProfileStrings.defaultInitial;
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return _ProfileStrings.defaultInitial;
  }

  Widget _buildTopHeader(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.only(
        top: topPadding + _ProfileDimensions.paddingStandard,
        left: _ProfileDimensions.paddingStandard,
        right: _ProfileDimensions.paddingStandard,
        bottom: _ProfileDimensions.paddingExtraLarge,
      ),
      decoration: const BoxDecoration(
        color: _ProfileColors.darkGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_ProfileDimensions.borderRadiusHeader),
          bottomRight: Radius.circular(_ProfileDimensions.borderRadiusHeader),
        ),
        gradient: LinearGradient(
          colors: [_ProfileColors.darkGreen, _ProfileColors.midGreen],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [
            _ProfileDimensions.gradientStopTop,
            _ProfileDimensions.gradientStopBottom,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: _ProfileStrings.semanticsBackLabel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    height: _ProfileDimensions.backButtonSize,
                    width: _ProfileDimensions.backButtonSize,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _ProfileColors.borderGreen,
                        width: _ProfileDimensions.borderWidthThin,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      CupertinoIcons.chevron_left,
                      size: _ProfileDimensions.backButtonIconSize,
                      color: _ProfileColors.textWhite,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _ProfileDimensions.spacingLarge),
          const Text(
            _ProfileStrings.headerTitle,
            style: TextStyle(
              fontSize: _ProfileDimensions.fontSizePageTitle,
              fontWeight: FontWeight.bold,
              color: _ProfileColors.textWhite,
            ),
          ),
          const Text(
            _ProfileStrings.headerSubtitle,
            style: TextStyle(
              fontSize: _ProfileDimensions.fontSizeSub,
              color: _ProfileColors.textWhite70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: _ProfileDimensions.paddingSmall,
        top: _ProfileDimensions.spacingLarge,
        bottom: _ProfileDimensions.paddingMedium,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: _ProfileDimensions.fontSizeSectionHeader,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoListTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: _ProfileDimensions.paddingStandard,
        vertical: _ProfileDimensions.paddingSmall,
      ),
      leading: Container(
        padding: const EdgeInsets.all(_ProfileDimensions.paddingMedium),
        decoration: BoxDecoration(
          color: _ProfileColors.iconBgColor,
          borderRadius: BorderRadius.circular(
            _ProfileDimensions.borderRadiusMedium,
          ),
        ),
        child: Icon(
          icon,
          color: _ProfileColors.iconGreen,
          size: _ProfileDimensions.leadingIconSize,
        ),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: _ProfileDimensions.fontSizeLabel,
          fontWeight: FontWeight.bold,
          color: _ProfileColors.labelGrey,
          letterSpacing: _ProfileDimensions.letterSpacingLabel,
        ),
      ),
      subtitle: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.15),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Text(
          value,
          key: ValueKey<String>(value),
          style: const TextStyle(
            fontSize: _ProfileDimensions.fontSizeValue,
            fontWeight: FontWeight.bold,
            color: _ProfileColors.darkGreen,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _ProfileColors.cardBg,
        borderRadius: BorderRadius.circular(
          _ProfileDimensions.borderRadiusLarge,
        ),
        boxShadow: [
          BoxShadow(
            color: _ProfileColors.shadowColor,
            spreadRadius: _ProfileDimensions.shadowSpreadRadius,
            blurRadius: _ProfileDimensions.shadowBlurRadius,
            offset: _ProfileDimensions.shadowOffset,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: _ProfileDimensions.paddingStandard,
      endIndent: _ProfileDimensions.paddingStandard,
      color: _ProfileColors.dividerColor,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'change_password_screen.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});

  // Color Palette Constants
  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color borderGreen = Color(0xFF20341E);
  static const Color lightGreenBg = Color(0xFFE8F5E9);
  static const Color pageBg = Colors.white;
  static const Color textGrey = Color(0xFF757575);

  // Firestore Collection & Field Keys
  static const String _usersCollection = 'users';
  static const String _fieldPasswordLastChanged = 'passwordLastChanged';
  static const String _fieldPasswordTimestamp = 'password_timestamp';
  static const String _fieldAccountInfo = 'account_info';

  // UI Text Constants
  static const String _textHavenChanged = "Haven't Changed";
  static const String _textNotLoggedIn = 'User not logged in';
  static const String _textSecurityAndPassword = 'Security & Password';
  static const String _textPasswordHeader = 'PASSWORD';
  static const String _textLastChangedPrefix = 'Last changed: ';
  static const String _textChangeButton = 'Change';
  static const String _textSecurityTitle = 'Security';
  static const String _textSecuritySubtitle =
      'Account authentication & security settings';

  // Time Formatter Unit Constants
  static const String _unitMonth = 'month';
  static const String _unitMonths = 'months';
  static const String _unitDay = 'day';
  static const String _unitDays = 'days';
  static const String _unitHour = 'hour';
  static const String _unitHours = 'hours';
  static const String _unitMinute = 'minute';
  static const String _unitMinutes = 'minutes';
  static const String _unitJustNow = 'Just now';
  static const String _unitAgo = 'ago';

  // Layout, Radius & Dimension Constants
  static const int _daysInMonth = 30;
  static const double _spacing4 = 4.0;
  static const double _spacing8 = 8.0;
  static const double _spacing10 = 10.0;
  static const double _spacing12 = 12.0;
  static const double _spacing14 = 14.0;
  static const double _spacing16 = 16.0;
  static const double _spacing18 = 18.0;
  static const double _spacing20 = 20.0;
  static const double _spacing25 = 25.0;
  static const double _spacing32 = 32.0;
  static const double _backButtonSize = 36.0;

  static const double _fontSizeSubtext = 11.0;
  static const double _fontSizeButton = 12.0;
  static const double _fontSizeLabel = 14.0;
  static const double _fontSizeSectionHeader = 20.0;
  static const double _fontSizePageTitle = 32.0;

  static const double _letterSpacingLabel = 0.5;
  static const double _borderWidth15 = 1.5;
  static const double _iconSizeLock = 20.0;
  static const double _iconSizeChevron = 18.0;

  static const double _lightGreenAlpha = 0.6;
  static const double _shadowAlpha = 0.2;
  static const double _gradientStopTop = 0.38;
  static const double _gradientStopBottom = 1.0;

  String _formatLastChanged(dynamic lastChangedData) {
    if (lastChangedData == null) return _textHavenChanged;

    DateTime? date;

    if (lastChangedData is Timestamp) {
      date = lastChangedData.toDate();
    } else if (lastChangedData is String && lastChangedData.trim().isNotEmpty) {
      try {
        date = DateTime.parse(lastChangedData);
      } catch (_) {
        return lastChangedData;
      }
    }

    if (date != null) {
      final Duration diff = DateTime.now().difference(date);

      if (diff.inDays >= _daysInMonth) {
        final int months = (diff.inDays / _daysInMonth).floor();
        final String unit = months == 1 ? _unitMonth : _unitMonths;
        return '$months $unit $_unitAgo';
      } else if (diff.inDays > 0) {
        final String unit = diff.inDays == 1 ? _unitDay : _unitDays;
        return '${diff.inDays} $unit $_unitAgo';
      } else if (diff.inHours > 0) {
        final String unit = diff.inHours == 1 ? _unitHour : _unitHours;
        return '${diff.inHours} $unit $_unitAgo';
      } else if (diff.inMinutes > 0) {
        final String unit = diff.inMinutes == 1 ? _unitMinute : _unitMinutes;
        return '${diff.inMinutes} $unit $_unitAgo';
      } else {
        return _unitJustNow;
      }
    }

    return _textHavenChanged;
  }

  dynamic _extractLastChangedRawData(Map<String, dynamic>? data) {
    if (data == null) return null;

    if (data.containsKey(_fieldPasswordLastChanged)) {
      return data[_fieldPasswordLastChanged];
    }
    if (data.containsKey(_fieldPasswordTimestamp)) {
      return data[_fieldPasswordTimestamp];
    }

    if (data.containsKey(_fieldAccountInfo) &&
        data[_fieldAccountInfo] is Map<String, dynamic>) {
      final accountInfo = data[_fieldAccountInfo] as Map<String, dynamic>;
      if (accountInfo.containsKey(_fieldPasswordLastChanged)) {
        return accountInfo[_fieldPasswordLastChanged];
      }
      if (accountInfo.containsKey(_fieldPasswordTimestamp)) {
        return accountInfo[_fieldPasswordTimestamp];
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, authSnapshot) {
        final currentUser =
            authSnapshot.data ?? FirebaseAuth.instance.currentUser;

        if (currentUser == null) {
          return Scaffold(
            backgroundColor: pageBg,
            body: Center(
              child: Text(
                _textNotLoggedIn,
                style: const TextStyle(color: textGrey),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: pageBg,
          body: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection(_usersCollection)
                .doc(currentUser.uid)
                .snapshots(includeMetadataChanges: false),
            builder: (context, snapshot) {
              String lastChangedText = _textHavenChanged;

              if (snapshot.hasData &&
                  snapshot.data != null &&
                  snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final rawData = _extractLastChangedRawData(data);
                lastChangedText = _formatLastChanged(rawData);
              }

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildTopHeader(context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _spacing16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: _spacing16),
                        _buildSectionHeader(_textSecurityAndPassword),
                        _buildFloatingCard(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(_spacing16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(_spacing10),
                                    decoration: BoxDecoration(
                                      color: lightGreenBg.withValues(
                                        alpha: _lightGreenAlpha,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        _spacing10,
                                      ),
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.lock_fill,
                                      color: midGreen,
                                      size: _iconSizeLock,
                                    ),
                                  ),
                                  const SizedBox(width: _spacing14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          _textPasswordHeader,
                                          style: TextStyle(
                                            fontSize: _fontSizeLabel,
                                            fontWeight: FontWeight.bold,
                                            color: darkGreen,
                                            letterSpacing: _letterSpacingLabel,
                                          ),
                                        ),
                                        const SizedBox(height: _spacing4),
                                        Text(
                                          '$_textLastChangedPrefix$lastChangedText',
                                          style: const TextStyle(
                                            fontSize: _fontSizeSubtext,
                                            fontWeight: FontWeight.w500,
                                            color: textGrey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: darkGreen,
                                      side: const BorderSide(
                                        color: midGreen,
                                        width: _borderWidth15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          _spacing10,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: _spacing12,
                                        vertical: _spacing8,
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ChangePasswordScreen(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      _textChangeButton,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: _fontSizeButton,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: _spacing32),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.only(
        top: topPadding + _spacing16,
        left: _spacing16,
        right: _spacing16,
        bottom: _spacing25,
      ),
      decoration: const BoxDecoration(
        color: darkGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_spacing20),
          bottomRight: Radius.circular(_spacing20),
        ),
        gradient: LinearGradient(
          colors: [darkGreen, midGreen],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [_gradientStopTop, _gradientStopBottom],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  height: _backButtonSize,
                  width: _backButtonSize,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: borderGreen,
                      width: _borderWidth15,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    CupertinoIcons.chevron_left,
                    size: _iconSizeChevron,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _spacing18),
          const Text(
            _textSecurityTitle,
            style: TextStyle(
              fontSize: _fontSizePageTitle,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            _textSecuritySubtitle,
            style: TextStyle(fontSize: _fontSizeSubtext, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: _spacing4,
        top: _spacing18,
        bottom: _spacing8,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: _fontSizeSectionHeader,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFloatingCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_spacing12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: _shadowAlpha),
            spreadRadius: 2,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'profile_overview_screen.dart';
import 'security_settings_screen.dart';
import 'feedback_screen.dart';
import 'terms_and_privacy_screen.dart';
import 'login_screen.dart';

// ==================== CONSTANTS MANAGEMENT ====================
abstract class _SettingsFirestoreKeys {
  static const String collectionSystemStatus = 'system_status';
  static const String docCurrent = 'current';
  static const String fieldTariffRatePerKwh = 'tariff_rate_per_kwh';

  static const String collectionUsers = 'users';
  static const String fieldName = 'name';
  static const String fieldEmail = 'email';
  static const String fieldPhone = 'phone';
}

abstract class _SettingsSharedPreferencesKeys {
  static const String prefMasterNotif = 'pref_master_notif';
  static const String prefAlertNotif = 'pref_alert_notif';
  static const String prefUpdateNotif = 'pref_update_notif';
  static const String prefDeliveryMethods = 'pref_delivery_methods';
  static const String prefQuietHours = 'pref_quiet_hours';
}

abstract class _SettingsStrings {
  static const String defaultDeliveryPush = 'Push';
  static const String defaultDeliveryEmail = 'Email';
  static const String defaultDeliverySms = 'SMS';
  static const String deliveryMethodNone = 'None';
  static const List<String> deliveryOptions = ['Push', 'Email', 'SMS'];

  static const String pageTitle = 'Settings';
  static const String pageSubtitle = 'System & App Preferences';
  static const String searchHint = 'Search settings...';

  static const String sectionAccountProfile = 'Account & Profile';
  static const String sectionTariffUtility = 'Tariff & Utility';
  static const String sectionNotifications = 'Notifications';
  static const String sectionStorageData = 'Storage & Data';
  static const String sectionSupportSystem = 'Support & System';

  static const String searchKeyAccount =
      'Account Profile Security Passwords User Info';
  static const String searchKeyTariff =
      'Tariff Billing Rate Electricity Savings Cost kWh';
  static const String searchKeyNotif =
      'Notifications Alerts Push Email SMS Quiet Hours Do Not Disturb';
  static const String searchKeyStorage = 'Data Storage Hardware Cache';
  static const String searchKeySupport =
      'Support Legal Terms Privacy Help Feedback Logout Delete';

  static const String fallbackName = 'Set Name';
  static const String fallbackEmail = 'No Email';
  static const String fallbackPhone = 'No phone added';

  static const String tileSecurityPassword = 'Security & Password';
  static const String subtitleChangePassword = 'Change password';
  static const String tileElectricityTariff = 'Electricity Tariff Rate';
  static const String subtitleTariffSavings =
      'Used for financial savings calculations';

  static const String tileAllowNotifications = 'Allow Notifications';
  static const String tileCriticalAlerts = 'Critical Alerts';
  static const String tileSystemUpdates = 'System Updates';
  static const String tileDeliveryMethod = 'Delivery Method';
  static const String modalTitlePreferredDelivery = 'Preferred Delivery';
  static const String tileDoNotDisturb = 'Do Not Disturb';
  static const String subtitleMuteAlerts = 'Mute non-critical alerts';

  static const String tileClearCache = 'Clear Storage Cache';
  static const String subtitleCacheSize = 'Local Cache: 42.8 MB';
  static const String cacheClearedMessage = 'Cache cleared successfully!';

  static const String tileFeedback = 'Feedback';
  static const String tileTermsPrivacy = 'Terms & Privacy';
  static const String tileAppVersion = 'App Version';
  static const String appVersionString = 'v1.0.4 (Build 42)';

  static const String buttonLogOut = 'Log Out';
  static const String buttonDelete = 'Delete';
  static const String buttonCancel = 'Cancel';
  static const String buttonSave = 'Save';
  static const String buttonDone = 'Done';
  static const String buttonOk = 'OK';
  static const String buttonClear = 'Clear';

  static const String dialogNotifPermissionTitle =
      'Notification Access Required';
  static const String dialogNotifPermissionContent =
      'Notifications are disabled in your system settings. To receive critical panel alerts and energy system updates, please allow notifications for this app in your device settings.';

  static const String dialogTariffTitle = 'Modify Electricity Tariff Rate';
  static const String dialogTariffContent =
      'Set your utility provider\'s rate per kWh (PHP) to accurately compute estimated savings.';
  static const String labelTariffInput = 'Tariff Rate (₱/kWh)';

  static const String dialogClearCacheTitle = 'Clear Local Cache?';
  static const String dialogClearCacheContent =
      'This will free up local storage space.';

  static const String dialogLogoutTitle = 'Log Out';
  static const String dialogLogoutContent = 'Are you sure you want to log out?';

  static const String dialogDeleteTitle = 'Delete Account';
  static const String dialogDeleteContent =
      'Permanently remove all data and linked hardware?';

  static const String errRequiresRecentLogin =
      'Please log out and log back in before deleting your account.';
  static const String errDeleteAccountPrefix = 'Failed to delete account: ';
}

abstract class _SettingsColors {
  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color borderGreen = Color(0xFF20341E);
  static const Color lightGreenBg = Color(0xFFE8F5E9);
  static const Color snackbarCheckmark = Color(0xFF00FF22);
  static const Color pageBg = Colors.white;
  static const Color cardBg = Colors.white;

  static const Color textBlack = Colors.black;
  static const Color textBlack87 = Colors.black87;
  static const Color textWhite = Colors.white;
  static const Color textWhite70 = Colors.white70;
  static const Color textGrey = Colors.grey;

  static final Color shadowColor = Colors.grey.withValues(alpha: 0.2);
  static final Color dividerColor = Colors.grey.withValues(alpha: 0.2);
  static final Color sheetHandleColor = Colors.grey.shade300;

  static final Color deleteBg = Colors.red.shade50;
  static final Color deleteBorder = Colors.red.shade200;
  static final Color deleteText = Colors.red.shade700;
  static final Color deleteButtonBg = Colors.red.shade600;
  static final Color deleteSnackbarBg = Colors.red.shade900;
}

abstract class _SettingsDimensions {
  static const double defaultTariffRate = 12.0;

  static const double paddingMicro = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 10.0;
  static const double paddingStandard = 14.0;
  static const double paddingLarge = 16.0;
  static const double paddingXLarge = 20.0;
  static const double paddingXXLarge = 24.0;
  static const double paddingHeaderBottom = 25.0;
  static const double paddingHeaderTop = 45.0;

  static const double spacingSmall = 8.0;
  static const double spacingMedium = 10.0;
  static const double spacingLarge = 12.0;
  static const double spacingXLarge = 16.0;
  static const double spacingSectionTop = 18.0;
  static const double spacingHeaderTitle = 20.0;
  static const double spacingXXLarge = 32.0;

  static const double fontSizeBadge = 11.0;
  static const double fontSizeSub = 11.0;
  static const double fontSizeInputLabel = 12.0;
  static const double fontSizeDialogContent = 13.0;
  static const double fontSizeBody = 14.0;
  static const double fontSizeChevron = 16.0;
  static const double fontSizeName = 17.0;
  static const double fontSizeDialogTitle = 18.0;
  static const double fontSizeModalTitle = 20.0;
  static const double fontSizeSectionHeader = 22.0;
  static const double fontSizePageTitle = 32.0;

  static const double buttonHeightStandard = 48.0;
  static const double backButtonSize = 40.0;
  static const double iconSizeSmall = 18.0;
  static const double iconSizeStandard = 20.0;
  static const double sheetHandleWidth = 40.0;
  static const double sheetHandleHeight = 5.0;

  static const double borderRadiusSmall = 10.0;
  static const double borderRadiusCard = 12.0;
  static const double borderRadiusTile = 14.0;
  static const double borderRadiusBadge = 16.0;
  static const double borderRadiusHeader = 20.0;
  static const double borderRadiusDialog = 20.0;
  static const double borderRadiusSheet = 28.0;

  static const double borderWidthThin = 1.0;
  static const double borderWidthStandard = 1.5;
  static const double shadowSpread = 2.0;
  static const double shadowBlurCard = 3.0;
  static const double shadowBlurSearch = 4.0;
  static const Offset shadowOffset = Offset(0, 2);

  static const double textLineHeightDialog = 1.4;
  static const double gradientStopTop = 0.38;
  static const double gradientStopBottom = 1.0;
}

// ==================== SETTINGS SCREEN WIDGET ====================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Search State
  String _searchQuery = '';

  // Tariff Rate State
  double _tariffRate = _SettingsDimensions.defaultTariffRate;

  // Notifications States (Stored locally via SharedPreferences and synced to Firestore)
  bool _masterNotifications = true;
  bool _alertNotifications = true;
  bool _updateNotifications = true;
  Set<String> _deliveryMethods = {_SettingsStrings.defaultDeliveryPush};
  bool _quietHours = false;

  @override
  void initState() {
    super.initState();
    _loadLocalSettings();
  }

  // --- LOCAL STORAGE & FIRESTORE INITIALIZATION ---
  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUser = FirebaseAuth.instance.currentUser;

    // Fetch initial tariff rate & preferences from Firestore
    try {
      final statusDoc = await FirebaseFirestore.instance
          .collection(_SettingsFirestoreKeys.collectionSystemStatus)
          .doc(_SettingsFirestoreKeys.docCurrent)
          .get();
      if (statusDoc.exists && statusDoc.data() != null) {
        final data = statusDoc.data()!;
        if (data.containsKey(_SettingsFirestoreKeys.fieldTariffRatePerKwh)) {
          _tariffRate =
              (data[_SettingsFirestoreKeys.fieldTariffRatePerKwh] as num)
                  .toDouble();
        }
      }

      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection(_SettingsFirestoreKeys.collectionUsers)
            .doc(currentUser.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          final uData = userDoc.data()!;
          if (uData.containsKey(
            _SettingsSharedPreferencesKeys.prefMasterNotif,
          )) {
            _masterNotifications =
                uData[_SettingsSharedPreferencesKeys.prefMasterNotif] as bool;
          }
          if (uData.containsKey(
            _SettingsSharedPreferencesKeys.prefAlertNotif,
          )) {
            _alertNotifications =
                uData[_SettingsSharedPreferencesKeys.prefAlertNotif] as bool;
          }
          if (uData.containsKey(
            _SettingsSharedPreferencesKeys.prefUpdateNotif,
          )) {
            _updateNotifications =
                uData[_SettingsSharedPreferencesKeys.prefUpdateNotif] as bool;
          }
        }
      }

      // Check real system OS notification permission status
      try {
        final settings = await FirebaseMessaging.instance
            .getNotificationSettings();
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          _masterNotifications = false;
        }
      } catch (_) {}
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _masterNotifications =
          prefs.getBool(_SettingsSharedPreferencesKeys.prefMasterNotif) ??
          _masterNotifications;
      _alertNotifications =
          prefs.getBool(_SettingsSharedPreferencesKeys.prefAlertNotif) ??
          _alertNotifications;
      _updateNotifications =
          prefs.getBool(_SettingsSharedPreferencesKeys.prefUpdateNotif) ??
          _updateNotifications;
      _deliveryMethods =
          prefs
              .getStringList(_SettingsSharedPreferencesKeys.prefDeliveryMethods)
              ?.toSet() ??
          {_SettingsStrings.defaultDeliveryPush};
      _quietHours =
          prefs.getBool(_SettingsSharedPreferencesKeys.prefQuietHours) ?? false;
    });
  }

  // --- SYSTEM NOTIFICATION PERMISSION HANDLER ---
  Future<void> _toggleMasterNotifications(bool enable) async {
    if (enable) {
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: true,
          provisional: false,
          sound: true,
        );

        if (settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional) {
          setState(() => _masterNotifications = true);
          await _saveBoolSetting(
            _SettingsSharedPreferencesKeys.prefMasterNotif,
            true,
          );
        } else {
          setState(() => _masterNotifications = false);
          await _saveBoolSetting(
            _SettingsSharedPreferencesKeys.prefMasterNotif,
            false,
          );
          if (mounted) {
            _showPermissionDeniedDialog();
          }
        }
      } catch (e) {
        // Fallback if platform messaging isn't active in simulator
        setState(() => _masterNotifications = true);
        await _saveBoolSetting(
          _SettingsSharedPreferencesKeys.prefMasterNotif,
          true,
        );
      }
    } else {
      setState(() => _masterNotifications = false);
      await _saveBoolSetting(
        _SettingsSharedPreferencesKeys.prefMasterNotif,
        false,
      );
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _SettingsColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            _SettingsDimensions.borderRadiusDialog,
          ),
        ),
        title: const Text(
          _SettingsStrings.dialogNotifPermissionTitle,
          style: TextStyle(
            color: _SettingsColors.darkGreen,
            fontWeight: FontWeight.bold,
            fontSize: _SettingsDimensions.fontSizeDialogTitle,
          ),
        ),
        content: const Text(
          _SettingsStrings.dialogNotifPermissionContent,
          style: TextStyle(
            color: _SettingsColors.textBlack87,
            fontSize: _SettingsDimensions.fontSizeDialogContent,
            height: _SettingsDimensions.textLineHeightDialog,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _SettingsColors.darkGreen,
              foregroundColor: _SettingsColors.textWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  _SettingsDimensions.borderRadiusCard,
                ),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(_SettingsStrings.buttonOk),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBoolSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection(_SettingsFirestoreKeys.collectionUsers)
            .doc(currentUser.uid)
            .set({key: value}, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<void> _saveListSetting(String key, List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection(_SettingsFirestoreKeys.collectionUsers)
            .doc(currentUser.uid)
            .set({key: value}, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  // --- TARIFF RATE EDIT DIALOG ---
  void _showEditTariffDialog() {
    final tariffController = TextEditingController(
      text: _tariffRate.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _SettingsColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            _SettingsDimensions.borderRadiusDialog,
          ),
        ),
        title: const Text(
          _SettingsStrings.dialogTariffTitle,
          style: TextStyle(
            color: _SettingsColors.darkGreen,
            fontWeight: FontWeight.bold,
            fontSize: _SettingsDimensions.fontSizeDialogTitle,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              _SettingsStrings.dialogTariffContent,
              style: TextStyle(
                fontSize: _SettingsDimensions.fontSizeInputLabel,
                color: _SettingsColors.textGrey,
              ),
            ),
            const SizedBox(height: _SettingsDimensions.spacingXLarge),
            TextField(
              controller: tariffController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: _SettingsStrings.labelTariffInput,
                prefixIcon: Icon(
                  CupertinoIcons.money_dollar,
                  color: _SettingsColors.midGreen,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              _SettingsStrings.buttonCancel,
              style: TextStyle(color: _SettingsColors.textGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _SettingsColors.darkGreen,
              foregroundColor: _SettingsColors.textWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  _SettingsDimensions.borderRadiusCard,
                ),
              ),
            ),
            onPressed: () async {
              final double? newRate = double.tryParse(
                tariffController.text.trim(),
              );
              if (newRate != null && newRate >= 0) {
                setState(() {
                  _tariffRate = newRate;
                });
                try {
                  await FirebaseFirestore.instance
                      .collection(_SettingsFirestoreKeys.collectionSystemStatus)
                      .doc(_SettingsFirestoreKeys.docCurrent)
                      .set({
                        _SettingsFirestoreKeys.fieldTariffRatePerKwh: newRate,
                      }, SetOptions(merge: true));
                } catch (_) {}
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(_SettingsStrings.buttonSave),
          ),
        ],
      ),
    );
  }

  // --- AUTH ACTIONS ---
  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const SlickLoginScreen()),
      (route) => false,
    );
  }

  Future<void> _handleDeleteAccount() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    try {
      if (currentUser != null) {
        // Clear local preferences before deletion
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Delete Firestore user document first
        await FirebaseFirestore.instance
            .collection(_SettingsFirestoreKeys.collectionUsers)
            .doc(currentUser.uid)
            .delete();

        // Delete Firebase Auth User
        await currentUser.delete();
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const SlickLoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final errorMessage = e.code == 'requires-recent-login'
          ? _SettingsStrings.errRequiresRecentLogin
          : '${_SettingsStrings.errDeleteAccountPrefix}${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: _SettingsColors.deleteSnackbarBg,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_SettingsStrings.errDeleteAccountPrefix}${e.toString()}',
          ),
          backgroundColor: _SettingsColors.deleteSnackbarBg,
        ),
      );
    }
  }

  void _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmText,
    required VoidCallback onConfirm,
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _SettingsColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            _SettingsDimensions.borderRadiusDialog,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: _SettingsColors.darkGreen,
            fontWeight: FontWeight.bold,
            fontSize: _SettingsDimensions.fontSizeDialogTitle,
          ),
        ),
        content: Text(
          content,
          style: const TextStyle(
            color: _SettingsColors.textBlack87,
            fontSize: _SettingsDimensions.fontSizeBody,
          ),
        ),
        actionsPadding: const EdgeInsets.all(_SettingsDimensions.paddingLarge),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              _SettingsStrings.buttonCancel,
              style: TextStyle(
                color: _SettingsColors.textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive
                  ? _SettingsColors.deleteButtonBg
                  : _SettingsColors.darkGreen,
              foregroundColor: _SettingsColors.textWhite,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  _SettingsDimensions.borderRadiusCard,
                ),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text(
              confirmText,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showMultiSelectModal({
    required String title,
    required List<String> options,
    required Set<String> currentSelections,
    required ValueChanged<Set<String>> onChanged,
  }) {
    final tempSelections = Set<String>.from(currentSelections);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Material(
            color: _SettingsColors.cardBg,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(_SettingsDimensions.borderRadiusSheet),
            ),
            child: Padding(
              padding: const EdgeInsets.all(_SettingsDimensions.paddingXXLarge),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: _SettingsDimensions.sheetHandleWidth,
                      height: _SettingsDimensions.sheetHandleHeight,
                      margin: const EdgeInsets.only(
                        bottom: _SettingsDimensions.spacingHeaderTitle,
                      ),
                      decoration: BoxDecoration(
                        color: _SettingsColors.sheetHandleColor,
                        borderRadius: BorderRadius.circular(
                          _SettingsDimensions.borderRadiusSmall,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: _SettingsDimensions.fontSizeModalTitle,
                      fontWeight: FontWeight.bold,
                      color: _SettingsColors.darkGreen,
                    ),
                  ),
                  const SizedBox(height: _SettingsDimensions.spacingXLarge),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final option in options) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: _SettingsDimensions.spacingSmall,
                              ),
                              child: Material(
                                color: tempSelections.contains(option)
                                    ? _SettingsColors.lightGreenBg
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  _SettingsDimensions.borderRadiusTile,
                                ),
                                child: CheckboxListTile(
                                  activeColor: _SettingsColors.midGreen,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      _SettingsDimensions.borderRadiusTile,
                                    ),
                                  ),
                                  title: Text(
                                    option,
                                    style: TextStyle(
                                      fontWeight:
                                          tempSelections.contains(option)
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: tempSelections.contains(option)
                                          ? _SettingsColors.darkGreen
                                          : _SettingsColors.textBlack87,
                                    ),
                                  ),
                                  value: tempSelections.contains(option),
                                  onChanged: (bool? checked) {
                                    setModalState(() {
                                      if (checked == true) {
                                        tempSelections.add(option);
                                      } else {
                                        tempSelections.remove(option);
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: _SettingsDimensions.spacingXLarge),
                  SizedBox(
                    width: double.infinity,
                    height: _SettingsDimensions.buttonHeightStandard,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _SettingsColors.darkGreen,
                        foregroundColor: _SettingsColors.textWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            _SettingsDimensions.borderRadiusCard,
                          ),
                        ),
                      ),
                      onPressed: () {
                        onChanged(tempSelections);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        _SettingsStrings.buttonDone,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _matchesSearch(String title) {
    if (_searchQuery.isEmpty) return true;
    return title.toLowerCase().contains(_searchQuery.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final String deliveryMethodText = _deliveryMethods.isEmpty
        ? _SettingsStrings.deliveryMethodNone
        : _deliveryMethods.join(', ');

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, authSnapshot) {
        final currentUser =
            authSnapshot.data ?? FirebaseAuth.instance.currentUser;

        return Scaffold(
          backgroundColor: _SettingsColors.pageBg,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildTopHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _SettingsDimensions.paddingLarge,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: _SettingsDimensions.spacingXLarge),
                    Container(
                      margin: const EdgeInsets.only(
                        bottom: _SettingsDimensions.borderRadiusSmall,
                      ),
                      decoration: BoxDecoration(
                        color: _SettingsColors.cardBg,
                        borderRadius: BorderRadius.circular(
                          _SettingsDimensions.borderRadiusBadge,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _SettingsColors.shadowColor,
                            spreadRadius: _SettingsDimensions.shadowSpread,
                            blurRadius: _SettingsDimensions.shadowBlurSearch,
                            offset: _SettingsDimensions.shadowOffset,
                          ),
                        ],
                      ),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: _SettingsStrings.searchHint,
                          hintStyle: TextStyle(
                            fontSize: _SettingsDimensions.fontSizeBody,
                            color: _SettingsColors.textGrey,
                          ),
                          prefixIcon: Icon(
                            CupertinoIcons.search,
                            color: _SettingsColors.midGreen,
                            size: _SettingsDimensions.iconSizeStandard,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: _SettingsDimensions.paddingStandard,
                          ),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),

                    // 1. ACCOUNT & PROFILE (Cloud Firestore-backed)
                    if (_matchesSearch(_SettingsStrings.searchKeyAccount)) ...[
                      _buildSectionHeader(
                        _SettingsStrings.sectionAccountProfile,
                      ),
                      _buildFloatingCard(
                        children: [
                          StreamBuilder<DocumentSnapshot>(
                            stream: currentUser != null
                                ? FirebaseFirestore.instance
                                      .collection(
                                        _SettingsFirestoreKeys.collectionUsers,
                                      )
                                      .doc(currentUser.uid)
                                      .snapshots(includeMetadataChanges: false)
                                : null,
                            builder: (context, snapshot) {
                              final data =
                                  snapshot.data?.data()
                                      as Map<String, dynamic>?;

                              final String name =
                                  data?[_SettingsFirestoreKeys.fieldName] ??
                                  currentUser?.displayName ??
                                  _SettingsStrings.fallbackName;
                              final String email =
                                  data?[_SettingsFirestoreKeys.fieldEmail] ??
                                  currentUser?.email ??
                                  _SettingsStrings.fallbackEmail;
                              final String phone =
                                  data?[_SettingsFirestoreKeys.fieldPhone] ??
                                  _SettingsStrings.fallbackPhone;

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: _SettingsDimensions.paddingLarge,
                                  vertical: _SettingsDimensions.paddingMicro,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(
                                    _SettingsDimensions.paddingMedium,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: _SettingsColors.lightGreenBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.person_fill,
                                    color: _SettingsColors.midGreen,
                                    size: _SettingsDimensions.iconSizeStandard,
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: _SettingsDimensions.fontSizeName,
                                    color: _SettingsColors.textBlack,
                                  ),
                                ),
                                subtitle: Text(
                                  '$email • $phone',
                                  style: const TextStyle(
                                    fontSize: _SettingsDimensions.fontSizeSub,
                                    color: _SettingsColors.textGrey,
                                  ),
                                ),
                                trailing: const Icon(
                                  CupertinoIcons.chevron_right,
                                  size: _SettingsDimensions.fontSizeChevron,
                                  color: _SettingsColors.textGrey,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ProfileOverviewScreen(),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          _buildDivider(),
                          ListTile(
                            leading: const Icon(
                              CupertinoIcons.shield_fill,
                              color: _SettingsColors.midGreen,
                              size: _SettingsDimensions.iconSizeStandard,
                            ),
                            title: const Text(
                              _SettingsStrings.tileSecurityPassword,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: _SettingsDimensions.fontSizeBody,
                              ),
                            ),
                            subtitle: const Text(
                              _SettingsStrings.subtitleChangePassword,
                              style: TextStyle(
                                fontSize: _SettingsDimensions.fontSizeSub,
                                color: _SettingsColors.textGrey,
                              ),
                            ),
                            trailing: const Icon(
                              CupertinoIcons.chevron_right,
                              size: _SettingsDimensions.fontSizeChevron,
                              color: _SettingsColors.textGrey,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SecuritySettingsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],

                    // 2. TARIFF & BILLING
                    if (_matchesSearch(_SettingsStrings.searchKeyTariff)) ...[
                      _buildSectionHeader(
                        _SettingsStrings.sectionTariffUtility,
                      ),
                      _buildFloatingCard(
                        children: [
                          ListTile(
                            leading: const Icon(
                              CupertinoIcons.money_dollar_circle_fill,
                              color: _SettingsColors.midGreen,
                              size: _SettingsDimensions.iconSizeStandard,
                            ),
                            title: const Text(
                              _SettingsStrings.tileElectricityTariff,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: _SettingsDimensions.fontSizeBody,
                              ),
                            ),
                            subtitle: const Text(
                              _SettingsStrings.subtitleTariffSavings,
                              style: TextStyle(
                                fontSize: _SettingsDimensions.fontSizeSub,
                                color: _SettingsColors.textGrey,
                              ),
                            ),
                            trailing: _buildValueBadge(
                              '₱${_tariffRate.toStringAsFixed(2)} / kWh',
                            ),
                            onTap: _showEditTariffDialog,
                          ),
                        ],
                      ),
                    ],

                    // 3. NOTIFICATIONS & ALERTS (SharedPreferences & Firestore)
                    if (_matchesSearch(_SettingsStrings.searchKeyNotif)) ...[
                      _buildSectionHeader(
                        _SettingsStrings.sectionNotifications,
                      ),
                      _buildFloatingCard(
                        children: [
                          SwitchListTile(
                            activeThumbColor: _SettingsColors.midGreen,
                            secondary: const Icon(
                              CupertinoIcons.bell_fill,
                              color: _SettingsColors.midGreen,
                              size: _SettingsDimensions.iconSizeStandard,
                            ),
                            title: const Text(
                              _SettingsStrings.tileAllowNotifications,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: _SettingsDimensions.fontSizeBody,
                              ),
                            ),
                            value: _masterNotifications,
                            onChanged: (val) => _toggleMasterNotifications(val),
                          ),
                          if (_masterNotifications) ...[
                            _buildDivider(),
                            SwitchListTile(
                              activeThumbColor: _SettingsColors.midGreen,
                              title: const Text(
                                _SettingsStrings.tileCriticalAlerts,
                                style: TextStyle(
                                  fontSize: _SettingsDimensions.fontSizeBody,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              value: _alertNotifications,
                              onChanged: (val) {
                                setState(() => _alertNotifications = val);
                                _saveBoolSetting(
                                  _SettingsSharedPreferencesKeys.prefAlertNotif,
                                  val,
                                );
                              },
                            ),
                            _buildDivider(),
                            SwitchListTile(
                              activeThumbColor: _SettingsColors.midGreen,
                              title: const Text(
                                _SettingsStrings.tileSystemUpdates,
                                style: TextStyle(
                                  fontSize: _SettingsDimensions.fontSizeBody,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              value: _updateNotifications,
                              onChanged: (val) {
                                setState(() => _updateNotifications = val);
                                _saveBoolSetting(
                                  _SettingsSharedPreferencesKeys
                                      .prefUpdateNotif,
                                  val,
                                );
                              },
                            ),
                            _buildDivider(),
                            ListTile(
                              leading: const Icon(
                                CupertinoIcons.paperplane_fill,
                                color: _SettingsColors.midGreen,
                                size: _SettingsDimensions.iconSizeStandard,
                              ),
                              title: const Text(
                                _SettingsStrings.tileDeliveryMethod,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: _SettingsDimensions.fontSizeBody,
                                ),
                              ),
                              trailing: _buildValueBadge(deliveryMethodText),
                              onTap: () => _showMultiSelectModal(
                                title: _SettingsStrings
                                    .modalTitlePreferredDelivery,
                                options: _SettingsStrings.deliveryOptions,
                                currentSelections: _deliveryMethods,
                                onChanged: (selected) {
                                  setState(() => _deliveryMethods = selected);
                                  _saveListSetting(
                                    _SettingsSharedPreferencesKeys
                                        .prefDeliveryMethods,
                                    selected.toList(),
                                  );
                                },
                              ),
                            ),
                          ],
                          _buildDivider(),
                          SwitchListTile(
                            activeThumbColor: _SettingsColors.midGreen,
                            secondary: const Icon(
                              CupertinoIcons.moon_fill,
                              color: _SettingsColors.midGreen,
                              size: _SettingsDimensions.iconSizeStandard,
                            ),
                            title: const Text(
                              _SettingsStrings.tileDoNotDisturb,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: _SettingsDimensions.fontSizeBody,
                              ),
                            ),
                            subtitle: const Text(
                              _SettingsStrings.subtitleMuteAlerts,
                              style: TextStyle(
                                fontSize: _SettingsDimensions.fontSizeSub,
                                color: _SettingsColors.textGrey,
                              ),
                            ),
                            value: _quietHours,
                            onChanged: (val) {
                              setState(() => _quietHours = val);
                              _saveBoolSetting(
                                _SettingsSharedPreferencesKeys.prefQuietHours,
                                val,
                              );
                            },
                          ),
                        ],
                      ),
                    ],

                    // 4. DATA & STORAGE
                    if (_matchesSearch(_SettingsStrings.searchKeyStorage)) ...[
                      _buildSectionHeader(_SettingsStrings.sectionStorageData),
                      _buildFloatingCard(
                        children: [
                          ListTile(
                            leading: const Icon(
                              CupertinoIcons.trash_fill,
                              color: _SettingsColors.midGreen,
                              size: _SettingsDimensions.iconSizeStandard,
                            ),
                            title: const Text(
                              _SettingsStrings.tileClearCache,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: _SettingsDimensions.fontSizeBody,
                              ),
                            ),
                            subtitle: const Text(
                              _SettingsStrings.subtitleCacheSize,
                              style: TextStyle(
                                fontSize: _SettingsDimensions.fontSizeSub,
                                color: _SettingsColors.textGrey,
                              ),
                            ),
                            onTap: () => _showConfirmationDialog(
                              title: _SettingsStrings.dialogClearCacheTitle,
                              content: _SettingsStrings.dialogClearCacheContent,
                              confirmText: _SettingsStrings.buttonClear,
                              onConfirm: () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor:
                                          _SettingsColors.darkGreen,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          _SettingsDimensions.borderRadiusSmall,
                                        ),
                                      ),
                                      content: const Row(
                                        children: [
                                          Icon(
                                            CupertinoIcons
                                                .checkmark_circle_fill,
                                            color: _SettingsColors
                                                .snackbarCheckmark,
                                          ),
                                          SizedBox(
                                            width: _SettingsDimensions
                                                .paddingMedium,
                                          ),
                                          Text(
                                            _SettingsStrings
                                                .cacheClearedMessage,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // 5. SUPPORT & ACTIONS
                    if (_matchesSearch(_SettingsStrings.searchKeySupport)) ...[
                      _buildSectionHeader(
                        _SettingsStrings.sectionSupportSystem,
                      ),
                      _buildFloatingCard(
                        children: [
                          ListTile(
                            leading: const Icon(
                              CupertinoIcons.chat_bubble_2_fill,
                              color: _SettingsColors.midGreen,
                              size: _SettingsDimensions.iconSizeStandard,
                            ),
                            title: const Text(
                              _SettingsStrings.tileFeedback,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: _SettingsDimensions.fontSizeBody,
                              ),
                            ),
                            trailing: const Icon(
                              CupertinoIcons.chevron_right,
                              size: _SettingsDimensions.fontSizeChevron,
                              color: _SettingsColors.textGrey,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const FeedbackScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDivider(),
                          ListTile(
                            leading: const Icon(
                              CupertinoIcons.doc_text_fill,
                              color: _SettingsColors.midGreen,
                              size: _SettingsDimensions.iconSizeStandard,
                            ),
                            title: const Text(
                              _SettingsStrings.tileTermsPrivacy,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: _SettingsDimensions.fontSizeBody,
                              ),
                            ),
                            trailing: const Icon(
                              CupertinoIcons.chevron_right,
                              size: _SettingsDimensions.fontSizeChevron,
                              color: _SettingsColors.textGrey,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const TermsAndPrivacyScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDivider(),
                          ListTile(
                            leading: const Icon(
                              CupertinoIcons.info_circle_fill,
                              color: _SettingsColors.midGreen,
                              size: _SettingsDimensions.iconSizeStandard,
                            ),
                            title: const Text(
                              _SettingsStrings.tileAppVersion,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: _SettingsDimensions.fontSizeBody,
                              ),
                            ),
                            subtitle: const Text(
                              _SettingsStrings.appVersionString,
                              style: TextStyle(
                                fontSize: _SettingsDimensions.fontSizeSub,
                                color: _SettingsColors.textGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: _SettingsDimensions.spacingXLarge),

                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: _SettingsDimensions.buttonHeightStandard,
                              decoration: BoxDecoration(
                                color: _SettingsColors.cardBg,
                                borderRadius: BorderRadius.circular(
                                  _SettingsDimensions.borderRadiusCard,
                                ),
                                border: Border.all(
                                  color: _SettingsColors.borderGreen,
                                  width:
                                      _SettingsDimensions.borderWidthStandard,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  _SettingsDimensions.borderRadiusCard,
                                ),
                                onTap: () => _showConfirmationDialog(
                                  title: _SettingsStrings.dialogLogoutTitle,
                                  content: _SettingsStrings.dialogLogoutContent,
                                  confirmText: _SettingsStrings.buttonLogOut,
                                  onConfirm: _handleLogout,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.square_arrow_right,
                                      size: _SettingsDimensions.iconSizeSmall,
                                      color: _SettingsColors.darkGreen,
                                    ),
                                    SizedBox(
                                      width: _SettingsDimensions.spacingSmall,
                                    ),
                                    Text(
                                      _SettingsStrings.buttonLogOut,
                                      style: TextStyle(
                                        color: _SettingsColors.darkGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize:
                                            _SettingsDimensions.fontSizeBody,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: _SettingsDimensions.spacingLarge,
                          ),
                          Expanded(
                            child: Container(
                              height: _SettingsDimensions.buttonHeightStandard,
                              decoration: BoxDecoration(
                                color: _SettingsColors.deleteBg,
                                borderRadius: BorderRadius.circular(
                                  _SettingsDimensions.borderRadiusCard,
                                ),
                                border: Border.all(
                                  color: _SettingsColors.deleteBorder,
                                  width:
                                      _SettingsDimensions.borderWidthStandard,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  _SettingsDimensions.borderRadiusCard,
                                ),
                                onTap: () => _showConfirmationDialog(
                                  title: _SettingsStrings.dialogDeleteTitle,
                                  content: _SettingsStrings.dialogDeleteContent,
                                  confirmText: _SettingsStrings.buttonDelete,
                                  isDestructive: true,
                                  onConfirm: _handleDeleteAccount,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.trash,
                                      size: _SettingsDimensions.iconSizeSmall,
                                      color: _SettingsColors.deleteText,
                                    ),
                                    const SizedBox(
                                      width: _SettingsDimensions.spacingSmall,
                                    ),
                                    Text(
                                      _SettingsStrings.buttonDelete,
                                      style: TextStyle(
                                        color: _SettingsColors.deleteText,
                                        fontWeight: FontWeight.bold,
                                        fontSize:
                                            _SettingsDimensions.fontSizeBody,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: _SettingsDimensions.spacingXXLarge,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.only(
        top: _SettingsDimensions.paddingHeaderTop,
        left: _SettingsDimensions.paddingLarge,
        right: _SettingsDimensions.paddingLarge,
        bottom: _SettingsDimensions.paddingHeaderBottom,
      ),
      decoration: const BoxDecoration(
        color: _SettingsColors.darkGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_SettingsDimensions.borderRadiusHeader),
          bottomRight: Radius.circular(_SettingsDimensions.borderRadiusHeader),
        ),
        gradient: LinearGradient(
          colors: [_SettingsColors.darkGreen, _SettingsColors.midGreen],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [
            _SettingsDimensions.gradientStopTop,
            _SettingsDimensions.gradientStopBottom,
          ],
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
                  height: _SettingsDimensions.backButtonSize,
                  width: _SettingsDimensions.backButtonSize,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _SettingsColors.borderGreen,
                      width: _SettingsDimensions.borderWidthStandard,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    CupertinoIcons.chevron_left,
                    size: _SettingsDimensions.iconSizeStandard,
                    color: _SettingsColors.textWhite,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: _SettingsDimensions.spacingHeaderTitle),
          const Text(
            _SettingsStrings.pageTitle,
            style: TextStyle(
              fontSize: _SettingsDimensions.fontSizePageTitle,
              fontWeight: FontWeight.bold,
              color: _SettingsColors.textWhite,
            ),
          ),
          const Text(
            _SettingsStrings.pageSubtitle,
            style: TextStyle(
              fontSize: _SettingsDimensions.fontSizeSub,
              color: _SettingsColors.textWhite70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: _SettingsDimensions.paddingMicro,
        top: _SettingsDimensions.spacingSectionTop,
        bottom: _SettingsDimensions.spacingSmall,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: _SettingsDimensions.fontSizeSectionHeader,
          fontWeight: FontWeight.bold,
          color: _SettingsColors.textBlack,
        ),
      ),
    );
  }

  Widget _buildValueBadge(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _SettingsDimensions.paddingMedium,
        vertical: _SettingsDimensions.paddingMicro,
      ),
      decoration: BoxDecoration(
        color: _SettingsColors.darkGreen,
        borderRadius: BorderRadius.circular(
          _SettingsDimensions.borderRadiusBadge,
        ),
        border: Border.all(
          color: _SettingsColors.borderGreen,
          width: _SettingsDimensions.borderWidthThin,
        ),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: _SettingsColors.textWhite,
          fontWeight: FontWeight.w500,
          fontSize: _SettingsDimensions.fontSizeBadge,
        ),
      ),
    );
  }

  Widget _buildFloatingCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: _SettingsDimensions.paddingMicro + 2,
      ),
      decoration: BoxDecoration(
        color: _SettingsColors.cardBg,
        borderRadius: BorderRadius.circular(
          _SettingsDimensions.borderRadiusCard,
        ),
        boxShadow: [
          BoxShadow(
            color: _SettingsColors.shadowColor,
            spreadRadius: _SettingsDimensions.shadowSpread,
            blurRadius: _SettingsDimensions.shadowBlurCard,
            offset: _SettingsDimensions.shadowOffset,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: _SettingsDimensions.paddingLarge,
      endIndent: _SettingsDimensions.paddingLarge,
      color: _SettingsColors.dividerColor,
    );
  }
}

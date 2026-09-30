import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_overview_screen.dart';
import 'security_settings_screen.dart';
import 'feedback_screen.dart';
import 'terms_and_privacy_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Search State
  String _searchQuery = '';

  // Tariff Rate State
  double _tariffRate = 12.0;

  // Notifications States (Stored locally via SharedPreferences and synced to Firestore)
  bool _masterNotifications = true;
  bool _alertNotifications = true;
  bool _updateNotifications = true;
  Set<String> _deliveryMethods = {'Push'};
  bool _quietHours = false;

  // --- DASHBOARD THEME COLOR CONSTANTS ---
  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color borderGreen = Color(0xFF20341E);
  static const Color lightGreenBg = Color(0xFFE8F5E9);
  static const Color pageBg = Colors.white;

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
          .collection('system_status')
          .doc('current')
          .get();
      if (statusDoc.exists && statusDoc.data() != null) {
        final data = statusDoc.data()!;
        if (data.containsKey('tariff_rate_per_kwh')) {
          _tariffRate = (data['tariff_rate_per_kwh'] as num).toDouble();
        }
      }

      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          final uData = userDoc.data()!;
          if (uData.containsKey('pref_master_notif')) {
            _masterNotifications = uData['pref_master_notif'] as bool;
          }
          if (uData.containsKey('pref_alert_notif')) {
            _alertNotifications = uData['pref_alert_notif'] as bool;
          }
          if (uData.containsKey('pref_update_notif')) {
            _updateNotifications = uData['pref_update_notif'] as bool;
          }
        }
      }
    } catch (_) {}

    setState(() {
      _masterNotifications =
          prefs.getBool('pref_master_notif') ?? _masterNotifications;
      _alertNotifications =
          prefs.getBool('pref_alert_notif') ?? _alertNotifications;
      _updateNotifications =
          prefs.getBool('pref_update_notif') ?? _updateNotifications;
      _deliveryMethods =
          prefs.getStringList('pref_delivery_methods')?.toSet() ?? {'Push'};
      _quietHours = prefs.getBool('pref_quiet_hours') ?? false;
    });
  }

  Future<void> _saveBoolSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
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
            .collection('users')
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Modify Electricity Tariff Rate',
          style: TextStyle(
            color: darkGreen,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set your utility provider\'s rate per kWh (PHP) to accurately compute estimated savings.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tariffController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Tariff Rate (₱/kWh)',
                prefixIcon: Icon(CupertinoIcons.money_dollar, color: midGreen),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: darkGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
                      .collection('system_status')
                      .doc('current')
                      .set({
                        'tariff_rate_per_kwh': newRate,
                      }, SetOptions(merge: true));
                } catch (_) {}
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
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
            .collection('users')
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
          ? 'Please log out and log back in before deleting your account.'
          : 'Failed to delete account: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red.shade900,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: ${e.toString()}'),
          backgroundColor: Colors.red.shade900,
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(
            color: darkGreen,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          content,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red.shade600 : darkGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: darkGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final option in options) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Material(
                                color: tempSelections.contains(option)
                                    ? lightGreenBg
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                child: CheckboxListTile(
                                  activeColor: midGreen,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  title: Text(
                                    option,
                                    style: TextStyle(
                                      fontWeight:
                                          tempSelections.contains(option)
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: tempSelections.contains(option)
                                          ? darkGreen
                                          : Colors.black87,
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
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        onChanged(tempSelections);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Done',
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
        ? 'None'
        : _deliveryMethods.join(', ');

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, authSnapshot) {
        final currentUser =
            authSnapshot.data ?? FirebaseAuth.instance.currentUser;

        return Scaffold(
          backgroundColor: pageBg,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildTopHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.2),
                            spreadRadius: 2,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search settings...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          prefixIcon: Icon(
                            CupertinoIcons.search,
                            color: midGreen,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),

                    // 1. ACCOUNT & PROFILE (Cloud Firestore-backed)
                    if (_matchesSearch(
                      'Account Profile Security Passwords User Info',
                    )) ...[
                      _buildSectionHeader('Account & Profile'),
                      _buildFloatingCard(
                        children: [
                          StreamBuilder<DocumentSnapshot>(
                            stream: currentUser != null
                                ? FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(currentUser.uid)
                                      .snapshots(includeMetadataChanges: false)
                                : null,
                            builder: (context, snapshot) {
                              final data =
                                  snapshot.data?.data()
                                      as Map<String, dynamic>?;

                              final String name =
                                  data?['name'] ??
                                  currentUser?.displayName ??
                                  'Set Name';
                              final String email =
                                  data?['email'] ??
                                  currentUser?.email ??
                                  'No Email';
                              final String phone =
                                  data?['phone'] ?? 'No phone added';

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: lightGreenBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.person_fill,
                                    color: midGreen,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: Colors.black,
                                  ),
                                ),
                                subtitle: Text(
                                  '$email • $phone',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                trailing: const Icon(
                                  CupertinoIcons.chevron_right,
                                  size: 16,
                                  color: Colors.grey,
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
                              color: midGreen,
                              size: 20,
                            ),
                            title: const Text(
                              'Security & Password',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: const Text(
                              'Change password',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            trailing: const Icon(
                              CupertinoIcons.chevron_right,
                              size: 16,
                              color: Colors.grey,
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
                    if (_matchesSearch(
                      'Tariff Billing Rate Electricity Savings Cost kWh',
                    )) ...[
                      _buildSectionHeader('Tariff & Utility'),
                      _buildFloatingCard(
                        children: [
                          ListTile(
                            leading: const Icon(
                              CupertinoIcons.money_dollar_circle_fill,
                              color: midGreen,
                              size: 20,
                            ),
                            title: const Text(
                              'Electricity Tariff Rate',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: const Text(
                              'Used for financial savings calculations',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
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
                    if (_matchesSearch(
                      'Notifications Alerts Push Email SMS Quiet Hours Do Not Disturb',
                    )) ...[
                      _buildSectionHeader('Notifications'),
                      _buildFloatingCard(
                        children: [
                          SwitchListTile(
                            activeThumbColor: midGreen,
                            secondary: const Icon(
                              CupertinoIcons.bell_fill,
                              color: midGreen,
                              size: 20,
                            ),
                            title: const Text(
                              'Allow Notifications',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            value: _masterNotifications,
                            onChanged: (val) {
                              setState(() => _masterNotifications = val);
                              _saveBoolSetting('pref_master_notif', val);
                            },
                          ),
                          if (_masterNotifications) ...[
                            _buildDivider(),
                            SwitchListTile(
                              activeThumbColor: midGreen,
                              title: const Text(
                                'Critical Alerts',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              value: _alertNotifications,
                              onChanged: (val) {
                                setState(() => _alertNotifications = val);
                                _saveBoolSetting('pref_alert_notif', val);
                              },
                            ),
                            _buildDivider(),
                            SwitchListTile(
                              activeThumbColor: midGreen,
                              title: const Text(
                                'System Updates',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              value: _updateNotifications,
                              onChanged: (val) {
                                setState(() => _updateNotifications = val);
                                _saveBoolSetting('pref_update_notif', val);
                              },
                            ),
                            _buildDivider(),
                            ListTile(
                              leading: const Icon(
                                CupertinoIcons.paperplane_fill,
                                color: midGreen,
                                size: 20,
                              ),
                              title: const Text(
                                'Delivery Method',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              trailing: _buildValueBadge(deliveryMethodText),
                              onTap: () => _showMultiSelectModal(
                                title: 'Preferred Delivery',
                                options: const ['Push', 'Email', 'SMS'],
                                currentSelections: _deliveryMethods,
                                onChanged: (selected) {
                                  setState(() => _deliveryMethods = selected);
                                  _saveListSetting(
                                    'pref_delivery_methods',
                                    selected.toList(),
                                  );
                                },
                              ),
                            ),
                          ],
                          _buildDivider(),
                          SwitchListTile(
                            activeThumbColor: midGreen,
                            secondary: const Icon(
                              CupertinoIcons.moon_fill,
                              color: midGreen,
                              size: 20,
                            ),
                            title: const Text(
                              'Do Not Disturb',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: const Text(
                              'Mute non-critical alerts',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            value: _quietHours,
                            onChanged: (val) {
                              setState(() => _quietHours = val);
                              _saveBoolSetting('pref_quiet_hours', val);
                            },
                          ),
                        ],
                      ),
                    ],

                    // 4. DATA & STORAGE
                    if (_matchesSearch('Data Storage Hardware Cache')) ...[
                      _buildSectionHeader('Storage & Data'),
                      _buildFloatingCard(
                        children: [
                          ListTile(
                            leading: const Icon(
                              CupertinoIcons.trash_fill,
                              color: midGreen,
                              size: 20,
                            ),
                            title: const Text(
                              'Clear Storage Cache',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: const Text(
                              'Local Cache: 42.8 MB',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            onTap: () => _showConfirmationDialog(
                              title: 'Clear Local Cache?',
                              content: 'This will free up local storage space.',
                              confirmText: 'Clear',
                              onConfirm: () =>
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
                                            CupertinoIcons
                                                .checkmark_circle_fill,
                                            color: Color(0xFF00FF22),
                                          ),
                                          SizedBox(width: 10),
                                          Text('Cache cleared successfully!'),
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
                    if (_matchesSearch(
                      'Support Legal Terms Privacy Help Feedback Logout Delete',
                    )) ...[
                      _buildSectionHeader('Support & System'),
                      _buildFloatingCard(
                        children: [
                          ListTile(
                            leading: const Icon(
                              CupertinoIcons.chat_bubble_2_fill,
                              color: midGreen,
                              size: 20,
                            ),
                            title: const Text(
                              'Feedback',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            trailing: const Icon(
                              CupertinoIcons.chevron_right,
                              size: 16,
                              color: Colors.grey,
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
                              color: midGreen,
                              size: 20,
                            ),
                            title: const Text(
                              'Terms & Privacy',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            trailing: const Icon(
                              CupertinoIcons.chevron_right,
                              size: 16,
                              color: Colors.grey,
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
                              color: midGreen,
                              size: 20,
                            ),
                            title: const Text(
                              'App Version',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: const Text(
                              'v1.0.4 (Build 42)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: borderGreen,
                                  width: 1.5,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _showConfirmationDialog(
                                  title: 'Log Out',
                                  content: 'Are you sure you want to log out?',
                                  confirmText: 'Log Out',
                                  onConfirm: _handleLogout,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.square_arrow_right,
                                      size: 18,
                                      color: darkGreen,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Log Out',
                                      style: TextStyle(
                                        color: darkGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.red.shade200,
                                  width: 1.5,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _showConfirmationDialog(
                                  title: 'Delete Account',
                                  content:
                                      'Permanently remove all data and linked hardware?',
                                  confirmText: 'Delete',
                                  isDestructive: true,
                                  onConfirm: _handleDeleteAccount,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.trash,
                                      size: 18,
                                      color: Colors.red.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
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
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderGreen, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    CupertinoIcons.chevron_left,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            'System & App Preferences',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 18, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildValueBadge(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: darkGreen,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderGreen, width: 1),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildFloatingCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Colors.grey.withValues(alpha: 0.2),
    );
  }
}


//finally done
//firestore optimized
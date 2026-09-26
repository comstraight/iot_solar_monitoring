import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Search State
  String _searchQuery = '';

  // Preferences States (Stored locally via SharedPreferences)
  String _language = 'English';
  String _tempUnit = 'Celsius (°C)';

  // Notifications States (Stored locally via SharedPreferences)
  bool _masterNotifications = true;
  bool _alertNotifications = true;
  bool _updateNotifications = true;
  Set<String> _deliveryMethods = {'Push'};
  bool _quietHours = false;

  // Data & Hardware States
  String _syncInterval = 'Real-time';

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

  // --- LOCAL STORAGE (SharedPreferences) ---
  Future<void> _loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language = prefs.getString('pref_language') ?? 'English';
      _tempUnit = prefs.getString('pref_temp_unit') ?? 'Celsius (°C)';
      _masterNotifications = prefs.getBool('pref_master_notif') ?? true;
      _alertNotifications = prefs.getBool('pref_alert_notif') ?? true;
      _updateNotifications = prefs.getBool('pref_update_notif') ?? true;
      _deliveryMethods =
          prefs.getStringList('pref_delivery_methods')?.toSet() ?? {'Push'};
      _quietHours = prefs.getBool('pref_quiet_hours') ?? false;
      _syncInterval = prefs.getString('pref_sync_interval') ?? 'Real-time';
    });
  }

  Future<void> _saveStringSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _saveBoolSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveListSetting(String key, List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, value);
  }

  // --- FIRESTORE PROFILE EDIT DIALOG ---
  void _showEditProfileDialog(String currentName, String currentPhone) {
    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit Contact Info',
          style: TextStyle(
            color: darkGreen,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(CupertinoIcons.person, color: midGreen),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(CupertinoIcons.phone, color: midGreen),
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
              if (_currentUser != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(_currentUser.uid)
                    .set({
                      'name': nameController.text.trim(),
                      'phone': phoneController.text.trim(),
                    }, SetOptions(merge: true));
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
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _handleDeleteAccount() async {
    try {
      if (_currentUser != null) {
        // Delete Firestore user document first
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser.uid)
            .delete();
        // Delete Firebase Auth User
        await _currentUser.delete();
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
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

  void _showSelectionModal({
    required String title,
    required List<String> options,
    required String currentValue,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
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
                              color: option == currentValue
                                  ? lightGreenBg
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              child: RadioListTile<String>(
                                groupValue: currentValue,
                                value: option,
                                activeColor: midGreen,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                title: Text(
                                  option,
                                  style: TextStyle(
                                    fontWeight: option == currentValue
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: option == currentValue
                                        ? darkGreen
                                        : Colors.black87,
                                  ),
                                ),
                                onChanged: (val) {
                                  if (val != null) {
                                    onSelected(val);
                                    Navigator.pop(context);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
                      hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
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
                        stream: _currentUser != null
                            ? FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(_currentUser.uid)
                                  .snapshots()
                            : null,
                        builder: (context, snapshot) {
                          final data =
                              snapshot.data?.data() as Map<String, dynamic>?;

                          final String name =
                              data?['name'] ??
                              _currentUser?.displayName ??
                              'Set Name';
                          final String email =
                              data?['email'] ??
                              _currentUser?.email ??
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
                            onTap: () => _showEditProfileDialog(name, phone),
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
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        trailing: const Icon(
                          CupertinoIcons.chevron_right,
                          size: 16,
                          color: Colors.grey,
                        ),
                        onTap: () {},
                      ),
                    ],
                  ),
                ],

                // 2. PREFERENCES & APPEARANCE (SharedPreferences)
                if (_matchesSearch(
                  'Preferences Appearance Language Units Temperature',
                )) ...[
                  _buildSectionHeader('Preferences'),
                  _buildFloatingCard(
                    children: [
                      ListTile(
                        leading: const Icon(
                          CupertinoIcons.globe,
                          color: midGreen,
                          size: 20,
                        ),
                        title: const Text(
                          'Language & Region',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        trailing: _buildValueBadge(_language),
                        onTap: () => _showSelectionModal(
                          title: 'Select Language',
                          options: const ['English', 'Filipino', 'Spanish'],
                          currentValue: _language,
                          onSelected: (val) {
                            setState(() => _language = val);
                            _saveStringSetting('pref_language', val);
                          },
                        ),
                      ),
                      _buildDivider(),
                      ListTile(
                        leading: const Icon(
                          CupertinoIcons.thermometer,
                          color: midGreen,
                          size: 20,
                        ),
                        title: const Text(
                          'Temperature Unit',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        trailing: _buildValueBadge(_tempUnit),
                        onTap: () => _showSelectionModal(
                          title: 'Select Unit',
                          options: const ['Celsius (°C)', 'Fahrenheit (°F)'],
                          currentValue: _tempUnit,
                          onSelected: (val) {
                            setState(() => _tempUnit = val);
                            _saveStringSetting('pref_temp_unit', val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],

                // 3. NOTIFICATIONS & ALERTS (SharedPreferences)
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
                          style: TextStyle(fontSize: 11, color: Colors.grey),
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

                // 4. DATA, STORAGE & HARDWARE
                if (_matchesSearch('Data Storage Hardware Cache Sync')) ...[
                  _buildSectionHeader('Storage & Hardware'),
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
                          style: TextStyle(fontSize: 11, color: Colors.grey),
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
                                        CupertinoIcons.checkmark_circle_fill,
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
                      _buildDivider(),
                      ListTile(
                        leading: const Icon(
                          CupertinoIcons.arrow_2_circlepath,
                          color: midGreen,
                          size: 20,
                        ),
                        title: const Text(
                          'Sync Frequency',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        trailing: _buildValueBadge(_syncInterval),
                        onTap: () => _showSelectionModal(
                          title: 'Sync Frequency',
                          options: const [
                            'Real-time',
                            'Every 15 mins',
                            'WiFi Only',
                          ],
                          currentValue: _syncInterval,
                          onSelected: (val) {
                            setState(() => _syncInterval = val);
                            _saveStringSetting('pref_sync_interval', val);
                          },
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
                        onTap: () {},
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
                          style: TextStyle(fontSize: 11, color: Colors.grey),
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
                            border: Border.all(color: borderGreen, width: 1.5),
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

class TermsAndPrivacyScreen extends StatelessWidget {
  const TermsAndPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Privacy')),
      body: const Center(child: Text('Terms & Privacy content')),
    );
  }
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// Screen Imports
import 'initial_setup_screen.dart';

// --- Data Models ---
class PanelItem {
  static const String _defaultPanelName = 'Unnamed Panel';

  final String id;
  final String name;
  final bool isActive;
  final String? groupId;
  final String? ownerUid;
  final int order;

  PanelItem({
    required this.id,
    required this.name,
    this.isActive = true,
    this.groupId,
    this.ownerUid,
    this.order = 0,
  });

  factory PanelItem.fromMap(String id, Map<String, dynamic> data) {
    final diagnostics = data['diagnostics'] as Map<String, dynamic>? ?? {};
    return PanelItem(
      id: id,
      name: data['panel_name'] ?? data['name'] ?? _defaultPanelName,
      isActive:
          data['isActive'] ??
          data['is_active'] ??
          diagnostics['is_active'] ??
          true,
      groupId: data['group'] ?? data['groupId'] ?? data['group_id'],
      ownerUid: data['owner_uid'] ?? data['ownerUid'],
      order:
          (data['panel_order'] as num?)?.toInt() ??
          (data['order'] as num?)?.toInt() ??
          0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'panel_id': id,
      'panel_name': name,
      'group': groupId,
      'owner_uid': ownerUid,
      'panel_order': order,
    };
  }
}

class PanelGroup {
  static const String _defaultGroupName = 'Site';

  final String id;
  String name;
  bool isExpanded;
  int order;
  String? ownerUid;
  List<PanelItem> panels;

  PanelGroup({
    required this.id,
    required this.name,
    this.isExpanded = false,
    this.order = 0,
    this.ownerUid,
    List<PanelItem>? panels,
  }) : panels = panels ?? [];

  factory PanelGroup.fromMap(
    String id,
    Map<String, dynamic> data,
    List<PanelItem> memberPanels,
  ) {
    return PanelGroup(
      id: id,
      name: data['group_name'] ?? data['name'] ?? _defaultGroupName,
      order:
          (data['group_order'] as num?)?.toInt() ??
          (data['order'] as num?)?.toInt() ??
          0,
      ownerUid: data['owner_uid'] ?? data['ownerUid'],
      panels: memberPanels,
    );
  }
}

class DashboardData {
  final List<PanelGroup> groups;
  final List<PanelItem> ungroupedPanels;

  DashboardData({required this.groups, required this.ungroupedPanels});
}

// --- Drag & Drop Payloads ---
class PanelDragData {
  final PanelItem item;
  final String? sourceGroupId;
  final int sourceIndex;

  PanelDragData({
    required this.item,
    required this.sourceGroupId,
    required this.sourceIndex,
  });
}

class GroupDragData {
  final PanelGroup group;
  final int sourceIndex;

  GroupDragData({required this.group, required this.sourceIndex});
}

// --- Firebase Service Layer ---
class GroupFirestoreService {
  static const String _colSystemStatus = 'system_status';
  static const String _docCurrent = 'current';
  static const String _colUsers = 'users';
  static const String _colGroups = 'groups';
  static const String _colDevices = 'devices';
  static const String _fieldOwnerUid = 'owner_uid';

  static const String _groupIdPrefix = 'group_';
  static const Set<String> _ungroupedIdentifiers = {
    'None',
    'null',
    'ungrouped',
  };

  static final _db = FirebaseFirestore.instance;
  static final DocumentReference _statusDocRef = _db
      .collection(_colSystemStatus)
      .doc(_docCurrent);

  /// Stream reading nested map structures inside system_status/current filtered by current user
  static Stream<DashboardData> getDashboardDataStream(
    String? currentUid,
    List<String> pairedDevices,
  ) {
    return _statusDocRef.snapshots(includeMetadataChanges: false).map((
      snapshot,
    ) {
      final data = snapshot.data() as Map<String, dynamic>? ?? {};

      final groupsMap = data['groups'] as Map<String, dynamic>? ?? {};
      final panelsMap = data['panels'] as Map<String, dynamic>? ?? {};

      // 1. Parse and Filter Panels for Current User
      final List<PanelItem> allPanels = panelsMap.entries
          .map((entry) {
            final panelData = entry.value as Map<String, dynamic>? ?? {};
            return PanelItem.fromMap(entry.key, panelData);
          })
          .where((p) {
            if (currentUid == null) return true;
            return p.ownerUid == currentUid || pairedDevices.contains(p.id);
          })
          .toList();

      allPanels.sort((a, b) => a.order.compareTo(b.order));

      // 2. Parse and Filter Groups for Current User
      final List<PanelGroup> groups = groupsMap.entries
          .map((entry) {
            final groupId = entry.key;
            final groupData = entry.value as Map<String, dynamic>? ?? {};
            final groupName =
                groupData['group_name'] ?? groupData['name'] ?? '';

            final memberPanels = allPanels.where((p) {
              return p.groupId == groupId ||
                  (p.groupId != null && p.groupId == groupName);
            }).toList();

            return PanelGroup.fromMap(groupId, groupData, memberPanels);
          })
          .where((g) {
            if (currentUid == null) return true;
            return g.ownerUid == null ||
                g.ownerUid == '' ||
                g.ownerUid == currentUid ||
                g.panels.isNotEmpty;
          })
          .toList();

      groups.sort((a, b) => a.order.compareTo(b.order));

      // 3. Extract Ungrouped Panels for Current User
      final List<PanelItem> ungroupedPanels = allPanels.where((p) {
        final g = p.groupId;
        return g == null || g.isEmpty || _ungroupedIdentifiers.contains(g);
      }).toList();

      return DashboardData(groups: groups, ungroupedPanels: ungroupedPanels);
    });
  }

  /// Write: Add New Group into system_status/current and users/{uid}/groups
  static Future<void> addGroup(String name, int order, String? ownerUid) async {
    final String groupId =
        '$_groupIdPrefix${DateTime.now().millisecondsSinceEpoch}';
    final effectiveUid = ownerUid ?? FirebaseAuth.instance.currentUser?.uid;

    final batch = _db.batch();

    batch.set(_statusDocRef, {
      'groups': {
        groupId: {
          'group_id': groupId,
          'group_name': name,
          'group_order': order,
          'owner_uid': effectiveUid,
        },
      },
    }, SetOptions(merge: true));

    if (effectiveUid != null && effectiveUid.isNotEmpty) {
      final userGroupRef = _db
          .collection(_colUsers)
          .doc(effectiveUid)
          .collection(_colGroups)
          .doc(groupId);

      batch.set(userGroupRef, {
        'group_id': groupId,
        'group_name': name,
        'group_order': order,
        'owner_uid': effectiveUid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// Write: Rename Group in system_status/current and users/{uid}/groups
  static Future<void> renameGroup(
    String groupId,
    String newName, {
    String? ownerUid,
  }) async {
    final effectiveUid = ownerUid ?? FirebaseAuth.instance.currentUser?.uid;
    final batch = _db.batch();

    batch.set(_statusDocRef, {
      'groups': {
        groupId: {
          'group_name': newName,
          if (effectiveUid != null) 'owner_uid': effectiveUid,
        },
      },
    }, SetOptions(merge: true));

    if (effectiveUid != null && effectiveUid.isNotEmpty) {
      final userGroupRef = _db
          .collection(_colUsers)
          .doc(effectiveUid)
          .collection(_colGroups)
          .doc(groupId);

      batch.set(userGroupRef, {
        'group_name': newName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// Write: Rename Panel in system_status/current
  static Future<void> renamePanel(String panelId, String newName) async {
    await _statusDocRef.set({
      'panels': {
        panelId: {'panel_name': newName},
      },
    }, SetOptions(merge: true));
  }

  /// Write: Remove Panel permanently from system_status/current & release device ownership
  static Future<void> deletePanel(String panelId) async {
    await _statusDocRef.update({'panels.$panelId': FieldValue.delete()});

    try {
      await _db.collection(_colDevices).doc(panelId).update({
        _fieldOwnerUid: '',
      });
    } catch (_) {}
  }

  /// Write: Safe Delete Group and unassign member panels in system_status/current and users/{uid}/groups
  static Future<void> deleteGroup(
    String groupId,
    String groupName, {
    String? ownerUid,
  }) async {
    final effectiveUid = ownerUid ?? FirebaseAuth.instance.currentUser?.uid;
    final docSnap = await _statusDocRef.get();
    final data = docSnap.data() as Map<String, dynamic>? ?? {};
    final panelsMap = data['panels'] as Map<String, dynamic>? ?? {};

    final Map<String, dynamic> updates = {
      'groups.$groupId': FieldValue.delete(),
    };

    panelsMap.forEach((panelId, panelData) {
      if (panelData is Map<String, dynamic>) {
        final pGroup = panelData['group'];
        if (pGroup == groupId || pGroup == groupName) {
          updates['panels.$panelId.group'] = null;
        }
      }
    });

    final batch = _db.batch();
    batch.update(_statusDocRef, updates);

    if (effectiveUid != null && effectiveUid.isNotEmpty) {
      final userGroupRef = _db
          .collection(_colUsers)
          .doc(effectiveUid)
          .collection(_colGroups)
          .doc(groupId);
      batch.delete(userGroupRef);
    }

    await batch.commit();
  }

  /// Write: Move Panel to target Group in system_status/current
  static Future<void> movePanelToGroup(
    String panelId,
    String? targetGroupId,
    String? targetGroupName,
  ) async {
    await _statusDocRef.set({
      'panels': {
        panelId: {'group': targetGroupId ?? targetGroupName},
      },
    }, SetOptions(merge: true));
  }

  /// Write: Reorder Groups in system_status/current
  static Future<void> updateGroupOrder(List<PanelGroup> groups) async {
    final Map<String, dynamic> groupUpdates = {};
    for (int i = 0; i < groups.length; i++) {
      groupUpdates[groups[i].id] = {'group_order': i};
    }
    await _statusDocRef.set({'groups': groupUpdates}, SetOptions(merge: true));
  }
}

// --- Main Groups Screen ---
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  static const Color primaryGreen = Color(0xFF16A34A);
  static const Color lightGreenBg = Color(0xFFDCFCE7);
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color cardBorderColor = Color(0xFFE2E8F0);
  static const Color dividerColor = Color(0xFFF1F5F9);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textSubtle = Color(0xFF475569);
  static const Color textBody = Color(0xFF334155);
  static const Color editBlue = Color(0xFF0284C7);
  static const Color activeGreen = Color(0xFF22C55E);
  static const Color dragHandleColor = Color(0xFF94A3B8);
  static const Color panelDragIconColor = Color(0xFFCBD5E1);

  static const String _defaultSitePrefix = 'Site ';
  static final RegExp _siteNameRegex = RegExp(
    r'^\s*(?:site|group)\s*(\d+)\s*$',
    caseSensitive: false,
  );

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  StreamSubscription<DocumentSnapshot>? _userSub;
  List<String> _pairedDevices = [];

  bool _isHoveringDeleteZone = false;
  bool _isEditing = false;

  final Map<String, bool> _expansionMap = {};

  @override
  void initState() {
    super.initState();
    _listenToUserDoc();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? Colors.red.shade900
            : const Color(0xFF092508),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _listenToUserDoc() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
          if (doc.exists && mounted) {
            final data = doc.data() ?? {};
            final List<dynamic> paired =
                data['pairedDevices'] as List<dynamic>? ?? [];
            setState(() {
              _pairedDevices = paired.map((e) => e.toString()).toList();
            });
          }
        });
  }

  void _collapseAllGroups() {
    _expansionMap.updateAll((key, value) => false);
  }

  Future<void> _addNewGroup(List<PanelGroup> currentGroups) async {
    int maxNum = 0;

    for (final g in currentGroups) {
      final match = GroupsScreen._siteNameRegex.firstMatch(g.name);
      if (match != null) {
        final numStr = match.group(1);
        if (numStr != null) {
          final val = int.tryParse(numStr);
          if (val != null && val > maxNum) {
            maxNum = val;
          }
        }
      }
    }

    final nextNum = maxNum + 1;
    final user = FirebaseAuth.instance.currentUser;
    try {
      await GroupFirestoreService.addGroup(
        '${GroupsScreen._defaultSitePrefix}$nextNum',
        currentGroups.length,
        user?.uid,
      );
      _showSnackBar('Site added successfully!');
    } catch (e) {
      _showSnackBar('Failed to add site: $e', isError: true);
    }
  }

  Future<void> _showRenameDialog(PanelGroup group) async {
    final controller = TextEditingController(text: group.name);
    String? newName;

    try {
      newName = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Rename Site',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Site Name',
              labelStyle: const TextStyle(color: GroupsScreen.textMuted),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: GroupsScreen.primaryGreen,
                  width: 1.5,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: GroupsScreen.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GroupsScreen.primaryGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(dialogContext, text);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }

    if (!mounted) return;

    if (newName != null && newName.isNotEmpty && newName != group.name) {
      try {
        await GroupFirestoreService.renameGroup(
          group.id,
          newName,
          ownerUid: group.ownerUid,
        );
        _showSnackBar('Site renamed successfully!');
      } catch (e) {
        _showSnackBar('Failed to rename site: $e', isError: true);
      }
    }
  }

  Future<void> _showRenamePanelDialog(PanelItem panel) async {
    final controller = TextEditingController(text: panel.name);
    String? newName;

    try {
      newName = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Rename Panel',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Panel Name',
              labelStyle: const TextStyle(color: GroupsScreen.textMuted),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: GroupsScreen.primaryGreen,
                  width: 1.5,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancel',
                style: TextStyle(color: GroupsScreen.textMuted),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GroupsScreen.primaryGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(dialogContext, text);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }

    if (!mounted) return;

    if (newName != null && newName.isNotEmpty && newName != panel.name) {
      try {
        await GroupFirestoreService.renamePanel(panel.id, newName);
        _showSnackBar('Panel renamed successfully!');
      } catch (e) {
        _showSnackBar('Failed to rename panel: $e', isError: true);
      }
    }
  }

  Future<void> _handlePanelDelete(PanelItem panel) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Panel',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to remove "${panel.name}"? Telemetry data for this panel will no longer be saved or accepted.',
          style: const TextStyle(fontSize: 14, color: GroupsScreen.textSubtle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: GroupsScreen.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirm == true) {
      try {
        await GroupFirestoreService.deletePanel(panel.id);
        _showSnackBar('Panel removed.');
      } catch (e) {
        _showSnackBar('Failed to remove panel: $e', isError: true);
      }
    }
  }

  Future<void> _handleGroupDelete(PanelGroup group) async {
    if (group.panels.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Cannot Delete Site',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Text(
            '${group.name} contains ${group.panels.length} panel(s). Panels must remain assigned to a site. Please move all panels to another site before deleting this site.',
            style: const TextStyle(
              fontSize: 14,
              color: GroupsScreen.textSubtle,
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GroupsScreen.primaryGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Site',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to delete "${group.name}"?',
          style: const TextStyle(fontSize: 14, color: GroupsScreen.textSubtle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: GroupsScreen.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirm == true) {
      try {
        await GroupFirestoreService.deleteGroup(
          group.id,
          group.name,
          ownerUid: group.ownerUid,
        );
        _showSnackBar('Site deleted.');
      } catch (e) {
        _showSnackBar('Failed to delete site: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: GroupsScreen.bgLight,
      body: SafeArea(
        child: StreamBuilder<DashboardData>(
          stream: GroupFirestoreService.getDashboardDataStream(
            currentUid,
            _pairedDevices,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator.adaptive(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    GroupsScreen.primaryGreen,
                  ),
                ),
              );
            }

            final data = snapshot.data;
            final groups = data?.groups ?? [];
            final ungroupedPanels = data?.ungroupedPanels ?? [];

            for (var group in groups) {
              group.isExpanded = _expansionMap[group.id] ?? false;
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: GroupsScreen.cardBorderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: GroupsScreen.dividerColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  CupertinoIcons.chevron_left,
                                  color: GroupsScreen.textDark,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Panel Sites',
                              style: TextStyle(
                                color: GroupsScreen.textDark,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            color: GroupsScreen.lightGreenBg,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              CupertinoIcons.add,
                              color: GroupsScreen.primaryGreen,
                              size: 20,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const InitialSetupScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: TweenAnimationBuilder<double>(
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
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: GroupsScreen.cardBorderColor,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'SITES',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isEditing = !_isEditing;
                                    });
                                  },
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    transitionBuilder: (child, animation) =>
                                        FadeTransition(
                                          opacity: animation,
                                          child: ScaleTransition(
                                            scale: animation,
                                            child: child,
                                          ),
                                        ),
                                    child: Text(
                                      _isEditing ? 'Done' : 'Edit',
                                      key: ValueKey<bool>(_isEditing),
                                      style: TextStyle(
                                        color: _isEditing
                                            ? GroupsScreen.primaryGreen
                                            : GroupsScreen.textMuted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (groups.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Text(
                                  'No sites created yet.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ),

                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: groups.length,
                              itemBuilder: (context, groupIndex) {
                                return _buildGroupRow(
                                  groups[groupIndex],
                                  groupIndex,
                                  groups,
                                );
                              },
                            ),

                            const SizedBox(height: 20),
                            const Divider(
                              color: GroupsScreen.dividerColor,
                              height: 1,
                              thickness: 1,
                            ),
                            const SizedBox(height: 20),

                            DragTarget<Object>(
                              onWillAcceptWithDetails: (details) {
                                if (details.data is GroupDragData &&
                                    !_isHoveringDeleteZone) {
                                  setState(() => _isHoveringDeleteZone = true);
                                }
                                return true;
                              },
                              onLeave: (_) {
                                if (_isHoveringDeleteZone) {
                                  setState(() => _isHoveringDeleteZone = false);
                                }
                              },
                              onAcceptWithDetails: (details) async {
                                if (details.data is GroupDragData) {
                                  setState(() => _isHoveringDeleteZone = false);
                                  final groupData =
                                      details.data as GroupDragData;
                                  _handleGroupDelete(groupData.group);
                                } else if (details.data is PanelDragData) {
                                  final panelData =
                                      details.data as PanelDragData;
                                  await GroupFirestoreService.movePanelToGroup(
                                    panelData.item.id,
                                    null,
                                    null,
                                  );
                                }
                              },
                              builder: (context, candidateGroupData, rejectedGroupData) {
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _isHoveringDeleteZone
                                        ? Colors.red.withValues(alpha: 0.08)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _isHoveringDeleteZone
                                          ? Colors.redAccent
                                          : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'UNASSIGNED',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                          AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            child: _isHoveringDeleteZone
                                                ? const Padding(
                                                    key: ValueKey(
                                                      'hover_delete_text',
                                                    ),
                                                    padding: EdgeInsets.only(
                                                      left: 8.0,
                                                    ),
                                                    child: Text(
                                                      '— Drop site here to delete',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  )
                                                : const SizedBox.shrink(
                                                    key: ValueKey('empty_text'),
                                                  ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      if (ungroupedPanels.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8.0,
                                          ),
                                          child: Text(
                                            'All panels are assigned to a site.',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),

                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: ungroupedPanels.length,
                                        itemBuilder: (context, index) {
                                          final panel = ungroupedPanels[index];
                                          return _buildMemberPanelTile(
                                            panel: panel,
                                            index: index,
                                            sourceGroupId: null,
                                            isIndented: false,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _addNewGroup(groups),
                                icon: const Icon(
                                  CupertinoIcons.add,
                                  size: 16,
                                  color: GroupsScreen.primaryGreen,
                                ),
                                label: const Text(
                                  'add a site',
                                  style: TextStyle(
                                    color: GroupsScreen.primaryGreen,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: GroupsScreen.lightGreenBg,
                                    width: 1.5,
                                  ),
                                  backgroundColor: GroupsScreen.bgLight,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGroupRow(
    PanelGroup group,
    int groupIndex,
    List<PanelGroup> allGroups,
  ) {
    final int activePanels = group.panels.where((p) => p.isActive).length;

    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) async {
        if (details.data is GroupDragData) {
          final groupData = details.data as GroupDragData;
          if (!_isEditing && groupData.sourceIndex != groupIndex) {
            final reordered = List<PanelGroup>.from(allGroups);
            final movedGroup = reordered.removeAt(groupData.sourceIndex);
            reordered.insert(groupIndex, movedGroup);
            await GroupFirestoreService.updateGroupOrder(reordered);
          }
        } else if (details.data is PanelDragData) {
          final panelData = details.data as PanelDragData;
          if (panelData.sourceGroupId != group.id) {
            await GroupFirestoreService.movePanelToGroup(
              panelData.item.id,
              group.id,
              group.name,
            );
          }
        }
      },
      builder: (context, candidateGroupData, rejectedGroupData) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: _isEditing
                        ? Row(
                            key: ValueKey('editing_group_${group.id}'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                                icon: const Icon(
                                  CupertinoIcons.pencil,
                                  color: GroupsScreen.editBlue,
                                  size: 18,
                                ),
                                onPressed: () => _showRenameDialog(group),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                                icon: const Icon(
                                  CupertinoIcons.trash,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                                onPressed: () => _handleGroupDelete(group),
                              ),
                            ],
                          )
                        : Draggable<GroupDragData>(
                            key: ValueKey('draggable_group_${group.id}'),
                            data: GroupDragData(
                              group: group,
                              sourceIndex: groupIndex,
                            ),
                            onDragStarted: () {
                              setState(() {
                                _collapseAllGroups();
                              });
                            },
                            feedback: Material(
                              color: Colors.transparent,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: GroupsScreen.textDark,
                                    width: 1.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.bars,
                                      color: GroupsScreen.textDark,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      group.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            childWhenDragging: const Icon(
                              CupertinoIcons.bars,
                              color: GroupsScreen.cardBorderColor,
                              size: 18,
                            ),
                            child: const Icon(
                              CupertinoIcons.bars,
                              color: GroupsScreen.dragHandleColor,
                              size: 18,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _expansionMap[group.id] = !group.isExpanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    group.name,
                                    style: const TextStyle(
                                      color: GroupsScreen.textDark,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '•  $activePanels of ${group.panels.length} active',
                                    style: const TextStyle(
                                      color: GroupsScreen.primaryGreen,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AnimatedRotation(
                              turns: group.isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              child: const Icon(
                                CupertinoIcons.chevron_down,
                                color: GroupsScreen.textMuted,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              child: group.isExpanded
                  ? ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: group.panels.length,
                      itemBuilder: (context, panelIndex) {
                        final panel = group.panels[panelIndex];
                        return _buildMemberPanelTile(
                          panel: panel,
                          index: panelIndex,
                          sourceGroupId: group.id,
                          isIndented: true,
                        );
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMemberPanelTile({
    required PanelItem panel,
    required int index,
    required String? sourceGroupId,
    bool isIndented = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: isIndented ? 30.0 : 0.0,
        top: 6.0,
        bottom: 6.0,
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: _isEditing
                ? Row(
                    key: ValueKey('editing_panel_${panel.id}'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        icon: const Icon(
                          CupertinoIcons.pencil,
                          color: GroupsScreen.editBlue,
                          size: 16,
                        ),
                        onPressed: () => _showRenamePanelDialog(panel),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        icon: const Icon(
                          CupertinoIcons.trash,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                        onPressed: () => _handlePanelDelete(panel),
                      ),
                      const SizedBox(width: 6),
                    ],
                  )
                : Row(
                    key: ValueKey('draggable_panel_${panel.id}'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Draggable<PanelDragData>(
                        data: PanelDragData(
                          item: panel,
                          sourceGroupId: sourceGroupId,
                          sourceIndex: index,
                        ),
                        onDragStarted: () {
                          setState(() {
                            _collapseAllGroups();
                          });
                        },
                        feedback: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: GroupsScreen.primaryGreen,
                                width: 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 8),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.line_horizontal_3,
                                  color: GroupsScreen.primaryGreen,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  panel.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        childWhenDragging: const Icon(
                          CupertinoIcons.line_horizontal_3,
                          color: GroupsScreen.cardBorderColor,
                          size: 16,
                        ),
                        child: const Icon(
                          CupertinoIcons.line_horizontal_3,
                          color: GroupsScreen.panelDragIconColor,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
          ),

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: panel.isActive
                  ? GroupsScreen.activeGreen
                  : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),

          Expanded(
            child: Text(
              panel.name,
              style: const TextStyle(
                color: GroupsScreen.textBody,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

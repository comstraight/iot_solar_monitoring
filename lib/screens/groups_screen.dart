import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'initial_setup_screen.dart';

// --- Data Models ---
class PanelItem {
  final String id;
  final String name;
  final bool isActive;
  final String? groupId;
  final int order;

  PanelItem({
    required this.id,
    required this.name,
    this.isActive = true,
    this.groupId,
    this.order = 0,
  });

  factory PanelItem.fromMap(String id, Map<String, dynamic> data) {
    final diagnostics = data['diagnostics'] as Map<String, dynamic>? ?? {};
    return PanelItem(
      id: id,
      name: data['panel_name'] ?? data['name'] ?? 'Unnamed Panel',
      isActive:
          data['isActive'] ??
          data['is_active'] ??
          diagnostics['is_active'] ??
          true,
      groupId: data['group'] ?? data['groupId'] ?? data['group_id'],
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
      'panel_order': order,
    };
  }
}

class PanelGroup {
  final String id;
  String name;
  bool isExpanded;
  int order;
  List<PanelItem> panels;

  PanelGroup({
    required this.id,
    required this.name,
    this.isExpanded = false,
    this.order = 0,
    List<PanelItem>? panels,
  }) : panels = panels ?? [];

  factory PanelGroup.fromMap(
    String id,
    Map<String, dynamic> data,
    List<PanelItem> memberPanels,
  ) {
    return PanelGroup(
      id: id,
      name: data['group_name'] ?? data['name'] ?? 'Group',
      order:
          (data['group_order'] as num?)?.toInt() ??
          (data['order'] as num?)?.toInt() ??
          0,
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
  static final _db = FirebaseFirestore.instance;
  static final DocumentReference _statusDocRef = _db
      .collection('system_status')
      .doc('current');

  /// Single Stream reading nested map structures inside system_status/current
  static Stream<DashboardData> getDashboardDataStream() {
    return _statusDocRef.snapshots().map((snapshot) {
      final data = snapshot.data() as Map<String, dynamic>? ?? {};

      final groupsMap = data['groups'] as Map<String, dynamic>? ?? {};
      final panelsMap = data['panels'] as Map<String, dynamic>? ?? {};

      // 1. Parse all Panels
      final List<PanelItem> allPanels = panelsMap.entries.map((entry) {
        final panelData = entry.value as Map<String, dynamic>? ?? {};
        return PanelItem.fromMap(entry.key, panelData);
      }).toList();

      allPanels.sort((a, b) => a.order.compareTo(b.order));

      // 2. Parse all Groups
      final List<PanelGroup> groups = groupsMap.entries.map((entry) {
        final groupId = entry.key;
        final groupData = entry.value as Map<String, dynamic>? ?? {};
        final groupName = groupData['group_name'] ?? groupData['name'] ?? '';

        final memberPanels = allPanels.where((p) {
          return p.groupId == groupId ||
              (p.groupId != null && p.groupId == groupName);
        }).toList();

        return PanelGroup.fromMap(groupId, groupData, memberPanels);
      }).toList();

      groups.sort((a, b) => a.order.compareTo(b.order));

      // 3. Extract Ungrouped Panels
      final List<PanelItem> ungroupedPanels = allPanels.where((p) {
        final g = p.groupId;
        return g == null ||
            g.isEmpty ||
            g == 'None' ||
            g == 'null' ||
            g == 'ungrouped';
      }).toList();

      return DashboardData(groups: groups, ungroupedPanels: ungroupedPanels);
    });
  }

  /// Write: Add New Group into system_status/current
  static Future<void> addGroup(String name, int order) async {
    final String groupId = 'group_${DateTime.now().millisecondsSinceEpoch}';

    await _statusDocRef.set({
      'groups': {
        groupId: {
          'group_id': groupId,
          'group_name': name,
          'group_order': order,
        },
      },
    }, SetOptions(merge: true));
  }

  /// Write: Rename Group in system_status/current
  static Future<void> renameGroup(String groupId, String newName) async {
    await _statusDocRef.update({'groups.$groupId.group_name': newName});
  }

  /// Write: Safe Delete Group and unassign member panels in system_status/current
  static Future<void> deleteGroup(String groupId, String groupName) async {
    final docSnap = await _statusDocRef.get();
    final data = docSnap.data() as Map<String, dynamic>? ?? {};
    final panelsMap = data['panels'] as Map<String, dynamic>? ?? {};

    final Map<String, dynamic> updates = {
      'groups.$groupId': FieldValue.delete(),
    };

    // Unassign panel group references matching either the groupId or groupName
    panelsMap.forEach((panelId, panelData) {
      if (panelData is Map<String, dynamic>) {
        final pGroup = panelData['group'];
        if (pGroup == groupId || pGroup == groupName) {
          updates['panels.$panelId.group'] = null;
        }
      }
    });

    await _statusDocRef.update(updates);
  }

  /// Write: Move Panel to target Group in system_status/current
  static Future<void> movePanelToGroup(
    String panelId,
    String? targetGroupId,
    String? targetGroupName,
  ) async {
    await _statusDocRef.update({'panels.$panelId.group': targetGroupId});
  }

  /// Write: Reorder Groups in system_status/current
  static Future<void> updateGroupOrder(List<PanelGroup> groups) async {
    final Map<String, dynamic> updates = {};
    for (int i = 0; i < groups.length; i++) {
      updates['groups.${groups[i].id}.group_order'] = i;
    }
    await _statusDocRef.update(updates);
  }
}

// --- Main Groups Screen ---
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late final Stream<DashboardData> _dashboardStream;

  @override
  void initState() {
    super.initState();
    _dashboardStream = GroupFirestoreService.getDashboardDataStream();
  }

  String? _currentlyHoveredGroupId;
  bool _isHoveringDeleteZone = false;
  bool _isEditing = false;

  final Map<String, bool> _expansionMap = {};

  void _collapseAllGroups() {
    _expansionMap.updateAll((key, value) => false);
  }

  Future<void> _addNewGroup(List<PanelGroup> currentGroups) async {
    final regExp = RegExp(r'^\s*group\s*(\d+)\s*$', caseSensitive: false);
    int maxNum = 0;

    for (final g in currentGroups) {
      final match = regExp.firstMatch(g.name);
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
    await GroupFirestoreService.addGroup(
      'Group $nextNum',
      currentGroups.length,
    );
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
            'Rename Group',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Group Name',
              labelStyle: const TextStyle(color: Color(0xFF64748B)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF16A34A),
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
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
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

    if (newName != null && newName.isNotEmpty) {
      await GroupFirestoreService.renameGroup(group.id, newName);
    }
  }

  Future<void> _handleGroupDelete(PanelGroup group) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Group',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to delete "${group.name}"? All member panels will be moved to UNGROUPED.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF64748B)),
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

    if (confirm == true) {
      await GroupFirestoreService.deleteGroup(group.id, group.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: StreamBuilder<DashboardData>(
          stream: _dashboardStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF16A34A)),
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
                // 1. STICKY HEADER BOX
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
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
                        const Text(
                          'Panel Groups',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFFDCFCE7),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              CupertinoIcons.add,
                              color: Color(0xFF16A34A),
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

                // 2. SCROLLABLE PANELS CONTAINER
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                          // GROUPED SECTION HEADER
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'GROUPED',
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
                                child: Text(
                                  _isEditing ? 'Done' : 'Edit',
                                  style: TextStyle(
                                    color: _isEditing
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF64748B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // List of Groups
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
                            color: Color(0xFFF1F5F9),
                            height: 1,
                            thickness: 1,
                          ),
                          const SizedBox(height: 20),

                          // UNGROUPED SECTION HEADER & DROP ZONE
                          DragTarget<GroupDragData>(
                            onWillAcceptWithDetails: (details) {
                              if (!_isHoveringDeleteZone) {
                                setState(() => _isHoveringDeleteZone = true);
                              }
                              return true;
                            },
                            onLeave: (_) {
                              if (_isHoveringDeleteZone) {
                                setState(() => _isHoveringDeleteZone = false);
                              }
                            },
                            onAcceptWithDetails: (details) {
                              setState(() => _isHoveringDeleteZone = false);
                              _handleGroupDelete(details.data.group);
                            },
                            builder: (context, candidateGroupData, rejectedGroupData) {
                              return DragTarget<PanelDragData>(
                                onWillAcceptWithDetails: (details) {
                                  if (_currentlyHoveredGroupId != null) {
                                    setState(() {
                                      _collapseAllGroups();
                                      _currentlyHoveredGroupId = null;
                                    });
                                  }
                                  return true;
                                },
                                onAcceptWithDetails: (details) async {
                                  setState(() {
                                    _collapseAllGroups();
                                  });
                                  await GroupFirestoreService.movePanelToGroup(
                                    details.data.item.id,
                                    null,
                                    null,
                                  );
                                },
                                builder:
                                    (
                                      context,
                                      candidatePanelData,
                                      rejectedPanelData,
                                    ) {
                                      return AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _isHoveringDeleteZone
                                              ? Colors.red.withValues(
                                                  alpha: 0.08,
                                                )
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: _isHoveringDeleteZone
                                              ? Border.all(
                                                  color: Colors.redAccent,
                                                  width: 1.5,
                                                )
                                              : null,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Text(
                                                  'UNGROUPED',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 1.5,
                                                  ),
                                                ),
                                                if (_isHoveringDeleteZone)
                                                  const Padding(
                                                    padding: EdgeInsets.only(
                                                      left: 8.0,
                                                    ),
                                                    child: Text(
                                                      '— Drop group here to delete',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),

                                            // List of Ungrouped Panels
                                            ListView.builder(
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              itemCount: ungroupedPanels.length,
                                              itemBuilder: (context, index) {
                                                final panel =
                                                    ungroupedPanels[index];
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
                                color: Color(0xFF16A34A),
                              ),
                              label: const Text(
                                'add a group',
                                style: TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFFDCFCE7),
                                  width: 1.5,
                                ),
                                backgroundColor: const Color(0xFFF8FAFC),
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
              ],
            );
          },
        ),
      ),
    );
  }

  // --- Group Row Widget ---
  Widget _buildGroupRow(
    PanelGroup group,
    int groupIndex,
    List<PanelGroup> allGroups,
  ) {
    final int activePanels = group.panels.where((p) => p.isActive).length;

    return DragTarget<PanelDragData>(
      onWillAcceptWithDetails: (details) {
        if (_currentlyHoveredGroupId != group.id) {
          _currentlyHoveredGroupId = group.id;
          if (!(_expansionMap[group.id] ?? false)) {
            setState(() {
              _collapseAllGroups();
              _expansionMap[group.id] = true;
            });
          }
        }
        return true;
      },
      onAcceptWithDetails: (details) async {
        _currentlyHoveredGroupId = null;
        await GroupFirestoreService.movePanelToGroup(
          details.data.item.id,
          group.id,
          group.name,
        );
      },
      builder: (context, candidateData, rejectedData) {
        return DragTarget<GroupDragData>(
          onWillAcceptWithDetails: (details) => true,
          onAcceptWithDetails: (details) async {
            if (!_isEditing && details.data.sourceIndex != groupIndex) {
              final reordered = List<PanelGroup>.from(allGroups);
              final movedGroup = reordered.removeAt(details.data.sourceIndex);
              reordered.insert(groupIndex, movedGroup);
              await GroupFirestoreService.updateGroupOrder(reordered);
            }
          },
          builder: (context, candidateGroupData, rejectedGroupData) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _expansionMap[group.id] = !group.isExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Row(
                      children: [
                        if (_isEditing) ...[
                          InkWell(
                            onTap: () => _showRenameDialog(group),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(
                                CupertinoIcons.pencil,
                                color: Color(0xFF0284C7),
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _handleGroupDelete(group),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(
                                CupertinoIcons.trash,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                            ),
                          ),
                        ] else ...[
                          Draggable<GroupDragData>(
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
                                    color: const Color(0xFF0F172A),
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
                                      color: Color(0xFF0F172A),
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
                              color: Color(0xFFE2E8F0),
                              size: 18,
                            ),
                            child: const Icon(
                              CupertinoIcons.bars,
                              color: Color(0xFF94A3B8),
                              size: 18,
                            ),
                          ),
                        ],
                        const SizedBox(width: 12),

                        // Title & Status Counter
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                group.name,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '•  $activePanels of ${group.panels.length} active',
                                style: const TextStyle(
                                  color: Color(0xFF16A34A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Expand Chevron
                        AnimatedRotation(
                          turns: group.isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(
                            CupertinoIcons.chevron_down,
                            color: Color(0xFF64748B),
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Expanded Member Panels
                if (group.isExpanded)
                  ListView.builder(
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
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Member Panel Row Widget ---
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
          // Member Panel Drag Handle
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
                    color: const Color(0xFF16A34A),
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
                      color: Color(0xFF16A34A),
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
              color: Color(0xFFE2E8F0),
              size: 16,
            ),
            child: const Icon(
              CupertinoIcons.line_horizontal_3,
              color: Color(0xFFCBD5E1),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),

          // Active Indicator Dot
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: panel.isActive
                  ? const Color(0xFF22C55E)
                  : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),

          // Panel Name
          Expanded(
            child: Text(
              panel.name,
              style: const TextStyle(
                color: Color(0xFF334155),
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


//partially done
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../screens/initial_setup_screen.dart';

// --- Data Models ---
class PanelItem {
  final String id;
  final String name;
  final bool isActive;

  PanelItem({required this.id, required this.name, this.isActive = true});
}

class PanelGroup {
  final String id;
  String name;
  bool isExpanded;
  List<PanelItem> panels;

  PanelGroup({
    required this.id,
    required this.name,
    this.isExpanded = false,
    required this.panels,
  });
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

// --- Main Groups Screen ---
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final List<PanelGroup> _groups = [
    PanelGroup(
      id: 'g1',
      name: 'Home 1',
      isExpanded: false,
      panels: [
        PanelItem(id: 'p1', name: 'Roof North Array'),
        PanelItem(id: 'p2', name: 'Roof South Array'),
        PanelItem(id: 'p3', name: 'Garage East'),
      ],
    ),
    PanelGroup(
      id: 'g2',
      name: 'Home 2',
      isExpanded: false,
      panels: [
        PanelItem(id: 'p4', name: 'Main Roof'),
        PanelItem(id: 'p5', name: 'Patio Awning'),
      ],
    ),
    PanelGroup(
      id: 'g3',
      name: 'Work',
      isExpanded: false,
      panels: [
        PanelItem(id: 'p6', name: 'HQ Building West'),
        PanelItem(id: 'p7', name: 'Parking Canopy A'),
        PanelItem(id: 'p8', name: 'Parking Canopy B'),
      ],
    ),
  ];

  final List<PanelItem> _ungroupedPanels = [
    PanelItem(id: 'u1', name: 'Backyard Shed'),
    PanelItem(id: 'u2', name: 'Garden Solar Light Bank'),
  ];

  String? _currentlyHoveredGroupId;
  bool _isHoveringDeleteZone = false;
  bool _isEditing = false; // Controls Edit Mode state

  // --- Auto Name Group Logic ---
  void _addNewGroup() {
    final regExp = RegExp(r'^\s*group\s*(\d+)\s*$', caseSensitive: false);
    int maxNum = 0;

    for (final g in _groups) {
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

    setState(() {
      _groups.add(
        PanelGroup(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Group $nextNum',
          isExpanded: false,
          panels: [],
        ),
      );
    });
  }

  void _collapseAllGroups() {
    for (var g in _groups) {
      g.isExpanded = false;
    }
  }

  // --- Rename Group Dialog ---
  Future<void> _showRenameDialog(PanelGroup group) async {
    final controller = TextEditingController(text: group.name);
    final String? newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() {
        group.name = newName;
      });
    }
  }

  // --- Confirm Group Delete Dialog ---
  Future<void> _handleGroupDelete(PanelGroup group) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context, false),
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _groups.removeWhere((g) => g.id == group.id);
        _ungroupedPanels.addAll(group.panels);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // 1. STICKY HEADER BOX (Remains fixed at top)
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
                              builder: (context) => const InitialSetupScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. SCROLLABLE PANELS CONTAINER (Only this section scrolls)
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
                      // GROUPED SECTION HEADER ROW (With Edit Button)
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
                        itemCount: _groups.length,
                        itemBuilder: (context, groupIndex) {
                          return _buildGroupRow(
                            _groups[groupIndex],
                            groupIndex,
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
                          setState(() => _isHoveringDeleteZone = true);
                          return true;
                        },
                        onLeave: (_) =>
                            setState(() => _isHoveringDeleteZone = false),
                        onAcceptWithDetails: (details) {
                          setState(() => _isHoveringDeleteZone = false);
                          _handleGroupDelete(details.data.group);
                        },
                        builder: (context, candidateGroupData, rejectedGroupData) {
                          return DragTarget<PanelDragData>(
                            onWillAcceptWithDetails: (details) {
                              setState(() {
                                _collapseAllGroups();
                                _currentlyHoveredGroupId = null;
                              });
                              return true;
                            },
                            onAcceptWithDetails: (details) {
                              final data = details.data;
                              setState(() {
                                if (data.sourceGroupId != null) {
                                  final sourceGroup = _groups.firstWhere(
                                    (g) => g.id == data.sourceGroupId,
                                  );
                                  sourceGroup.panels.removeWhere(
                                    (p) => p.id == data.item.id,
                                  );
                                  _ungroupedPanels.add(data.item);
                                }
                                _collapseAllGroups();
                              });
                            },
                            builder:
                                (
                                  context,
                                  candidatePanelData,
                                  rejectedPanelData,
                                ) {
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _isHoveringDeleteZone
                                          ? Colors.red.withValues(alpha: 0.08)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
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
                                                    fontWeight: FontWeight.bold,
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
                                          itemCount: _ungroupedPanels.length,
                                          itemBuilder: (context, index) {
                                            final panel =
                                                _ungroupedPanels[index];
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

                      // ADD A GROUP BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _addNewGroup,
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
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
    );
  }

  // --- Group Row Widget ---
  Widget _buildGroupRow(PanelGroup group, int groupIndex) {
    final int activePanels = group.panels.where((p) => p.isActive).length;

    return DragTarget<PanelDragData>(
      onWillAcceptWithDetails: (details) {
        if (_currentlyHoveredGroupId != group.id) {
          setState(() {
            _collapseAllGroups();
            group.isExpanded = true;
            _currentlyHoveredGroupId = group.id;
          });
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        setState(() {
          if (data.sourceGroupId != null) {
            final oldGroup = _groups.firstWhere(
              (g) => g.id == data.sourceGroupId,
            );
            oldGroup.panels.removeWhere((p) => p.id == data.item.id);
          } else {
            _ungroupedPanels.removeWhere((p) => p.id == data.item.id);
          }

          if (!group.panels.any((p) => p.id == data.item.id)) {
            group.panels.add(data.item);
          }
          _currentlyHoveredGroupId = null;
        });
      },
      builder: (context, candidateData, rejectedData) {
        return DragTarget<GroupDragData>(
          onWillAcceptWithDetails: (details) {
            if (!_isEditing && details.data.sourceIndex != groupIndex) {
              setState(() {
                final movedGroup = _groups.removeAt(details.data.sourceIndex);
                _groups.insert(groupIndex, movedGroup);
              });
            }
            return true;
          },
          builder: (context, candidateGroupData, rejectedGroupData) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      group.isExpanded = !group.isExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Row(
                      children: [
                        // SWITCH BETWEEN EDIT BUTTONS & DRAG HANDLE
                        if (_isEditing) ...[
                          // Rename Button
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
                          // Delete Button
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
                          // Instant Drag Handle for Group
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
    return DragTarget<PanelDragData>(
      onWillAcceptWithDetails: (details) {
        if (details.data.sourceGroupId == sourceGroupId &&
            details.data.sourceIndex != index) {
          setState(() {
            final list = sourceGroupId != null
                ? _groups.firstWhere((g) => g.id == sourceGroupId).panels
                : _ungroupedPanels;
            final movedItem = list.removeAt(details.data.sourceIndex);
            list.insert(index, movedItem);
          });
        }
        return true;
      },
      builder: (context, candidateData, rejectedData) {
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
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
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
      },
    );
  }
}

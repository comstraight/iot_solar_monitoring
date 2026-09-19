import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// --- Models ---
class PanelItem {
  final String id;
  final String name;
  final String output;
  final bool isActive;

  PanelItem({
    required this.id,
    required this.name,
    required this.output,
    this.isActive = true,
  });
}

class PanelGroup {
  final String id;
  final String name;
  bool isExpanded;
  List<PanelItem> panels;

  PanelGroup({
    required this.id,
    required this.name,
    this.isExpanded = false,
    required this.panels,
  });
}

// --- Minimalist List Groups Screen ---
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
      isExpanded: true,
      panels: [
        PanelItem(id: 'p1', name: 'Roof North Array', output: '4.2 kW/h'),
        PanelItem(id: 'p2', name: 'Roof South Array', output: '5.8 kW/h'),
        PanelItem(id: 'p3', name: 'Garage East', output: '2.1 kW/h'),
      ],
    ),
    PanelGroup(
      id: 'g2',
      name: 'Home 2',
      isExpanded: false,
      panels: [
        PanelItem(id: 'p4', name: 'Main Roof', output: '6.0 kW/h'),
        PanelItem(id: 'p5', name: 'Patio Awning', output: '1.5 kW/h'),
      ],
    ),
    PanelGroup(
      id: 'g3',
      name: 'Work',
      isExpanded: false,
      panels: [
        PanelItem(id: 'p6', name: 'HQ Building West', output: '12.4 kW/h'),
        PanelItem(id: 'p7', name: 'Parking Canopy A', output: '8.9 kW/h'),
        PanelItem(id: 'p8', name: 'Parking Canopy B', output: '9.1 kW/h'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Panel Groups',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.add, color: Color(0xFF16A34A)),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          buildDefaultDragHandles: false,
          itemCount: _groups.length,
          // Collapse group when dragging begins
          onReorderStart: (index) {
            setState(() {
              _groups[index].isExpanded = false;
            });
          },
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex -= 1;
              final group = _groups.removeAt(oldIndex);
              _groups.insert(newIndex, group);
            });
          },
          itemBuilder: (context, groupIndex) {
            final group = _groups[groupIndex];
            return _buildGroupTile(group, groupIndex);
          },
        ),
      ),
    );
  }

  // --- Group Row Widget ---
  Widget _buildGroupTile(PanelGroup group, int groupIndex) {
    final int activePanels = group.panels.where((p) => p.isActive).length;

    return Column(
      key: ValueKey(group.id),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group Header Row
        InkWell(
          onTap: () {
            setState(() {
              group.isExpanded = !group.isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                // Plain Drag Handle for Group
                ReorderableDragStartListener(
                  index: groupIndex,
                  child: const Icon(
                    CupertinoIcons.bars,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Group Title & Single-Line Subtitle
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•  $activePanels of ${group.panels.length} active',
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Expand/Collapse Chevron
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

        // Nested Member Panels (Indented List Style)
        if (group.isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 32, bottom: 8),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: group.panels.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final panel = group.panels.removeAt(oldIndex);
                  group.panels.insert(newIndex, panel);
                });
              },
              itemBuilder: (context, panelIndex) {
                final panel = group.panels[panelIndex];
                return _buildMemberPanelTile(panel, panelIndex);
              },
            ),
          ),
      ],
    );
  }

  // --- Member Panel Row Widget ---
  Widget _buildMemberPanelTile(PanelItem panel, int panelIndex) {
    return Padding(
      key: ValueKey(panel.id),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // Plain Drag Handle for Member
          ReorderableDragStartListener(
            index: panelIndex,
            child: const Icon(
              CupertinoIcons.line_horizontal_3,
              color: Color(0xFFCBD5E1),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),

          // Status Dot
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),

          // Member Panel Name
          Expanded(
            child: Text(
              panel.name,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Clean Output Text
          Text(
            panel.output,
            style: const TextStyle(
              color: Color(0xFF16A34A),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
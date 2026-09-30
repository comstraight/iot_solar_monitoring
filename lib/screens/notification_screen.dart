import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'monitoring_screen.dart';

enum NotificationType {
  info, // Green: Updates, Patches, TOS, General Reminders
  warning, // Yellow: Degradation, dust, shading, high temp
  critical, // Red: Fires, Sensor failure, wiring failure
}

class NotificationItem {
  final String id;
  final String senderName;
  final String senderEmail;
  final String title;
  final String message;
  final String timestamp;
  final NotificationType type;
  final String category;
  final String? panelId;
  final String targetUid;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.senderName,
    required this.senderEmail,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.category = 'General',
    this.panelId,
    this.targetUid = 'all',
    this.isRead = false,
  });

  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    NotificationType parsedType = NotificationType.info;
    final typeStr = data['type']?.toString().toLowerCase() ?? 'info';
    if (typeStr == 'critical') {
      parsedType = NotificationType.critical;
    } else if (typeStr == 'warning') {
      parsedType = NotificationType.warning;
    }

    String formattedTime = 'Just now';
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) {
        formattedTime = 'Just now';
      } else if (diff.inHours < 1) {
        formattedTime = '${diff.inMinutes}m ago';
      } else if (diff.inDays < 1) {
        formattedTime = '${diff.inHours}h ago';
      } else {
        formattedTime = '${diff.inDays}d ago';
      }
    } else if (data['timestamp'] != null) {
      formattedTime = data['timestamp'].toString();
    }

    return NotificationItem(
      id: doc.id,
      senderName: data['senderName'] ?? 'System Monitor',
      senderEmail: data['senderEmail'] ?? 'no-reply@solarcontrol.com',
      title: data['title'] ?? 'Notice',
      message: data['message'] ?? '',
      timestamp: formattedTime,
      type: parsedType,
      category: data['category'] ?? 'System',
      panelId: data['panelId'],
      targetUid: data['targetUid'] ?? 'all',
      isRead: data['isRead'] ?? false,
    );
  }
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const Color pageBg = Color(0xFFF8FAF8);

  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 20;
  int _currentLimit = _pageSize;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
        _currentLimit += _pageSize;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isLoadingMore = false;
          });
        }
      });
    }
  }

  Future<void> _markAllAsRead(List<NotificationItem> notifications) async {
    final unreadItems = notifications.where((n) => !n.isRead).toList();
    if (unreadItems.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (var item in unreadItems) {
      final docRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc(item.id);
      batch.update(docRef, {'isRead': true});
    }

    try {
      await batch.commit();
    } catch (_) {}
  }

  Future<void> _updateReadStatusInFirestore(String id, bool isRead) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(id)
          .update({'isRead': isRead});
    } catch (_) {}
  }

  Future<void> _removeItem(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(id)
          .delete();
    } catch (_) {}
  }

  void _openEmailReaderSheet(NotificationItem item) {
    if (!item.isRead) {
      _updateReadStatusInFirestore(item.id, true);
    }

    final Color badgeColor;
    final String badgeLabel;

    switch (item.type) {
      case NotificationType.critical:
        badgeColor = const Color(0xFFDC2626);
        badgeLabel = 'CRITICAL SYSTEM ALERT';
        break;
      case NotificationType.warning:
        badgeColor = const Color(0xFFD97706);
        badgeLabel = 'WARNING';
        break;
      case NotificationType.info:
        badgeColor = const Color(0xFF16A34A);
        badgeLabel = 'ANNOUNCEMENT';
        break;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
        height: MediaQuery.of(modalContext).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeLabel,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.category.toUpperCase(),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  item.timestamp,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: badgeColor,
                    radius: 18,
                    child: Text(
                      item.senderName.isNotEmpty
                          ? item.senderName[0].toUpperCase()
                          : 'S',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.senderName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          'From: <${item.senderEmail}>',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  item.message,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            if (item.panelId != null && item.panelId!.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF092508),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(
                    CupertinoIcons.graph_circle,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'Inspect Affected Panel Hardware',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    final nav = Navigator.of(modalContext);
                    nav.pop();
                    nav.push(
                      MaterialPageRoute(
                        builder: (context) =>
                            MonitoringScreen(panelId: item.panelId!),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF20831B)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(modalContext),
                child: const Text(
                  'Close Message',
                  style: TextStyle(
                    color: Color(0xFF20831B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final List<String> targetUids = ['all'];
    if (currentUser != null) {
      targetUids.add(currentUser.uid);
    }

    return Scaffold(
      backgroundColor: pageBg,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('targetUid', whereIn: targetUids)
            .orderBy('createdAt', descending: true)
            .limit(_currentLimit)
            .snapshots(includeMetadataChanges: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF20831B)),
            );
          }

          final rawDocs = snapshot.data?.docs ?? [];
          final notifications = rawDocs
              .map((doc) => NotificationItem.fromFirestore(doc))
              .toList();

          final int unreadCount = notifications.where((n) => !n.isRead).length;

          return Scaffold(
            backgroundColor: pageBg,
            appBar: _buildAppBar(context, unreadCount, notifications),
            body: notifications.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: notifications.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == notifications.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Color(0xFF20831B),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        );
                      }

                      final item = notifications[index];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _removeItem(item.id),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            CupertinoIcons.trash,
                            color: Color(0xFFDC2626),
                            size: 22,
                          ),
                        ),
                        child: _buildNotificationCard(item),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    int unreadCount,
    List<NotificationItem> notifications,
  ) {
    return AppBar(
      backgroundColor: pageBg,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF20831B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (unreadCount > 0)
          TextButton(
            onPressed: () => _markAllAsRead(notifications),
            child: const Text(
              'Read All',
              style: TextStyle(
                color: Color(0xFF20831B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotificationCard(NotificationItem item) {
    final Color iconColor;
    final IconData iconData;

    switch (item.type) {
      case NotificationType.critical:
        iconColor = const Color(0xFFDC2626);
        iconData = CupertinoIcons.exclamationmark_triangle_fill;
        break;
      case NotificationType.warning:
        iconColor = const Color(0xFFD97706);
        iconData = CupertinoIcons.bolt_horizontal_circle_fill;
        break;
      case NotificationType.info:
        iconColor = const Color(0xFF16A34A);
        iconData = CupertinoIcons.info_circle_fill;
        break;
    }

    return GestureDetector(
      onTap: () => _openEmailReaderSheet(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.senderName} (${item.senderEmail})',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: item.isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.timestamp,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: item.isRead
                          ? Colors.grey.shade600
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.bell_slash,
              size: 40,
              color: Color(0xFF16A34A),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'All Caught Up!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You have no new notifications.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}


//finally done
//firestore optimized
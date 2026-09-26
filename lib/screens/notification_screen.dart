import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum NotificationType {
  info, // Green: App Updates, Patches, TOS, General Reminders
  warning, // Yellow: Degradation prevention (dust, shading, cleaning)
  critical, // Red: Fires, Sensor nonfunctional/wiring failures
}

class NotificationItem {
  final String id;
  final String senderName;
  final String senderEmail;
  final String title;
  final String message;
  final String timestamp;
  final NotificationType type;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.senderName,
    required this.senderEmail,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
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

    return NotificationItem(
      id: doc.id,
      senderName: data['senderName'] ?? 'System Monitor',
      senderEmail: data['senderEmail'] ?? 'no-reply@solarcontrol.com',
      title: data['title'] ?? 'Notice',
      message: data['message'] ?? '',
      timestamp: data['timestamp'] ?? 'Just now',
      type: parsedType,
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

  Timer? _pollingTimer;
  bool _isLoading = true;

  // CHECK INTERVAL SETTING:
  // For testing: Duration(seconds: 1)
  // For deployment: Change to Duration(hours: 1)
  static const Duration _checkInterval = Duration(
    seconds: 1,
  ); // <-- CHANGE TO Duration(hours: 1) FOR DEPLOYMENT

  // Clean initialization - zero hardcoded data
  List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    // Fetch directly from Firebase on launch
    _fetchNotificationsFromFirebase();

    // Setup periodic polling interval
    _pollingTimer = Timer.periodic(_checkInterval, (_) {
      _fetchNotificationsFromFirebase();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchNotificationsFromFirebase() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _notifications = snapshot.docs
              .map((doc) => NotificationItem.fromFirestore(doc))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _notifications = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      for (var item in _notifications) {
        item.isRead = true;
      }
    });

    for (var item in _notifications) {
      _updateReadStatusInFirestore(item.id, true);
    }
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
    setState(() {
      _notifications.removeWhere((item) => item.id == id);
    });

    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(id)
          .delete();
    } catch (_) {}
  }

  void _openEmailReaderSheet(NotificationItem item) {
    if (!item.isRead) {
      setState(() => item.isRead = true);
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
        badgeLabel = 'SYSTEM ANNOUNCEMENT';
        break;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
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
                      item.senderName[0].toUpperCase(),
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
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20831B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close Message',
                  style: TextStyle(
                    color: Colors.white,
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
    final int unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: _buildAppBar(context, unreadCount),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF20831B)),
            )
          : _notifications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final item = _notifications[index];
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
  }

  AppBar _buildAppBar(BuildContext context, int unreadCount) {
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
            onPressed: _markAllAsRead,
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
                  Text(
                    '${item.senderName} (${item.senderEmail})',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

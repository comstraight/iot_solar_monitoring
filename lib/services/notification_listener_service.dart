// notification_listener_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'top_notification_service.dart';

class NotificationListenerService {
  static StreamSubscription<QuerySnapshot>? _subscription;
  static bool _isInitialLoad = true;

  static void initialize() {
    _subscription?.cancel();
    _isInitialLoad = true;

    final currentUser = FirebaseAuth.instance.currentUser;
    final List<String> targetUids = ['all'];
    if (currentUser != null) {
      targetUids.add(currentUser.uid);
    }

    _subscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('targetUid', whereIn: targetUids)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots(includeMetadataChanges: false)
        .listen(
          (snapshot) {
            // Skip existing database records on initial app launch
            if (_isInitialLoad) {
              _isInitialLoad = false;
              return;
            }

            // Only fire banner for documents added AFTER initial load
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final data = change.doc.data() as Map<String, dynamic>? ?? {};

                final String title = data['title'] ?? 'Notice';
                final String message = data['message'] ?? '';
                final String type =
                    data['type']?.toString().toLowerCase() ?? 'info';
                final String? panelId = data['panelId'];

                showGlobalTopNotification(
                  title: title,
                  message: message,
                  type: type,
                  panelId: panelId,
                );
              }
            }
          },
          onError: (error) {
            // Handle stream error if necessary
          },
        );
  }

  static void dispose() {
    _subscription?.cancel();
  }
}

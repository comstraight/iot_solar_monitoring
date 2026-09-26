import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TermsAndPrivacyScreen extends StatefulWidget {
  const TermsAndPrivacyScreen({super.key});

  @override
  State<TermsAndPrivacyScreen> createState() => _TermsAndPrivacyScreenState();
}

class _TermsAndPrivacyScreenState extends State<TermsAndPrivacyScreen> {
  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color borderGreen = Color(0xFF20341E);
  static const Color pageBg = Colors.white;

  Timer? _pollingTimer;
  bool _isLoading = true;

  // CHECK INTERVAL SETTING:
  // For testing: Duration(seconds: 1)
  // For deployment: Change to Duration(hours: 24)
  static const Duration _checkInterval = Duration(
    seconds: 1,
  ); // <-- CHANGE TO Duration(hours: 24) FOR DEPLOYMENT

  String _lastUpdated = 'Loading...';
  String _copyright = '© 2026 Solar Telemetry System';
  List<Map<String, String>> _sections = [];

  @override
  void initState() {
    super.initState();
    _fetchTermsFromFirebase();

    // Setup periodic polling interval
    _pollingTimer = Timer.periodic(_checkInterval, (_) {
      _fetchTermsFromFirebase();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTermsFromFirebase() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('terms_and_privacy')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final rawSections = data['sections'] as List<dynamic>? ?? [];

        final List<Map<String, String>> parsedSections = rawSections.map((sec) {
          final map = sec as Map<String, dynamic>;
          return {
            'title': map['title']?.toString() ?? '',
            'content': map['content']?.toString() ?? '',
          };
        }).toList();

        if (mounted) {
          setState(() {
            _lastUpdated = data['lastUpdated'] ?? 'Unknown Date';
            _copyright = data['copyright'] ?? '© 2026 Solar Telemetry System';
            _sections = parsedSections;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: midGreen))
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildTopHeader(context),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'Last Updated: $_lastUpdated',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_sections.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.0),
                          child: Center(
                            child: Text(
                              'No terms or privacy policies found.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ..._sections.map(
                          (sec) => _SectionWidget(
                            title: sec['title'] ?? '',
                            content: sec['content'] ?? '',
                          ),
                        ),
                      const SizedBox(height: 32),
                      Center(
                        child: Text(
                          _copyright,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 16,
        left: 16,
        right: 16,
        bottom: 25,
      ),
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
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: borderGreen, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    CupertinoIcons.chevron_left,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Terms & Privacy',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            'Legal Agreements & Data Protection Policy',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _SectionWidget extends StatelessWidget {
  final String title;
  final String content;

  const _SectionWidget({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 18, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

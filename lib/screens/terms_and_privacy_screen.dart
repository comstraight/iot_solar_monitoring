import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TermsAndPrivacyScreen extends StatefulWidget {
  const TermsAndPrivacyScreen({super.key});

  @override
  State<TermsAndPrivacyScreen> createState() => _TermsAndPrivacyScreenState();
}

class _TermsAndPrivacyScreenState extends State<TermsAndPrivacyScreen> {
  // Color Palette Constants
  static const Color darkGreen = Color(0xFF092508);
  static const Color midGreen = Color(0xFF20831B);
  static const Color borderGreen = Color(0xFF20341E);
  static const Color pageBg = Colors.white;
  static const Color textGrey = Colors.grey;

  // Firestore Collection, Document & Key Constants
  static const String _collectionSystemStatus = 'system_status';
  static const String _docCurrent = 'current';
  static const String _fieldGlobals = 'globals';
  static const String _fieldTermsAndConditions = 'terms_and_conditions';
  static const String _fieldSections = 'sections';
  static const String _fieldTitle = 'title';
  static const String _fieldContent = 'content';
  static const String _fieldAcceptedAt = 'accepted_at';
  static const String _fieldLastUpdated = 'lastUpdated';
  static const String _fieldCopyright = 'copyright';

  // Text Strings Constants
  static const String _textLoading = 'Loading...';
  static const String _textDefaultCopyright = '© 2026 Solar Telemetry System';
  static const String _textUnknownDate = 'Unknown Date';
  static const String _textFallbackDate = 'October 2026';
  static const String _textLastUpdatedPrefix = 'Last Updated: ';
  static const String _textNoTermsFound = 'No terms or privacy policies found.';
  static const String _textHeaderTitle = 'Terms & Privacy';
  static const String _textHeaderSubtitle =
      'Legal Agreements & Data Protection Policy';

  // Fallback Section Content Constants
  static const String _textFallbackSec1Title = '1. Terms of Service';
  static const String _textFallbackSec1Content =
      'By using the Solar Telemetry application, you agree to monitor solar system metrics responsibly. Data transmitted across sensors is intended for real-time diagnostics and energy production tracking.';
  static const String _textFallbackSec2Title = '2. Privacy & Data Handling';
  static const String _textFallbackSec2Content =
      'We collect device usage metrics, panel status updates, and configuration parameters solely to optimize hardware diagnostics and compute accurate utility savings. Personal credentials are end-to-end encrypted.';

  static const List _defaultFallbackSections = [
    {
      _fieldTitle: _textFallbackSec1Title,
      _fieldContent: _textFallbackSec1Content,
    },
    {
      _fieldTitle: _textFallbackSec2Title,
      _fieldContent: _textFallbackSec2Content,
    },
  ];

  // Layout, Dimension & Font Size Constants
  static const double _spacing12 = 12.0;
  static const double _spacing16 = 16.0;
  static const double _spacing18 = 18.0;
  static const double _spacing25 = 25.0;
  static const double _spacing32 = 32.0;
  static const double _backButtonSize = 36.0;

  static const double _fontSizeSubtext = 11.0;
  static const double _fontSizePageTitle = 32.0;

  static const double _borderWidth15 = 1.5;
  static const double _iconSizeChevron = 18.0;
  static const double _headerRadius = 20.0;
  static const double _gradientStopTop = 0.38;
  static const double _gradientStopBottom = 1.0;

  bool _isLoading = true;
  String _lastUpdated = _textLoading;
  String _copyright = _textDefaultCopyright;
  List _sections = [];

  @override
  void initState() {
    super.initState();
    _fetchTermsFromFirebase();
  }

  String _formatDate(dynamic rawDate) {
    if (rawDate == null) return _textUnknownDate;
    if (rawDate is Timestamp) {
      final dt = rawDate.toDate();
      final monthStr = dt.month.toString().padLeft(2, '0');
      final dayStr = dt.day.toString().padLeft(2, '0');
      return '${dt.year}-$monthStr-$dayStr';
    }
    return rawDate.toString();
  }

  Future<void> _fetchTermsFromFirebase() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collectionSystemStatus)
          .doc(_docCurrent)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final globals = data[_fieldGlobals] as Map<String, dynamic>? ?? {};
        final terms =
            globals[_fieldTermsAndConditions] as Map<String, dynamic>? ?? {};

        final rawSections = terms[_fieldSections] as List<dynamic>? ?? [];

        final List parsedSections = rawSections.map((sec) {
          final map = sec as Map<String, dynamic>;
          return {
            _fieldTitle: map[_fieldTitle]?.toString() ?? '',
            _fieldContent: map[_fieldContent]?.toString() ?? '',
          };
        }).toList();

        if (mounted) {
          setState(() {
            _lastUpdated = _formatDate(
              terms[_fieldAcceptedAt] ?? terms[_fieldLastUpdated],
            );
            _copyright =
                terms[_fieldCopyright]?.toString() ?? _textDefaultCopyright;
            _sections = parsedSections.isNotEmpty
                ? parsedSections
                : _defaultFallbackSections;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _sections = _defaultFallbackSections;
            _lastUpdated = _textFallbackDate;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sections = _defaultFallbackSections;
          _lastUpdated = _textFallbackDate;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isLoading
            ? const Center(
                key: ValueKey('loading'),
                child: CircularProgressIndicator(color: midGreen),
              )
            : ListView(
                key: const ValueKey('content'),
                padding: EdgeInsets.zero,
                children: [
                  _buildTopHeader(context),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _spacing16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: _spacing16),
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, (1 - value) * 12),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            '$_textLastUpdatedPrefix$_lastUpdated',
                            style: const TextStyle(
                              fontSize: _fontSizeSubtext,
                              fontWeight: FontWeight.bold,
                              color: textGrey,
                            ),
                          ),
                        ),
                        const SizedBox(height: _spacing12),
                        if (_sections.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: _spacing32),
                            child: Center(
                              child: Text(
                                _textNoTermsFound,
                                style: TextStyle(color: textGrey),
                              ),
                            ),
                          )
                        else
                          ..._sections.asMap().entries.map(
                            (entry) => _SectionWidget(
                              title: entry.value[_fieldTitle] ?? '',
                              content: entry.value[_fieldContent] ?? '',
                              index: entry.key,
                            ),
                          ),
                        const SizedBox(height: _spacing32),
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Opacity(opacity: value, child: child);
                          },
                          child: Center(
                            child: Text(
                              _copyright,
                              style: TextStyle(
                                fontSize: _fontSizeSubtext,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: _spacing32),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.only(
        top: topPadding + _spacing16,
        left: _spacing16,
        right: _spacing16,
        bottom: _spacing25,
      ),
      decoration: const BoxDecoration(
        color: darkGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(_headerRadius),
          bottomRight: Radius.circular(_headerRadius),
        ),
        gradient: LinearGradient(
          colors: [darkGreen, midGreen],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [_gradientStopTop, _gradientStopBottom],
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
                  height: _backButtonSize,
                  width: _backButtonSize,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: borderGreen,
                      width: _borderWidth15,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    CupertinoIcons.chevron_left,
                    size: _iconSizeChevron,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _spacing18),
          const Text(
            _textHeaderTitle,
            style: TextStyle(
              fontSize: _fontSizePageTitle,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            _textHeaderSubtitle,
            style: TextStyle(fontSize: _fontSizeSubtext, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _SectionWidget extends StatelessWidget {
  final String title;
  final String content;
  final int index;

  const _SectionWidget({
    required this.title,
    required this.content,
    this.index = 0,
  });

  static const double _spacing4 = 4.0;
  static const double _spacing8 = 8.0;
  static const double _spacing16 = 16.0;
  static const double _spacing18 = 18.0;
  static const double _fontSizeSectionTitle = 20.0;
  static const double _fontSizeContent = 13.0;
  static const double _cardRadius = 12.0;
  static const double _shadowAlpha = 0.2;
  static const double _shadowSpread = 2.0;
  static const double _shadowBlur = 3.0;
  static const double _lineHeightContent = 1.4;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 80)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: _spacing4,
              top: _spacing18,
              bottom: _spacing8,
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: _fontSizeSectionTitle,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_cardRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: _shadowAlpha),
                  spreadRadius: _shadowSpread,
                  blurRadius: _shadowBlur,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(_spacing16),
              child: Text(
                content,
                style: const TextStyle(
                  fontSize: _fontSizeContent,
                  color: Colors.black87,
                  height: _lineHeightContent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

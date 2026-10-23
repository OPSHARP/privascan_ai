import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('About'),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leadingWidth: 80,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(CupertinoIcons.back), Text('Back')],
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          children: [
            _buildAppHeader(theme),
            const SizedBox(height: 32),
            _buildGroupedCard(
              theme,
              children: [
                _buildLanguageSection(
                  theme,
                  icon: CupertinoIcons.globe,
                  title: 'English',
                  content: _englishDescription,
                  isLast: false,
                ),
                _buildLanguageSection(
                  theme,
                  icon: CupertinoIcons.textformat_abc,
                  title: 'हिन्दी',
                  content: _hindiDescription,
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: Text(
                  'FEATURES',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            _buildGroupedCard(
              theme,
              children: [
                _buildFeatureRow(
                  theme,
                  CupertinoIcons.lock_fill,
                  '100% Offline — No Data Sent',
                  CupertinoColors.activeGreen,
                  false,
                ),
                _buildFeatureRow(
                  theme,
                  CupertinoIcons.money_dollar_circle_fill,
                  'Completely Free',
                  CupertinoColors.activeOrange,
                  false,
                ),
                _buildFeatureRow(
                  theme,
                  CupertinoIcons.device_phone_portrait,
                  'On-Device AI Processing',
                  CupertinoColors.activeBlue,
                  false,
                ),
                _buildFeatureRow(
                  theme,
                  CupertinoIcons.camera_fill,
                  'Camera & Gallery Scanning',
                  CupertinoColors.systemIndigo,
                  false,
                ),
                _buildFeatureRow(
                  theme,
                  CupertinoIcons.doc_text_fill,
                  'OCR Text Recognition',
                  CupertinoColors.systemTeal,
                  false,
                ),
                _buildFeatureRow(
                  theme,
                  CupertinoIcons.sparkles,
                  'AI Summarization & Q&A',
                  CupertinoColors.systemPurple,
                  true,
                ),
              ],
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                '© 2026 PrivaScan AI',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          height: 84,
          width: 84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            CupertinoIcons.doc_text_viewfinder,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppConstants.appName,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Version ${AppConstants.appVersion}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildGroupedCard(ThemeData theme, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildLanguageSection(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String content,
    required bool isLast,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Divider(height: 1, color: theme.dividerTheme.color),
          ),
      ],
    );
  }

  Widget _buildFeatureRow(
    ThemeData theme,
    IconData icon,
    String text,
    Color color,
    bool isLast,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 17,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Divider(height: 1, color: theme.dividerTheme.color),
          ),
      ],
    );
  }
}

const String _englishDescription =
    'PrivaScan AI is a privacy-first, on-device document scanner and summarizer. '
    'It allows you to scan documents using your camera or import from the gallery, '
    'extract text using OCR (Optical Character Recognition) via Google ML Kit, '
    'and generate AI-powered summaries, action items, and key entities — all '
    'completely offline with no data ever leaving your device.\n\n'
    'Your privacy is our priority — everything runs locally on your device. '
    'No accounts, no sign-ups, no data collection, no internet required.';

const String _hindiDescription =
    'PrivaScan AI एक प्राइवेसी-फर्स्ट, ऑन-डिवाइस डॉक्यूमेंट स्कैनर और सारांशकर्ता है। '
    'यह आपको अपने कैमरे का उपयोग करके दस्तावेज़ों को स्कैन करने या गैलरी से आयात करने, '
    'Google ML Kit के माध्यम से OCR (ऑप्टिकल कैरेक्टर रिकॉग्निशन) का उपयोग करके टेक्स्ट निकालने, '
    'और AI-संचालित सारांश, एक्शन आइटम और प्रमुख संस्थाएँ उत्पन्न करने की सुविधा देता है — '
    'यह सब पूरी तरह से ऑफ़लाइन, आपके डिवाइस पर होता है और कोई डेटा कभी भी आपके डिवाइस से बाहर नहीं जाता।\n\n'
    'आपकी गोपनीयता हमारी प्राथमिकता है — सब कुछ आपके डिवाइस पर स्थानीय रूप से चलता है। '
    'कोई खाता नहीं, कोई साइन-अप नहीं, कोई डेटा संग्रह नहीं, कोई इंटरनेट की आवश्यकता नहीं।';

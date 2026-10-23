import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme, 'Privacy Policy'),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                'Effective Date: October 22, 2026',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildGroupedCard(
              theme,
              children: [
                _buildPolicySection(
                  theme,
                  '1. Our Privacy-First Architecture',
                  '''PrivaScan AI ("the App", "we", "us", or "our") is architected from the ground up as a zero-cloud-upload, privacy-first mobile document scanner.

We firmly believe your personal documents, receipts, contracts, tax papers, and identity documents belong strictly to you. All document processing — including edge detection, image perspective filtering, Optical Character Recognition (OCR), on-device document classification, language translation, and Text-to-Speech (TTS) — executes 100% locally on your smartphone processor using Google ML Kit on-device binaries. Your document pixels and extracted text never traverse our servers, nor do we operate remote servers that collect or aggregate document data.''',
                  isLast: false,
                ),
                _buildPolicySection(
                  theme,
                  '2. Information We Process & Store Locally',
                  '''a) Scanned Images and PDF Documents:
- Captured camera photographs and imported images are saved exclusively within your device's isolated app storage sandbox or your chosen public Documents directory (/Documents/PrivaScan).
- We do not transmit or duplicate these files to any external network location.

b) Digital Signatures and Official Stamps:
- VIP members can create vector digital signatures and custom stamps.
- Signature strokes and stamp graphics are saved strictly in local encrypted device memory and composited onto your document locally.

c) Document Passwords:
- When exporting a password-protected PDF, your chosen password is used strictly in real-time by the local cryptographic ISO 32000-1 engine to generate the standard 128-bit encrypted PDF stream.
- We never store, log, or transmit your document passwords anywhere.''',
                  isLast: false,
                ),
                _buildPolicySection(
                  theme,
                  '3. Google Play Billing & In-App Subscriptions',
                  '''a) VIP Pass Subscription (₹99 / month):
- Payments, renewals, cancellations, and billing transactions are processed exclusively by Google LLC through the official Google Play Billing Library.
- PrivaScan AI does not collect, receive, or store credit card numbers, bank account credentials, UPI IDs, or financial account data. All billing is governed by the Google Play Terms of Service.

b) Subscription Management:
- Subscriptions automatically renew monthly unless canceled at least 24 hours prior to the conclusion of the active billing period in your Google Play Store account settings.
- You can manage or cancel your subscription anytime via Google Play > Payments & Subscriptions.''',
                  isLast: false,
                ),
                _buildPolicySection(
                  theme,
                  '4. Advertisements & VIP 100% Ad-Free Guarantee',
                  '''a) Free Tier Advertisements:
- The free version of PrivaScan AI utilizes Google AdMob to display banner and interstitial advertisements to support ongoing development.
- Google AdMob may collect and process device identifiers (such as the Google Advertising ID), network state, and general non-precise location to deliver contextual ads subject to Google's Privacy Policy (https://policies.google.com/privacy).

b) VIP Pass 100% Ad-Free Guarantee:
- Upon activating the VIP Pass (₹99/month), all Google AdMob network requests, banner widgets, app open ads, and interstitials are completely suppressed and disabled across the entire app.''',
                  isLast: false,
                ),
                _buildPolicySection(
                  theme,
                  '5. Android Device Permissions & Usage',
                  '''We only request essential permissions required to deliver document scanning features:
• CAMERA (android.permission.CAMERA): Required solely for viewfinder frame capture of documents, barcodes, and QR codes. Camera frames are analyzed in memory and immediately discarded unless you capture the image.
• INTERNET & ACCESS_NETWORK_STATE: Required by Google Play Billing to verify active VIP subscription status and by Google AdMob to deliver ads in free tier.
• BILLING (com.android.vending.BILLING): Enables Google Play Console official in-app purchases and subscriptions.''',
                  isLast: false,
                ),
                _buildPolicySection(
                  theme,
                  '6. Data Security & Storage Integrity',
                  '''• Local Hive Encrypted Database: Metadata, tags, and document histories are stored locally using encrypted key-value storage.
• PDF Standard Encryption: Password-protected PDFs generated by VIP users comply with international ISO 32000 standard specifications with 128-bit cipher encryption.
• We recommend keeping your Android device locked with biometric authentication (Fingerprint / PIN) and keeping device firmware updated.''',
                  isLast: false,
                ),
                _buildPolicySection(
                  theme,
                  '7. GDPR, CCPA & User Rights',
                  '''Under global privacy regulations (including GDPR, CCPA, and Indian Digital Personal Data Protection Act):
- Right of Access & Portability: You can export all your scanned documents as standard PDFs or plain text (.txt) files directly to your device storage or cloud drives at any time.
- Right of Erasure: Deleting documents within PrivaScan AI permanently removes them from local storage immediately. Uninstalling the app completely purges all local app data without residue.''',
                  isLast: false,
                ),
                _buildPolicySection(
                  theme,
                  '8. Children\'s Privacy (COPPA)',
                  '''PrivaScan AI does not knowingly collect or solicit any personal information from children under the age of 13. The app is a general-purpose document utility tool and does not require account registration or identity profiling.''',
                  isLast: false,
                ),
                _buildPolicySection(
                  theme,
                  '9. Changes to This Policy',
                  '''We may revise this Privacy Policy periodically to reflect technological advancements, Play Console policy updates, or legal compliance. Any modifications will be updated within this screen along with the "Effective Date" at the top.''',
                  isLast: false,
                ),
                _buildPolicySection(
                  theme,
                  '10. Developer Contact Information',
                  '''If you have questions, feedback, or concerns regarding our privacy practices or data handling, please reach out to us:

• Application: PrivaScan AI
• Developer: Tarun
• Support Email: drillmovies@gmail.com
• Play Store Developer: PrivaScan AI Team''',
                  isLast: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildGroupedCard(
    ThemeData theme, {
    required List<Widget> children,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildPolicySection(
    ThemeData theme,
    String title,
    String content, {
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
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: theme.dividerTheme.color ??
                theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
      ],
    );
  }
}

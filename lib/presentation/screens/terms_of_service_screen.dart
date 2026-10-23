import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Terms of Service'),
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
            _buildHeader(theme, 'Terms of Service'),
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
                _buildTermsSection(
                  theme,
                  '1. Acceptance of Terms',
                  '''By installing, downloading, or using PrivaScan AI ("the App"), you agree to be legally bound by these Terms of Service ("Terms") and our Privacy Policy. If you do not accept these Terms, do not install or use the App.

These Terms constitute a binding agreement between you and the developer ("we", "us", or "our").''',
                  isLast: false,
                ),
                _buildTermsSection(
                  theme,
                  '2. Scope of Services',
                  '''PrivaScan AI provides high-performance on-device document scanning, edge-detection, OCR text transcription, table-to-CSV extraction, offline language translation, Text-to-Speech (TTS), and PDF document compilation.

All image processing and machine learning calculations execute locally on your physical smartphone hardware without cloud uploads.''',
                  isLast: false,
                ),
                _buildTermsSection(
                  theme,
                  '3. VIP Pass Subscription & Google Play Billing',
                  '''a) Pricing & Billing (₹99 per Month):
- PrivaScan AI offers a premium subscription tier known as the "VIP Pass" priced at ₹99 per month (inclusive of all applicable taxes).
- VIP subscriptions are processed exclusively through Google Play In-App Billing (Play Billing Library). We do not collect or store direct payment credentials.

b) VIP Pass Features:
1. 100% Ad-Free Experience (complete suppression of all banners, interstitial, and open-app ads).
2. Custom Digital Signature & Custom Stamp creation and page placement.
3. Password-Protected Encrypted PDF Export (standard ISO 32000 128-bit encryption).
4. High-Res 300 DPI Lossless Scans (full camera sensor fidelity without lossy downscaling).

c) Auto-Renewal & Cancellation:
- Your subscription automatically renews every month unless canceled at least 24 hours prior to the renewal date.
- You can manage, modify, or cancel your subscription at any time by opening the Google Play Store app > Profile Icon > Payments & subscriptions > Subscriptions.
- Cancellation halts future charges; VIP perks remain active until the end of the current billing cycle.

d) Refunds:
- Refund requests are processed strictly in accordance with Google Play Refund Policies (https://support.google.com/googleplay/answer/2479637).''',
                  isLast: false,
                ),
                _buildTermsSection(
                  theme,
                  '4. User Content & Ownership',
                  '''• Ownership Guarantee: You retain 100% full legal ownership, copyright, and title to all documents, images, signatures, and texts created or scanned within PrivaScan AI.
• Zero License Transfer: We claim no ownership, license, or rights over your document content.
• Device Security: Because all files are stored locally on your physical device, you are solely responsible for backing up your documents and securing your hardware.''',
                  isLast: false,
                ),
                _buildTermsSection(
                  theme,
                  '5. Acceptable Use & Prohibited Conduct',
                  '''You agree not to use PrivaScan AI to:
- Forge, fabricate, or falsify government identity cards, currency, or unauthorized legal instruments.
- Infringe upon third-party copyrights, patents, or intellectual property rights.
- Attempt to decompile, reverse engineer, disassemble, or extract source code from the App, except to the extent permitted by applicable open-source licenses.''',
                  isLast: false,
                ),
                _buildTermsSection(
                  theme,
                  '6. Free Tier Advertisements',
                  '''The free version of PrivaScan AI contains third-party advertisements delivered by Google AdMob. We are not responsible for the content, privacy policies, or practices of third-party advertisers. Advertisements can be completely eliminated by subscribing to the VIP Pass.''',
                  isLast: false,
                ),
                _buildTermsSection(
                  theme,
                  '7. Disclaimer of Warranties',
                  '''PRIVASCAN AI IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.

While we strive for high precision, we do not warrant that Optical Character Recognition (OCR), barcode recognition, or document classification will be 100% error-free in all lighting conditions.''',
                  isLast: false,
                ),
                _buildTermsSection(
                  theme,
                  '8. Limitation of Liability',
                  '''TO THE FULLEST EXTENT PERMITTED BY LAW, NEITHER THE DEVELOPER NOR ITS AFFILIATES SHALL BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS, DATA, OR USE ARISING OUT OF YOUR ACCESS TO OR INABILITY TO USE THE APP.''',
                  isLast: false,
                ),
                _buildTermsSection(
                  theme,
                  '9. Termination',
                  '''We reserve the right to suspend or terminate app access or services if you materially breach these Terms. You may terminate your agreement anytime by canceling any active VIP subscription via Google Play and uninstalling the App.''',
                  isLast: false,
                ),
                _buildTermsSection(
                  theme,
                  '10. Governing Law',
                  '''These Terms shall be governed by and construed in accordance with the laws of India, without regard to its conflict of law principles. Any legal disputes shall be subject to the exclusive jurisdiction of competent courts in India.''',
                  isLast: false,
                ),
                _buildTermsSection(
                  theme,
                  '11. Support & Contact',
                  '''For inquiries, support, or questions regarding these Terms of Service:

• Product: PrivaScan AI
• Developer: Tarun
• Support Email: drillmovies@gmail.com''',
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

  Widget _buildTermsSection(
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

import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/services/vip_service.dart';

class VipPassScreen extends StatefulWidget {
  final String? triggerPerk;

  const VipPassScreen({super.key, this.triggerPerk});

  static Future<bool> show(BuildContext context, {String? triggerPerk}) async {
    final result = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(
        builder: (_) => VipPassScreen(triggerPerk: triggerPerk),
        fullscreenDialog: true,
      ),
    );
    return result ?? VipService.instance.isVip;
  }

  @override
  State<VipPassScreen> createState() => _VipPassScreenState();
}

class _VipPassScreenState extends State<VipPassScreen> {
  bool _isProcessing = false;

  void _subscribe() async {
    HapticFeedback.heavyImpact();
    setState(() => _isProcessing = true);

    try {
      final success = await VipService.instance.buyVipSubscription();
      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (success || VipService.instance.isVip) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.sparkles, color: CupertinoColors.systemYellow),
                SizedBox(width: 8),
                Text('Welcome to VIP!'),
              ],
            ),
            content: const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Your PrivaScan AI VIP Pass is now ACTIVE via Google Play!\n\n'
                '• 100% Ad-Free Experience\n'
                '• Digital Signature & Custom Stamps\n'
                '• Password-Protected PDF Encryption\n'
                '• 300 DPI Lossless Scans',
                textAlign: TextAlign.center,
              ),
            ),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('Awesome'),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase could not be completed: $e')),
        );
      }
    }
  }

  void _restore() async {
    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);
    await VipService.instance.restorePurchases();
    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (VipService.instance.isVip) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('VIP Pass restored successfully from Google Play!'),
          backgroundColor: CupertinoColors.activeGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active VIP Pass found on this Google account.'),
        ),
      );
    }
  }

  void _cancel() async {
    HapticFeedback.mediumImpact();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Cancel VIP Pass?'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Are you sure you want to revert to free mode? Ads and locked features will re-enable.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Keep VIP'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Cancel VIP'),
            onPressed: () async {
              Navigator.pop(ctx);
              await VipService.instance.cancelVip();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isVip = VipService.instance.isVip;
    final expiry = VipService.instance.vipExpiry;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF7F8FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            backgroundColor: (isDark ? const Color(0xFF0F0F14) : const Color(0xFFF7F8FA))
                .withValues(alpha: 0.85),
            surfaceTintColor: Colors.transparent,
            pinned: true,
            elevation: 0,
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(
                CupertinoIcons.xmark_circle_fill,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                size: 28,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Glowing Crown Badge
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB800).withValues(alpha: 0.4),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.sparkles,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'PrivaScan VIP Pass',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '100% On-Device • Maximum Privacy • Pro Tools',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Pricing Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1C1A2E), const Color(0xFF282244)]
                            : [const Color(0xFFEDE9FE), const Color(0xFFDDD6FE)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'MONTHLY PASS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (isVip)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.activeGreen,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(CupertinoIcons.checkmark_alt, size: 13, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              VipService.monthlyPrice,
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                            Text(
                              ' / month',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isVip && expiry != null
                              ? 'Valid until ${DateFormat('dd MMM yyyy').format(expiry)}'
                              : 'Billed monthly • Cancel anytime with 1 tap',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4 Core VIP Perks List
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'INCLUDED IN VIP PASS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPerkItem(
                    theme: theme,
                    icon: CupertinoIcons.slash_circle_fill,
                    iconColor: CupertinoColors.destructiveRed,
                    title: '100% Ad-Free Experience',
                    subtitle: 'Zero interruptions. No banners, no popups, full focus.',
                  ),
                  _buildPerkItem(
                    theme: theme,
                    icon: CupertinoIcons.signature,
                    iconColor: const Color(0xFF2563EB),
                    title: 'Custom Digital Signature & Stamp',
                    subtitle: 'Draw signature and apply official stamps (Approved, Paid, Custom).',
                  ),
                  _buildPerkItem(
                    theme: theme,
                    icon: CupertinoIcons.lock_shield_fill,
                    iconColor: CupertinoColors.activeGreen,
                    title: 'Password-Protected PDF Export',
                    subtitle: 'Standard encrypted PDFs that prompt for password on open.',
                  ),
                  _buildPerkItem(
                    theme: theme,
                    icon: CupertinoIcons.sparkles,
                    iconColor: const Color(0xFFD97706),
                    title: 'High-Res 300 DPI Lossless Scans',
                    subtitle: 'Print-ready crystal clarity with zero lossy compression.',
                    isLast: true,
                  ),
                  const SizedBox(height: 32),

                  // Primary Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isProcessing ? null : (isVip ? _cancel : _subscribe),
                      child: _isProcessing
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : Text(
                              isVip ? 'Cancel VIP Subscription' : 'Activate VIP Pass (₹99/mo)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (!isVip)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _restore,
                      child: Text(
                        'Restore Purchases',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerkItem({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool isLast = false,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

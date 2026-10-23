import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/repositories/document_repository_impl.dart';
import '../../data/services/ad_service.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/vip_service.dart';
import '../blocs/document_bloc.dart';
import '../blocs/theme_cubit.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'vip_pass_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar(
            backgroundColor: theme.scaffoldBackgroundColor.withValues(
              alpha: 0.85,
            ),
            surfaceTintColor: Colors.transparent,
            pinned: true,
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
            title: Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: 0.35,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVipCard(context, theme),
                  const SizedBox(height: 24),
                  _buildSectionHeader(theme, 'Appearance'),
                  _buildSettingsGroup(
                    theme,
                    children: [
                      BlocBuilder<ThemeCubit, ThemeMode>(
                        builder: (context, themeMode) {
                          String modeText;
                          IconData modeIcon;
                          switch (themeMode) {
                            case ThemeMode.light:
                              modeText = 'Light';
                              modeIcon = CupertinoIcons.sun_max_fill;
                              break;
                            case ThemeMode.dark:
                              modeText = 'Dark';
                              modeIcon = CupertinoIcons.moon_fill;
                              break;
                            case ThemeMode.system:
                              modeText = 'System Default';
                              modeIcon = CupertinoIcons.device_phone_portrait;
                              break;
                          }

                          return _buildSettingRow(
                            theme,
                            icon: modeIcon,
                            iconColor: CupertinoColors.systemPurple,
                            title: 'Theme',
                            trailing: Text(
                              modeText,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 16,
                              ),
                            ),
                            showChevron: true,
                            isLast: true,
                            onTap: () => _showThemeSelectionDialog(context, themeMode),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader(theme, 'Data & Storage'),
                  _buildSettingsGroup(
                    theme,
                    children: [
                      _buildSettingRow(
                        theme,
                        icon: CupertinoIcons.folder_fill,
                        iconColor: CupertinoColors.activeBlue,
                        title: 'Document Storage',
                        trailing: const Text(
                          'Local Device',
                          style: TextStyle(color: CupertinoColors.systemGrey),
                        ),
                        isLast: false,
                      ),
                      _buildSettingRow(
                        theme,
                        icon: CupertinoIcons.arrow_up_doc_fill,
                        iconColor: CupertinoColors.activeGreen,
                        title: 'Export Offline Backup',
                        trailing: const Text(
                          '.privascan',
                          style: TextStyle(
                            color: CupertinoColors.activeGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        showChevron: true,
                        isLast: false,
                        onTap: () => _exportBackup(context),
                      ),
                      _buildSettingRow(
                        theme,
                        icon: CupertinoIcons.arrow_down_doc_fill,
                        iconColor: CupertinoColors.systemIndigo,
                        title: 'Restore from Backup',
                        showChevron: true,
                        isLast: false,
                        onTap: () => _restoreBackup(context),
                      ),
                      _buildSettingRow(
                        theme,
                        icon: CupertinoIcons.trash_fill,
                        iconColor: CupertinoColors.destructiveRed,
                        title: 'Delete All Documents',
                        showChevron: true,
                        isLast: true,
                        onTap: () => _showDeleteAllDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader(theme, 'Legal'),
                  _buildSettingsGroup(
                    theme,
                    children: [
                      _buildSettingRow(
                        theme,
                        icon: CupertinoIcons.hand_raised_fill,
                        iconColor: CupertinoColors.activeBlue,
                        title: 'Privacy Policy',
                        showChevron: true,
                        isLast: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => const PrivacyPolicyScreen(),
                            ),
                          );
                        },
                      ),
                      _buildSettingRow(
                        theme,
                        icon: CupertinoIcons.doc_text_fill,
                        iconColor: CupertinoColors.activeOrange,
                        title: 'Terms of Service',
                        showChevron: true,
                        isLast: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (_) => const TermsOfServiceScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader(theme, 'Support'),
                  _buildSettingsGroup(
                    theme,
                    children: [
                      _buildSettingRow(
                        theme,
                        icon: CupertinoIcons.mail_solid,
                        iconColor: CupertinoColors.activeBlue,
                        title: 'Contact Support',
                        showChevron: true,
                        isLast: true,
                        onTap: () async {
                          final url = Uri.parse(
                            'https://tarunappdev.blogspot.com',
                          );
                          if (await canLaunchUrl(url)) {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      '© 2026 PrivaScan AI',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BannerAdWidget(),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(
    ThemeData theme, {
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingRow(
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? trailing,
    bool showChevron = false,
    required bool isLast,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.only(left: 16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: trailing,
                    ),
                  if (showChevron)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Icon(
                        CupertinoIcons.chevron_forward,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.3,
                        ),
                        size: 20,
                      ),
                    )
                  else
                    const SizedBox(width: 16),
                ],
              ),
            ),
            if (!isLast)
              Padding(
                padding: const EdgeInsets.only(left: 46),
                child: Divider(height: 1, color: theme.dividerTheme.color),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAllDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete All Documents'),
        content: const Text(
          'This will permanently delete all scanned documents. This action cannot be undone. Are you sure?',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              context.read<DocumentBloc>().add(DeleteAllDocuments());
              Navigator.pop(context);
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  void _showThemeSelectionDialog(BuildContext context, ThemeMode currentMode) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select Appearance'),
        message: const Text('Choose how PrivaScan AI looks on your device'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              context.read<ThemeCubit>().setThemeMode(ThemeMode.system);
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.device_phone_portrait, size: 20),
                const SizedBox(width: 8),
                const Text('System Default'),
                if (currentMode == ThemeMode.system) ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark, size: 18),
                ],
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              context.read<ThemeCubit>().setThemeMode(ThemeMode.light);
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.sun_max_fill, size: 20),
                const SizedBox(width: 8),
                const Text('Light Mode'),
                if (currentMode == ThemeMode.light) ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark, size: 18),
                ],
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              context.read<ThemeCubit>().setThemeMode(ThemeMode.dark);
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.moon_fill, size: 20),
                const SizedBox(width: 8),
                const Text('Dark Mode'),
                if (currentMode == ThemeMode.dark) ...[
                  const SizedBox(width: 8),
                  const Icon(CupertinoIcons.checkmark, size: 18),
                ],
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    final repo = context.read<DocumentRepositoryImpl>();
    final backupService = BackupService(repo);

    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CupertinoAlertDialog(
        content: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(radius: 14),
              SizedBox(height: 16),
              Text(
                'Compressing offline backup...',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );

    final result = await backupService.createBackup();
    if (context.mounted) {
      Navigator.pop(context); // Close loading dialog
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(result.success ? 'Backup Created' : 'Backup Notice'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(result.message),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final repo = context.read<DocumentRepositoryImpl>();
    final backupService = BackupService(repo);

    final result = await backupService.restoreBackup();
    if (context.mounted) {
      if (result.success) {
        context.read<DocumentBloc>().add(LoadDocuments());
      }
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(result.success ? 'Restore Complete' : 'Restore Notice'),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(result.message),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildVipCard(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return ValueListenableBuilder<bool>(
      valueListenable: VipService.instance.vipStatusNotifier,
      builder: (context, isVip, _) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (_) => const VipPassScreen(),
                fullscreenDialog: true,
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: isVip
                    ? (isDark
                        ? [const Color(0xFF2E2410), const Color(0xFF3F3010)]
                        : [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)])
                    : (isDark
                        ? [const Color(0xFF221A3A), const Color(0xFF312554)]
                        : [const Color(0xFFEDE9FE), const Color(0xFFDDD6FE)]),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: isVip
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                    : const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isVip ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6))
                      .withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isVip
                          ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                          : [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isVip ? const Color(0xFFFFB800) : const Color(0xFF8B5CF6))
                            .withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    isVip ? CupertinoIcons.sparkles : CupertinoIcons.bolt_fill,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isVip ? 'PrivaScan VIP Active' : 'PrivaScan VIP Pass',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isVip
                                  ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309))
                                  : (isDark ? Colors.white : const Color(0xFF5B21B6)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isVip ? CupertinoColors.activeGreen : const Color(0xFF7C3AED),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isVip ? 'ACTIVE' : '₹99/MO',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isVip
                            ? '100% Ad-Free • Sign & Stamp • Password PDF • 300 DPI'
                            : 'Unlock Ad-Free, Sign & Stamp, Password PDF & 300 DPI',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

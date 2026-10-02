import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/desktop_content_width.dart';
import '../../../l10n/l10n.dart';
import '../../../core/utils/external_url.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _githubUrl = 'https://github.com/ganeshapp/JekyllPress';
  static const String _privacyUrl =
      'https://github.com/ganeshapp/JekyllPress/blob/main/PRIVACY.md';
  static const String _creatorUrl = 'https://www.gapp.in';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundGradient(context),
        child: SafeArea(
          child: DesktopContentWidth(
            child: CustomScrollView(
              slivers: [
                _buildAppBar(context),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLogo(context),
                        const SizedBox(height: 32),
                        _buildSection(
                          context,
                          icon: Icons.info_outline_rounded,
                          title: context.l10n.aboutSectionTitle,
                          content: context.l10n.aboutSectionBody,
                        ),
                        const SizedBox(height: 24),
                        _buildSection(
                          context,
                          icon: Icons.lightbulb_outline_rounded,
                          title: context.l10n.motivationTitle,
                          content: context.l10n.motivationBody,
                        ),
                        const SizedBox(height: 24),
                        _buildSection(
                          context,
                          icon: Icons.play_circle_outline_rounded,
                          title: context.l10n.howToUseTitle,
                          content: context.l10n.howToUseBody,
                        ),
                        const SizedBox(height: 24),
                        _buildSection(
                          context,
                          icon: Icons.warning_amber_rounded,
                          title: context.l10n.limitationsTitle,
                          content: context.l10n.limitationsBody,
                        ),
                        const SizedBox(height: 24),
                        _buildSection(
                          context,
                          icon: Icons.privacy_tip_outlined,
                          title: context.l10n.privacySectionTitle,
                          content: context.l10n.privacySectionBody,
                          actionLabel: context.l10n.readPrivacyPolicy,
                          onAction: () => _launchUrl(context, _privacyUrl),
                        ),
                        const SizedBox(height: 24),
                        _buildSection(
                          context,
                          icon: Icons.code_rounded,
                          title: context.l10n.openSourceTitle,
                          content: context.l10n.openSourceBody,
                          actionLabel: context.l10n.viewOnGitHub,
                          onAction: () => _launchUrl(context, _githubUrl),
                        ),
                        const SizedBox(height: 32),
                        _buildCreatorCard(context),
                        const SizedBox(height: 32),
                        _buildLicenseSection(context),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        color: context.colorScheme.onSurfaceVariant,
        tooltip: context.l10n.commonBack,
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        context.l10n.aboutLabel,
        style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      centerTitle: false,
      pinned: false,
      floating: true,
    );
  }

  Widget _buildLogo(BuildContext context) {
    final scheme = context.colorScheme;
    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'JekyllPress.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      size: 48,
                      color: scheme.primary,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.aboutAppName,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: scheme.tertiary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            // Real installed version from the platform (not a hardcoded
            // string that goes stale)
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                final label = info == null
                    ? context.l10n.versionLoading
                    : context.l10n.versionLabel(info.version, info.buildNumber);
                return Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: scheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(actionLabel),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCreatorCard(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      button: true,
      label: context.l10n.creatorCardSemantics,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _launchUrl(context, _creatorUrl),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primaryContainer,
                  scheme.surfaceContainerHigh,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.primary.withAlpha(40),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary,
                        Color.lerp(scheme.primary, Colors.black, 0.15)!,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'G',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.createdByLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Gapp',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: scheme.tertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.language_rounded,
                            size: 14,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'www.gapp.in',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.primary.withAlpha(200),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLicenseSection(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outline,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.appColors.info.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.gavel_rounded,
                  size: 20,
                  color: context.appColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                context.l10n.mitLicenseTitle,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: scheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Copyright © 2026 Gapp\n\n'
            'Permission is hereby granted, free of charge, to any person obtaining '
            'a copy of this software and associated documentation files, to deal '
            'in the Software without restriction, including without limitation the '
            'rights to use, copy, modify, merge, publish, distribute, sublicense, '
            'and/or sell copies of the Software.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: scheme.onSurfaceVariant.withAlpha(200),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    // Tries an in-app tab, then an external browser; only then do we fall back
    // to the clipboard below.
    if (await openExternalUrl(context, url, copyOnFailure: false)) return;
    if (!context.mounted) return;

    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.link_rounded,
              color: context.colorScheme.onSurface,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.linkCopiedSnack(url),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

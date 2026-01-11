import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _version = '1.0.0';
  static const String _githubUrl = 'https://github.com/ganeshapp/JekyllPress';
  static const String _creatorUrl = 'https://www.gapp.in';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 32),
                      _buildSection(
                        context,
                        icon: Icons.info_outline_rounded,
                        title: 'About Jekyll Press',
                        content:
                            'Jekyll Press is a mobile-first CMS designed for bloggers who use '
                            'GitHub Pages with Jekyll. Write, edit, and publish your blog posts '
                            'directly from your phone — no laptop required.\n\n'
                            'Built with Flutter and powered by the GitHub REST API, Jekyll Press '
                            'brings the full blogging experience to your pocket.',
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        context,
                        icon: Icons.lightbulb_outline_rounded,
                        title: 'Motivation',
                        content:
                            'As a developer who blogs on GitHub Pages, I often found inspiration '
                            'for new posts while away from my computer. Jekyll Press was born from '
                            'the need to capture and publish those ideas immediately, without '
                            'waiting to get back to a desktop.\n\n'
                            'The goal is simple: make mobile blogging on Jekyll as seamless as '
                            'writing in any native notes app.',
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        context,
                        icon: Icons.play_circle_outline_rounded,
                        title: 'How to Use',
                        content:
                            '1. Generate a GitHub Personal Access Token (PAT) with "repo" scope\n'
                            '2. Paste the token in the login screen\n'
                            '3. Select your Jekyll blog repository\n'
                            '4. Set your image assets path (usually "assets/images")\n'
                            '5. Start writing! Tap the + button to create a new post\n'
                            '6. Use the Preview tab to see your formatted markdown\n'
                            '7. Hit Publish to push directly to GitHub',
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        context,
                        icon: Icons.warning_amber_rounded,
                        title: 'Limitations',
                        content:
                            '• Requires an active internet connection to publish\n'
                            '• Only supports repositories with a _posts folder\n'
                            '• Image uploads are limited to JPEG format\n'
                            '• Post titles cannot be changed after publishing\n'
                            '• Currently Android only (iOS coming soon)',
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        context,
                        icon: Icons.code_rounded,
                        title: 'Open Source',
                        content:
                            'Jekyll Press is open source under the MIT License. '
                            'Found a bug or have a feature request? Head over to GitHub to:\n\n'
                            '• Report issues\n'
                            '• Request features\n'
                            '• Contribute code\n'
                            '• Star the repo ⭐',
                        actionLabel: 'View on GitHub',
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
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        color: const Color(0xFFA8B5A0),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'About',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      centerTitle: false,
      pinned: false,
      floating: true,
    );
  }

  Widget _buildLogo() {
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
                  color: const Color(0xFF000000).withAlpha(40),
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
                      color: const Color(0xFF2D4A3E),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      size: 48,
                      color: Color(0xFFE8A87C),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Jekyll Press',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE8D5B5),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8A87C).withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Version $_version',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFE8A87C),
                fontWeight: FontWeight.w500,
              ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2F23),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2D4A3E),
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
                  color: const Color(0xFFE8A87C).withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: const Color(0xFFE8A87C),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE8D5B5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFFA8B5A0),
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
                  foregroundColor: const Color(0xFFE8A87C),
                  side: const BorderSide(color: Color(0xFFE8A87C)),
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
    return GestureDetector(
      onTap: () => _launchUrl(context, _creatorUrl),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2D4A3E),
              Color(0xFF1A2F23),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE8A87C).withAlpha(40),
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
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE8A87C),
                    Color(0xFFD4956A),
                  ],
                ),
              ),
              child: const Center(
                child: Text(
                  'G',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D1B14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Created by',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFA8B5A0),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Gapp',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE8D5B5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.language_rounded,
                        size: 14,
                        color: Color(0xFFE8A87C),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'www.gapp.in',
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFFE8A87C).withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFFA8B5A0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2D4A3E),
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
                  color: const Color(0xFF4DB6AC).withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.gavel_rounded,
                  size: 20,
                  color: Color(0xFF4DB6AC),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'MIT License',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE8D5B5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Copyright © 2026 Gapp\n\n'
            'Permission is hereby granted, free of charge, to any person obtaining '
            'a copy of this software and associated documentation files, to deal '
            'in the Software without restriction, including without limitation the '
            'rights to use, copy, modify, merge, publish, distribute, sublicense, '
            'and/or sell copies of the Software.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Color(0xFF8A9A82),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  void _launchUrl(BuildContext context, String url) {
    // Copy to clipboard and show snackbar
    // In a production app, you'd use url_launcher package
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.link_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Link copied: $url',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2D4A3E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../main.dart'; // Ensure rootNavigatorKey is accessible

class PromptService {
  static const String _keyLastPromptMonth = 'last_support_prompt_month';
  static const String _donationUrl = 'https://avizitrx.com/sunrise-signal/donate';

  static const String _shareSubject = 'Sunrise Signal - Men\'s Morning Health Tracker';
  static const String _shareMessage =
      'Track your morning wood, sleep quality, and lifestyle factors privately with Sunrise Signal:\n\nhttps://avizitrx.com/sunrise-signal';

  static Future<void> checkAndShowPrompt(int totalLogs) async {
    debugPrint("Total Logs: $totalLogs");

    // 1. Minimum 5 logs required
    if (totalLogs < 5) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final currentMonthKey = '${now.year}-${now.month}';

    // 2. Only once per calendar month
    final lastPromptMonth = prefs.getString(_keyLastPromptMonth);
    debugPrint("Last Prompt Month: $lastPromptMonth");
    if (lastPromptMonth == currentMonthKey) return;

    // 3. Random chance trigger on save (~35% chance to appear)
    final random = Random();
    if (random.nextDouble() > 0.35) return;

    // Mark current month as prompted so it won't show again this month
    await prefs.setString(_keyLastPromptMonth, currentMonthKey);

    // Show Donation Dialog (with fallback to share if they decline)
    final userChoseNotNow = await _showSupportDialog();
    if (userChoseNotNow == true) {
      await _showShareAlternativeDialog();
    }
  }

  // ---------------------------------------------------------------------------
  // 1. DONATION DIALOG
  // ---------------------------------------------------------------------------
  static Future<bool?> _showSupportDialog() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return Future.value(null);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161F2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(CupertinoIcons.heart_fill, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Support Sunrise Signal',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'Sunrise Signal is completely free, private, and ad-free. If this tracker has helped you better understand your morning vitality, consider supporting its independent development.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Not Now',
                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
              ),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);

                final uri = Uri.parse(_donationUrl);

                try {
                  final launched = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );

                  if (launched) {
                    await _showCopyLinkDialog();
                  }
                } catch (e) {
                  debugPrint('Error launching donation URL: $e');
                  await _showCopyLinkDialog();
                }
              },
              icon: const Icon(CupertinoIcons.gift_fill, size: 16),
              label: const Text('Support Developer'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 2. FALLBACK SHARE DIALOG (Shown when user declines donation)
  // ---------------------------------------------------------------------------
  static Future<void> _showShareAlternativeDialog() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return Future.value();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161F2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'Help Us Grow for Free',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'No worries at all! You can also support the app completely for free by sharing it with friends or on social media.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final box = dialogContext.findRenderObject() as RenderBox?;
                final originRect = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

                Navigator.pop(dialogContext);

                await SharePlus.instance.share(
                  ShareParams(
                    text: _shareMessage,
                    subject: _shareSubject,
                    sharePositionOrigin: originRect,
                  ),
                );
              },
              icon: const Icon(CupertinoIcons.share, size: 16),
              label: const Text('Share to Socials'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _showCopyLinkDialog() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161F2E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Open Donation Page',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'We couldn’t open the donation page automatically. '
          'Copy the link below and paste it into your browser.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: _donationUrl),
              );

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            icon: const Icon(
              CupertinoIcons.doc_on_doc,
              size: 16,
            ),
            label: const Text('Copy Link'),
          ),
        ],
      ),
    );
  }
}

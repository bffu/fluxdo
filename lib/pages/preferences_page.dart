import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/preferences_provider.dart';
import '../utils/comment_keyword_filter.dart';

class PreferencesPage extends ConsumerWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final preferences = ref.watch(preferencesProvider);
    final blockedKeywords = preferences.blockedCommentKeywords;
    final blockedKeywordsPreview =
        blockedKeywords.isEmpty ? 'No keywords' : blockedKeywords.take(4).join(', ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferences'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildSectionHeader(theme, 'General'),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Long press preview'),
                  subtitle: const Text('Long press topic cards to preview quickly'),
                  secondary: Icon(
                    Icons.touch_app_rounded,
                    color: preferences.longPressPreview
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  value: preferences.longPressPreview,
                  onChanged: (value) {
                    ref.read(preferencesProvider.notifier).setLongPressPreview(value);
                  },
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                SwitchListTile(
                  title: const Text('In-app browser for external links'),
                  subtitle: const Text('Open external links inside the app first'),
                  secondary: Icon(
                    Icons.open_in_browser_rounded,
                    color: preferences.openExternalLinksInAppBrowser
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  value: preferences.openExternalLinksInAppBrowser,
                  onChanged: (value) {
                    ref
                        .read(preferencesProvider.notifier)
                        .setOpenExternalLinksInAppBrowser(value);
                  },
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                SwitchListTile(
                  title: const Text('Anonymous share'),
                  subtitle: const Text('Do not attach user identity to shared links'),
                  secondary: Icon(
                    Icons.visibility_off_rounded,
                    color: preferences.anonymousShare
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  value: preferences.anonymousShare,
                  onChanged: (value) {
                    ref.read(preferencesProvider.notifier).setAnonymousShare(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(theme, 'Reading'),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.format_size_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Content font size'),
                            Text(
                              '${(preferences.contentFontScale * 100).round()}%',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: preferences.contentFontScale != 1.0
                            ? () => ref.read(preferencesProvider.notifier).setContentFontScale(1.0)
                            : null,
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: preferences.contentFontScale,
                      min: 0.8,
                      max: 1.4,
                      divisions: 12,
                      label: '${(preferences.contentFontScale * 100).round()}%',
                      onChanged: (value) {
                        ref.read(preferencesProvider.notifier).setContentFontScale(value);
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Small',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'Large',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(theme, 'Comments'),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Threaded comment mode'),
                  subtitle: const Text('Render comments by reply relationship'),
                  secondary: Icon(
                    Icons.account_tree_outlined,
                    color: preferences.threadedCommentMode
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  value: preferences.threadedCommentMode,
                  onChanged: (value) {
                    ref.read(preferencesProvider.notifier).setThreadedCommentMode(value);
                  },
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                ListTile(
                  leading: Icon(
                    Icons.block_outlined,
                    color: blockedKeywords.isNotEmpty
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  title: const Text('Comment keyword blocking'),
                  subtitle: Text(
                    blockedKeywords.isEmpty
                        ? 'Tap to add keywords'
                        : '$blockedKeywordsPreview${blockedKeywords.length > 4 ? '...' : ''} (${blockedKeywords.length})',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _editBlockedKeywords(context, ref, preferences),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(theme, 'Editor'),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              title: const Text('Auto pangu spacing'),
              subtitle: const Text('Auto insert spacing for CJK mixed text'),
              secondary: Icon(
                Icons.auto_fix_high_rounded,
                color: preferences.autoPanguSpacing
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              value: preferences.autoPanguSpacing,
              onChanged: (value) {
                ref.read(preferencesProvider.notifier).setAutoPanguSpacing(value);
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Row(
      children: [
        Icon(Icons.tune, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> _editBlockedKeywords(
    BuildContext context,
    WidgetRef ref,
    AppPreferences preferences,
  ) async {
    final theme = Theme.of(context);
    final controller = TextEditingController(
      text: preferences.blockedCommentKeywords.join('\n'),
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Comment keyword blocking'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Use one keyword per line, or split by comma/semicolon.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                minLines: 6,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Example: spoiler\nad\nflame',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(preferencesProvider.notifier).setBlockedCommentKeywords(const []);
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final keywords = CommentKeywordFilter.parseKeywords(controller.text);
              ref.read(preferencesProvider.notifier).setBlockedCommentKeywords(keywords);
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

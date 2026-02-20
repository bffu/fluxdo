import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../providers/discourse_providers.dart';
import '../services/discourse_cache_manager.dart';
import 'webview_page.dart';
import 'webview_login_page.dart';
import 'appearance_page.dart';
import 'browsing_history_page.dart';
import 'bookmarks_page.dart';
import 'my_topics_page.dart';
import 'my_badges_page.dart';
import 'user_profile_page.dart';
import 'trust_level_requirements_page.dart';
import 'about_page.dart';
import 'network_settings_page/network_settings_page.dart';
import 'preferences_page.dart';
import 'local_favorites_page.dart';
import '../widgets/common/loading_spinner.dart';
import '../widgets/common/loading_dialog.dart';
import '../widgets/common/notification_icon_button.dart';
import '../widgets/common/flair_badge.dart';
import '../widgets/common/smart_avatar.dart';
import '../providers/app_state_refresher.dart';
import 'metaverse_page.dart';
import 'drafts_page.dart';
import '../widgets/ldc_balance_card.dart';
import '../providers/ldc_providers.dart';
import '../utils/number_utils.dart';

/// 涓汉椤甸潰
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late ScrollController _scrollController;
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    // 杩涘叆椤甸潰鍚庨潤榛樺埛鏂扮敤鎴锋暟鎹紙涓嶈Е鍙?loading 鐘舵€侊級
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final current = ref.read(currentUserProvider).value;
        if (current != null) {
          // 浣跨敤 refresh 鍦ㄥ悗鍙版洿鏂版暟鎹紝涓嶄細瑙﹀彂 loading 鐘舵€侊紝閬垮厤 UI 闂儊
          // 蹇界暐杩斿洖鍊硷紝鍥犱负鎴戜滑鍙槸瑙﹀彂鍚庡彴鍒锋柊
          ref.read(currentUserProvider.notifier).refreshSilently().ignore();
          ref.refresh(userSummaryProvider.future).ignore();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    // 褰撴粴鍔ㄨ秴杩囦竴瀹氳窛绂伙紙渚嬪澶村儚鍖哄煙鐨勯珮搴︼級鏃舵樉绀烘爣棰?
    // 澶村儚(72) + padding(澶ф20)
    final show = _scrollController.offset > 80;
    if (show != _showTitle) {
      setState(() {
        _showTitle = show;
      });
    }
  }

  Future<void> _goToLogin() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const WebViewLoginPage()),
    );
    if (result == true && mounted) {
      LoadingDialog.show(context, message: '鍔犺浇鏁版嵁...');

      // 鍒锋柊鎵€鏈夌姸鎬?
      AppStateRefresher.refreshAll(ref);

      // 绛夊緟鍏抽敭鏁版嵁鍔犺浇瀹屾垚
      try {
        await Future.wait([
          ref.read(currentUserProvider.future),
          ref.read(userSummaryProvider.future),
        ]).timeout(const Duration(seconds: 10));
      } catch (_) {
        // 瓒呮椂鎴栭敊璇椂缁х画
      }

      if (mounted) {
        LoadingDialog.hide(context);
      }
    }
  }
  
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('鍙栨秷')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('退出')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      LoadingDialog.show(context, message: '姝ｅ湪閫€鍑?..');

      await ref.read(discourseServiceProvider).logout(callApi: true);
      if (mounted) {
        await AppStateRefresher.resetForLogout(ref);
      }

      if (mounted) {
        LoadingDialog.hide(context);
      }
    }
  }

  Future<void> _openProfileEdit() async {
    final username = ref.read(currentUserProvider).value?.username;
    if (username != null && username.isNotEmpty) {
      await WebViewPage.open(
        context, 
        'https://linux.do/u/$username/preferences/account',
        title: '缂栬緫璧勬枡',
        injectCss: '''
          .new-user-content-wrapper {
            position: fixed !important;
            top: 0 !important;
            left: 0 !important;
            width: 100% !important;
            height: 100% !important;
            z-index: 100 !important;
            background: var(--d-content-background, var(--secondary)) !important;
            overflow-y: auto !important;
            padding: 20px !important;
            box-sizing: border-box !important;
          }
          .d-header {
            display: none !important;
          }
        ''',
      );
      
      // 杩斿洖鍚庨潤榛樺埛鏂版暟鎹?
      if (mounted) {
        ref.read(currentUserProvider.notifier).refreshSilently().ignore();
        ref.refresh(userSummaryProvider.future).ignore();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userState = ref.watch(currentUserProvider);
    final isLoggedIn = userState.value != null;
    final user = userState.value;
    final displayName = user?.name ?? user?.username ?? '';
    
    final isLoadingInitial = userState.isLoading && !userState.hasValue;
    final hasError = userState.hasError && !userState.hasValue;
    final errorMessage = userState.error?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: _showTitle && displayName.isNotEmpty 
            ? GestureDetector(
                onTap: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SmartAvatar(
                      imageUrl: user?.getAvatarUrl(),
                      radius: 14,
                      fallbackText: displayName,
                    ),
                    const SizedBox(width: 8),
                    Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              )
            : null,
        centerTitle: false,
        actions: isLoggedIn ? [
          IconButton(
            icon: const Icon(Icons.manage_accounts_rounded),
            tooltip: '缂栬緫璧勬枡',
            onPressed: _openProfileEdit,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: NotificationIconButton(),
          )
        ] : null,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final current = ref.read(currentUserProvider).value;
          if (current == null) return;
          await ref.read(currentUserProvider.notifier).refreshSilently();
          ref.invalidate(userSummaryProvider);
          final service = ref.read(discourseServiceProvider);
          final user = ref.read(currentUserProvider).value;
          if (user != null) {
            await service.getUserSummary(user.username, forceRefresh: true);
          }
        },
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            const _ProfileHeader(),
            const SizedBox(height: 24),
            
            if (isLoadingInitial)
              const Center(child: Padding(
                padding: EdgeInsets.all(64),
                child: LoadingSpinner(),
              ))
            else if (hasError)
              _buildError(theme, errorMessage)
            else
              Consumer(
                builder: (context, ref, _) {
                  final summary = ref.watch(userSummaryProvider.select((value) => value.value));
                  final loggedIn = ref.watch(
                    currentUserProvider.select((value) => value.value != null),
                  );
                  if (!loggedIn || summary == null) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: [
                      _buildStatsRow(theme, summary),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),

            Consumer(
              builder: (context, ref, _) {
                final ldcUserInfo = ref.watch(ldcUserInfoProvider).value;
                if (ldcUserInfo == null) return const SizedBox.shrink();
                return Column(
                  children: const [
                    LdcBalanceCard(compact: true),
                    SizedBox(height: 24),
                  ],
                );
              },
            ),

            if (isLoggedIn) ...[
              _buildOptionsCard(theme),
              const SizedBox(height: 20),
            ],
            _buildAboutCard(theme),
            const SizedBox(height: 32),
            _buildAuthButton(theme, isLoggedIn),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
  
  Widget _buildError(ThemeData theme, String error) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.errorContainer.withValues(alpha:0.3),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.error.withValues(alpha:0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(child: Text('鍔犺浇澶辫触: $error', style: theme.textTheme.bodySmall)),
            TextButton(
              onPressed: () => ref.invalidate(currentUserProvider), 
              child: const Text('閲嶈瘯')
            ),
          ],
        ),
      ),
    );
  }
  
  /// 绀惧尯琛ㄧ幇 - 浣跨敤 Card 淇濇寔涓€鑷存€?
  Widget _buildStatsRow(ThemeData theme, UserSummary summary) {
    return Card(
      elevation: 0,
       // 浣跨敤 surfaceContainerLow 涓庡叾浠栧垪琛ㄥ崱鐗囧尯鍒嗘垨涓€鑷达紝杩欓噷閫夋嫨绋嶅井绐佸嚭涓€鐐?
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha:0.2)),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildCompactStatItem(theme, NumberUtils.formatCount(summary.daysVisited), '璁块棶澶╂暟', summary.daysVisited),
            _buildVerticalDivider(theme),
            _buildCompactStatItem(theme, NumberUtils.formatCount(summary.postsReadCount), '闃呰甯栧瓙', summary.postsReadCount),
            _buildVerticalDivider(theme),
            _buildCompactStatItem(theme, NumberUtils.formatCount(summary.likesReceived), '鑾峰緱鐐硅禐', summary.likesReceived),
            _buildVerticalDivider(theme),
            _buildCompactStatItem(theme, NumberUtils.formatCount(summary.postCount), '鍙戣〃鍥炲', summary.postCount),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider(ThemeData theme) {
    return Container(
      height: 20,
      width: 1,
      color: theme.colorScheme.outlineVariant.withValues(alpha:0.5),
    );
  }

  Widget _buildCompactStatItem(ThemeData theme, String value, String label, int rawValue) {
    return Tooltip(
      message: '$rawValue',
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            )
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            )
          ),
        ],
      ),
    );
  }
  
  Widget _buildOptionsCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha:0.2)),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildOptionTile(
            icon: Icons.bookmark_rounded,
            iconColor: Colors.orange,
            title: '鎴戠殑涔︾',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookmarksPage()))
          ),
          _buildOptionTile(
            icon: Icons.drafts_rounded,
            iconColor: Colors.teal,
            title: '鎴戠殑鑽夌',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DraftsPage()))
          ),
          _buildOptionTile(
            icon: Icons.article_rounded, 
            iconColor: Colors.blue,
            title: '鎴戠殑璇濋', 
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTopicsPage()))
          ),
          _buildOptionTile(
            icon: Icons.military_tech_rounded, 
            iconColor: Colors.amber[700]!,
            title: '鎴戠殑寰界珷', 
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBadgesPage()))
          ),
          _buildOptionTile(
            icon: Icons.verified_user_rounded, 
            iconColor: Colors.green,
            title: '淇′换瑕佹眰', 
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrustLevelRequirementsPage()))
          ),
          _buildOptionTile(
            icon: Icons.history_rounded,
            iconColor: Colors.purple,
            title: '娴忚鍘嗗彶',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BrowsingHistoryPage()))
          ),
          _buildOptionTile(
            icon: Icons.explore_rounded,
            iconColor: Colors.deepOrange,
            title: '元宇宙',
            showDivider: false,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MetaversePage()))
          ),
        ],
      ),
    );
  }
  
  Widget _buildAboutCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha:0.2)),
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildOptionTile(
            icon: Icons.favorite_rounded,
            iconColor: Colors.red,
            title: '本地收藏夹',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalFavoritesPage())),
          ),
          _buildOptionTile(
            icon: Icons.color_lens_rounded, 
            iconColor: Colors.teal,
            title: '澶栬璁剧疆', 
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppearancePage()))
          ),
          _buildOptionTile(
            icon: Icons.network_check_rounded,
            iconColor: Colors.blueGrey,
            title: '缃戠粶璁剧疆',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NetworkSettingsPage())),
          ),
          _buildOptionTile(
            icon: Icons.tune_rounded,
            iconColor: Colors.deepPurple,
            title: '鍋忓ソ璁剧疆',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PreferencesPage())),
          ),
          _buildOptionTile(
            icon: Icons.info_rounded,
            iconColor: Colors.indigo,
            title: '鍏充簬 FluxDO',
            showDivider: false,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage())),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOptionTile({
    required IconData icon, 
    Color? iconColor,
    required String title, 
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    final theme = Theme.of(context);
    final finalIconColor = iconColor ?? theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  // iOS 椋庢牸鐨勫浘鏍囧鍣ㄤ繚鐣欙紝鍥犱负杩欎笉杩濆拰涓斿ソ鐪?
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: finalIconColor.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: finalIconColor, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title, 
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w500
                      )
                    )
                  ),
                  Icon(
                    Icons.chevron_right_rounded, 
                    color: theme.colorScheme.outline.withValues(alpha:0.4), 
                    size: 20
                  ),
                ],
              ),
            ),
            if (showDivider)
              Padding(
                padding: const EdgeInsets.only(left: 60), // 瀵归綈鏂囧瓧
                child: Divider(
                  height: 1, 
                  thickness: 0.5,
                  color: theme.colorScheme.outlineVariant.withValues(alpha:0.2)
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAuthButton(ThemeData theme, bool isLoggedIn) {
    if (isLoggedIn) {
      return Center(
        child: TextButton.icon(
          onPressed: _logout,
          icon: Icon(Icons.logout_rounded, size: 18, color: theme.colorScheme.error.withValues(alpha:0.8)),
          label: Text('退出当前账号', style: TextStyle(color: theme.colorScheme.error.withValues(alpha:0.8), fontWeight: FontWeight.w600)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            backgroundColor: theme.colorScheme.errorContainer.withValues(alpha:0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: FilledButton.icon(
          onPressed: _goToLogin,
          icon: const Icon(Icons.login_rounded, size: 20),
          label: const Text('鐧诲綍 Linux.do', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
    }
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserProvider.select((value) => value.value?.id));
    final username = ref.watch(currentUserProvider.select((value) => value.value?.username));
    final isLoggedIn = ref.watch(currentUserProvider.select((value) => value.value != null));
    final canNavigate = username != null && username.isNotEmpty;

    return GestureDetector(
      onTap: canNavigate
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UserProfilePage(username: username)),
              );
            }
          : null,
      child: Container(
        color: Colors.transparent,
        child: Row(
          children: [
            _ProfileAvatarSection(userId: userId, isLoggedIn: isLoggedIn),
            const SizedBox(width: 20),
            const Expanded(child: _ProfileInfoSection()),
            if (isLoggedIn)
              CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatarSection extends ConsumerWidget {
  final int? userId;
  final bool isLoggedIn;

  const _ProfileAvatarSection({
    required this.userId,
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarUrl = ref.watch(
      currentUserProvider.select((value) => value.value?.getAvatarUrl() ?? ''),
    );
    final flairUrl = ref.watch(currentUserProvider.select((value) => value.value?.flairUrl));
    final flairName = ref.watch(currentUserProvider.select((value) => value.value?.flairName));
    final flairBgColor = ref.watch(currentUserProvider.select((value) => value.value?.flairBgColor));
    final flairColor = ref.watch(currentUserProvider.select((value) => value.value?.flairColor));

    return _ProfileAvatar(
      key: ValueKey('profile-avatar-$userId'),
      userId: userId,
      avatarUrl: avatarUrl,
      isLoggedIn: isLoggedIn,
      flairUrl: flairUrl,
      flairName: flairName,
      flairBgColor: flairBgColor,
      flairColor: flairColor,
    );
  }
}

class _ProfileInfoSection extends ConsumerWidget {
  const _ProfileInfoSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final name = ref.watch(currentUserProvider.select((value) => value.value?.name));
    final username = ref.watch(currentUserProvider.select((value) => value.value?.username));
    final trustLevel = ref.watch(currentUserProvider.select((value) => value.value?.trustLevel));
    final status = ref.watch(currentUserProvider.select((value) => value.value?.status));
    final isLoggedIn = ref.watch(currentUserProvider.select((value) => value.value != null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name ?? username ?? (isLoggedIn ? '加载中...' : '未登录'),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (isLoggedIn) ...[
          const SizedBox(height: 4),
          Text(
            '@${username ?? ''}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getTrustLevelLabel(trustLevel ?? 0),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (status != null) _buildStatusChip(status, theme),
            ],
          ),
        ] else ...[
          const SizedBox(height: 4),
          Text(
            '登录后体验更多功能',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// 鐙珛鐨勫ご鍍忕粍浠讹紝浣跨敤 AutomaticKeepAliveClientMixin 閬垮厤閲嶅缓
class _ProfileAvatar extends StatefulWidget {
  final int? userId;
  final String avatarUrl;
  final bool isLoggedIn;
  final String? flairUrl;
  final String? flairName;
  final String? flairBgColor;
  final String? flairColor;

  const _ProfileAvatar({
    super.key,
    required this.userId,
    required this.avatarUrl,
    required this.isLoggedIn,
    this.flairUrl,
    this.flairName,
    this.flairBgColor,
    this.flairColor,
  });

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> with AutomaticKeepAliveClientMixin {
  Widget? _cachedAvatarWithFlair;
  String _cachedSignature = '';

  @override
  bool get wantKeepAlive => true;

  String _buildCacheSignature() {
    return '${widget.avatarUrl}_${widget.flairUrl}_${widget.flairName}_${widget.flairBgColor}_${widget.flairColor}';
  }

  @override
  void didUpdateWidget(_ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newSignature = _buildCacheSignature();
    if (newSignature != _cachedSignature) {
      _cachedAvatarWithFlair = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 蹇呴』璋冪敤浠ユ敮鎸?AutomaticKeepAliveClientMixin

    final signature = _buildCacheSignature();
    if (_cachedAvatarWithFlair != null && signature == _cachedSignature) {
      return _cachedAvatarWithFlair!;
    }
    _cachedSignature = signature;

    final theme = Theme.of(context);

    _cachedAvatarWithFlair = AvatarWithFlair(
      key: ValueKey('profile-avatar-flair-${widget.userId}-${widget.flairUrl}'),
      flairSize: 24,
      flairRight: -2,
      flairBottom: -2,
      flairUrl: widget.flairUrl,
      flairName: widget.flairName,
      flairBgColor: widget.flairBgColor,
      flairColor: widget.flairColor,
      avatar: SmartAvatar(
        imageUrl: widget.avatarUrl.isNotEmpty ? widget.avatarUrl : null,
        radius: 36,
        fallbackText: widget.isLoggedIn ? null : '',
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: theme.colorScheme.surfaceContainerHighest,
          width: 1,
        ),
      ),
    );

    return _cachedAvatarWithFlair!;
  }
}

String _getTrustLevelLabel(int level) {
  switch (level) {
    case 0:
      return 'L0 鏂?user';
    case 1:
      return 'L1 鍩烘湰鐢ㄦ埛';
    case 2:
      return 'L2 鎴愬憳';
    case 3:
      return 'L3 娲昏穬鐢ㄦ埛';
    case 4:
      return 'L4 棰嗚';
    default:
      return 'L$level';
  }
}

Widget _buildStatusEmoji(UserStatus status) {
  final emoji = status.emoji;
  if (emoji == null || emoji.isEmpty) return const SizedBox.shrink();

  final isEmojiName =
      emoji.contains(RegExp(r'[a-zA-Z0-9_]')) && !emoji.contains(RegExp(r'[^\x00-\x7F]'));

  if (isEmojiName) {
    final cleanName = emoji.replaceAll(':', '');
    final emojiUrl = 'https://linux.do/images/emoji/twitter/$cleanName.png?v=12';

    return Image(
      image: discourseImageProvider(emojiUrl),
      width: 14,
      height: 14,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  return Text(
    emoji,
    style: const TextStyle(fontSize: 12, height: 1.2),
  );
}

Widget _buildStatusChip(UserStatus status, ThemeData theme) {
  final emoji = status.emoji;
  final description = status.description;

  if ((emoji == null || emoji.isEmpty) && (description == null || description.isEmpty)) {
    return const SizedBox.shrink();
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.5),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha:0.5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (emoji != null && emoji.isNotEmpty) ...[
          _buildStatusEmoji(status),
          if (description != null && description.isNotEmpty) const SizedBox(width: 4),
        ],
        if (description != null && description.isNotEmpty)
          Flexible(
            child: Text(
              description,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    ),
  );
}


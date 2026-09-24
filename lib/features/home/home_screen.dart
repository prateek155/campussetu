import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/models/post_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/bento_grid.dart';
import '../../core/router/app_router.dart';
import 'widgets/post_card.dart';
import 'package:campussetu/features/home/help_chat_widget.dart';
import 'widgets/create_post_sheet.dart';
import '../ambassador/services/campus_ambassador_service.dart';

final homeCountsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ApiService().get('/users/home-counts');
  return Map<String, dynamic>.from(res as Map);
});


class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Map<String, PostModel> _likeOverrides = {};
  final Set<String> _liking = {};
  bool _dismissedAmbassadorBanner = false;

  Future<void> _refresh() async {
    _likeOverrides.clear();
    _liking.clear();
    ref.invalidate(currentUserProvider);
    ref.invalidate(feedProvider);
  }

  Future<void> _ensureToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) ApiService().setToken(token);
    }
  }

  Future<void> _toggleLike(PostModel post) async {
    if (_liking.contains(post.id)) return;
    final base = _likeOverrides[post.id] ?? post;
    final wantLiked = !base.isLiked;
    setState(() {
      _liking.add(post.id);
      _likeOverrides[post.id] = base.copyWith(
        isLiked: wantLiked,
        likesCount: base.likesCount + (wantLiked ? 1 : -1),
      );
    });
    try {
      await _ensureToken();
      final res = await ApiService().toggleLike(post.id);
      if (!mounted) return;
      setState(() {
        final cur = _likeOverrides[post.id] ?? base;
        int? count;
        final raw = res['likes_count'] ?? res['likesCount'];
        if (raw is int) count = raw;
        if (raw is String) count = int.tryParse(raw);
        _likeOverrides[post.id] = cur.copyWith(
          isLiked: res['liked'] == true,
          likesCount: count ?? cur.likesCount,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _likeOverrides.remove(post.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_apiError(e, 'Like failed')), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _liking.remove(post.id));
    }
  }

  void _bumpComments(String postId) {
    final feed = ref.read(feedProvider).value;
    if (feed == null) return;
    PostModel? found;
    for (final p in feed) {
      if (p.id == postId) { found = p; break; }
    }
    if (found == null) return;
    final base = _likeOverrides[postId] ?? found;
    setState(() => _likeOverrides[postId] = base.copyWith(commentsCount: base.commentsCount + 1));
  }

  Future<void> _openComments(PostModel post) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(postId: post.id, onCommented: () => _bumpComments(post.id)),
    );
    await _ensureToken();
    try {
      final res = await ApiService().getFeed(page: 1, limit: 20);
      final List list = (res['data'] as List?) ?? [];
      for (final e in list) {
        final m = Map<String, dynamic>.from(e as Map);
        if (m['id'].toString() == post.id) {
          m['author'] = m['author'] is Map ? Map<String, dynamic>.from(m['author'] as Map) : <String, dynamic>{};
          if ((m['author'] as Map).isEmpty && m['author_id'] != null) (m['author'] as Map)['id'] = m['author_id'];
          m['likes_count'] = m['likes_count'] ?? m['likesCount'] ?? 0;
          m['comments_count'] = m['comments_count'] ?? m['commentsCount'] ?? 0;
          m['is_liked'] = m['is_liked'] ?? m['isLiked'] ?? false;
          m['image_url'] = m['image_url'] ?? m['imageUrl'];
          final fresh = PostModel.fromJson(m);
          if (!mounted) return;
          setState(() {
            final ov = _likeOverrides[post.id];
            _likeOverrides[post.id] = fresh.copyWith(isLiked: ov?.isLiked ?? fresh.isLiked, likesCount: ov?.likesCount ?? fresh.likesCount);
          });
          break;
        }
      }
    } catch (_) {}
  }

  String _apiError(Object e, String fallback) {
    try {
      final d = (e as dynamic)?.response?.data;
      if (d is Map && d['error'] != null) return d['error'].toString();
    } catch (_) {}
    final s = e.toString();
    if (s.contains('404')) return 'Post not found';
    return '$fallback: ${s.length > 100 ? s.substring(0, 100) : s}';
  }

  Future<void> _sharePost(PostModel post) async {
    try {
      await Share.share(post.content, subject: 'CampusSetu Post');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final feedAsync = ref.watch(feedProvider);
    final countsAsync = ref.watch(homeCountsProvider);
    final counts = countsAsync.valueOrNull ?? {};
    final isAmbassadorOpen = ref.watch(ambassadorProgramStatusProvider).value ?? true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton(
          onPressed: () => HelpChatWidget.show(context),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          tooltip: 'Help & Support',
          child: const Icon(Icons.help_outline),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: AppColors.bg,
              toolbarHeight: 64,
              flexibleSpace: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('CampusSetu', style: AppTypography.caveatBrand(size: 28, color: AppColors.ink)),
                      const Spacer(),
                      NeuCard(
                        padding: const EdgeInsets.all(10),
                        onTap: () => context.push(AppRoutes.notifications),
                        child: Icon(Icons.notifications_outlined, size: 22, color: AppColors.ink),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.profile),
                        child: userAsync.when(
                          data: (u) => UserAvatar(name: u.name, size: 38, showNeuBorder: true, isVerified: u.isVerified, imageUrl: u.photoUrl),
                          loading: () => const UserAvatar(name: '?', size: 38, showNeuBorder: true),
                          error: (_, __) => const UserAvatar(name: '?', size: 38, showNeuBorder: true),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: userAsync.when(
                      data: (u) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Namaste, ${u.name.split(' ').first}! 👋', style: AppTypography.caveatWarm(size: 22, color: AppColors.inkSoft)),
                          Text("What's happening today?", style: AppTypography.soraHeading2()),
                        ],
                      ),
                      loading: () => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Namaste! 👋', style: AppTypography.caveatWarm(size: 22, color: AppColors.inkSoft)),
                          Text("What's happening today?", style: AppTypography.soraHeading2()),
                        ],
                      ),
                      error: (_, __) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Namaste! 👋', style: AppTypography.caveatWarm(size: 22, color: AppColors.inkSoft)),
                          Text("What's happening today?", style: AppTypography.soraHeading2()),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Feed', style: AppTypography.soraHeading3()),
                        NeuCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          onTap: () async {
                            final created = await showModalBottomSheet<bool>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const CreatePostSheet(),
                            );
                            if (created == true) ref.invalidate(feedProvider);
                          },
                          child: Row(children: [
                            const Icon(Icons.add_rounded, size: 18, color: AppColors.cyanDeep),
                            const SizedBox(width: 6),
                            Text('Post', style: AppTypography.interLabel(color: AppColors.cyanDeep)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: BentoGrid(
                      rowHeight: 88,
                      gap: 10,
                      tiles: [
                        BentoTile(id: 'tools', kind: BentoKind.wide, w: 2, h: 1, icon: Icons.auto_fix_high_rounded, color: const Color(0xFF0284C7), title: 'Tools', subtitle: 'PDF & image utilities', onTap: () => context.push(AppRoutes.tools)),
                        BentoTile(id: 'learning', kind: BentoKind.wide, w: 2, h: 1, icon: Icons.quiz_rounded, color: const Color(0xFF7C3AED), title: 'Learning', subtitle: 'Live quizzes & tests', count: (counts['live_quizzes'] ?? 0).toString(), onTap: () => context.push('/quiz')),
                        BentoTile(id: 'travel', kind: BentoKind.small, w: 1, h: 1, icon: Icons.directions_car_rounded, color: const Color(0xFF0D9488), title: 'Travel', count: (counts['travels'] ?? 0).toString(), onTap: () => context.push('/travel')),
                        BentoTile(id: 'events', kind: BentoKind.small, w: 1, h: 1, icon: Icons.event_rounded, color: const Color(0xFF4F46E5), title: 'Events', count: (counts['events'] ?? 0).toString(), onTap: () => context.push('/events')),
                        BentoTile(id: 'helping', kind: BentoKind.small, w: 1, h: 1, icon: Icons.handshake_outlined, color: const Color(0xFFEA580C), title: 'Helping', count: (counts['tasks'] ?? 0).toString(), onTap: () => context.push(AppRoutes.helping)),
                        BentoTile(id: 'deals', kind: BentoKind.small, w: 1, h: 1, icon: Icons.local_offer_outlined, color: const Color(0xFF16A34A), title: 'Deals', count: (counts['deals'] ?? 0).toString(), onTap: () => context.push(AppRoutes.deals)),
                        BentoTile(id: 'flatmates', kind: BentoKind.wide, w: 2, h: 1, icon: Icons.home_work_outlined, color: const Color(0xFFE11D48), title: 'Flatmates', subtitle: 'Find rooms and roommates', count: (counts['flatmates'] ?? 0).toString(), onTap: () => context.push(AppRoutes.flatmates)),
                        if (isAmbassadorOpen) BentoTile(id: 'ambassador', kind: BentoKind.wide, w: 2, h: 1, icon: Icons.campaign_rounded, color: const Color(0xFFF59E0B), title: 'Campus Ambassador', subtitle: 'Lead your campus', badge: 'APPLY', onTap: () => context.push(AppRoutes.ambassador)),
                      ],
                    ),
                  ),
                  if (isAmbassadorOpen && !_dismissedAmbassadorBanner)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 8),
                      child: _buildAmbassadorPromoBanner(context, isDark: isDark),
                    ),
                ],
              ),
            ),
            feedAsync.when(
              data: (posts) {
                if (posts.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: NeuCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(children: [
                          Icon(Icons.feed_outlined, size: 40, color: AppColors.inkSoft),
                          const SizedBox(height: 12),
                          Text('No posts yet', style: AppTypography.soraHeading3()),
                          const SizedBox(height: 6),
                          Text('Be the first to share something!', style: AppTypography.interBody(color: AppColors.inkSoft)),
                        ]),
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final display = _likeOverrides[posts[index].id] ?? posts[index];
                      return PostCard(
                      post: display,
                      onLike: () => _toggleLike(display),
                      onComment: () => _openComments(display),
                      onShare: () => _sharePost(display),
                      onReport: () async {
                        try {
                          await _ensureToken();
                          await ApiService().submitReport({'target_type': 'post', 'target_id': posts[index].id, 'reason': 'reported'});
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reported')));
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                        }
                      },
                    ).animate(delay: (index * 80).ms).fadeIn(duration: 400.ms).slideY(begin: 0.1);
                    },
                    childCount: posts.length,
                  ),
                );
              },
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate((_, __) => _PostShimmer(), childCount: 3),
              ),
              error: (e, _) => SliverToBoxAdapter(child: _ErrorCard(msg: e.toString(), onRetry: () => ref.invalidate(feedProvider))),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbassadorPromoBanner(BuildContext context, {required bool isDark}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2E2008), const Color(0xFF1B1304)]
              : [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'CAMPUS AMBASSADOR 2026',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _dismissedAmbassadorBanner = true),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: isDark ? Colors.white60 : Colors.black45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Lead Your Campus, Earn Perks & Grow 🚀',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Represent CampusSetu in your university. Get Certificate, Stipends, Goodies & Direct Mentorship.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _perkChip('🏆 Certificate', isDark),
                    _perkChip('💰 Stipend & Swag', isDark),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => context.push(AppRoutes.ambassador),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Apply Now'),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _perkChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorCard({required this.msg, required this.onRetry});
  @override
  Widget build(BuildContext context) => NeuCard(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text('Failed to load', style: AppTypography.interBody(color: AppColors.error)),
          const SizedBox(height: 4),
          Text(msg, style: AppTypography.interCaption(), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          GestureDetector(onTap: onRetry, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: AppColors.cyanDeep, borderRadius: BorderRadius.circular(8)), child: Text('Retry', style: AppTypography.interLabel(color: Colors.white)))),
        ]),
      );
}

class _PostShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: NeuCard(padding: const EdgeInsets.all(16), child: Column(children: [Container(height: 14, color: AppColors.shadowDark.withValues(alpha: 0.3)), const SizedBox(height: 8), Container(height: 14, color: AppColors.shadowDark.withValues(alpha: 0.2)), const SizedBox(height: 12), Container(height: 80, decoration: BoxDecoration(color: AppColors.shadowDark.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)))])),
      );
}

class _CommentsSheet extends StatefulWidget {
  final String postId;
  final VoidCallback onCommented;
  const _CommentsSheet({required this.postId, required this.onCommented});
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();
  List<CommentModel> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _ensureToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) ApiService().setToken(token);
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      await _ensureToken();
      final list = await ApiService().getComments(widget.postId);
      final parsed = <CommentModel>[];
      for (final e in list) {
        try {
          final m = Map<String, dynamic>.from(e as Map);
          final author = m['author'] is Map ? Map<String, dynamic>.from(m['author'] as Map) : <String, dynamic>{};
          m['author'] = author;
          parsed.add(CommentModel.fromJson(m));
        } catch (_) {}
      }
      if (mounted) setState(() => _comments = parsed);
    } catch (e) {
      if (mounted) {
        String msg = 'Comments load nahi hue';
        try {
          final d = (e as dynamic)?.response?.data;
          if (d is Map && d['error'] != null) msg = d['error'].toString();
        } catch (_) {}
        setState(() => _loadError = msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _ensureToken();
      final res = await ApiService().addComment(widget.postId, text);
      _ctrl.clear();
      widget.onCommented();
      bool prepended = false;
      try {
        final m = Map<String, dynamic>.from(res);
        if (m['author'] is! Map) m['author'] = <String, dynamic>{};
        final c = CommentModel.fromJson(m);
        if (mounted) setState(() => _comments.insert(0, c));
        prepended = true;
      } catch (_) {}
      if (!prepended) await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment added ✓'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_serverError(e)), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _serverError(Object e) {
    try {
      final resp = (e as dynamic)?.response;
      final code = resp?.statusCode;
      final d = resp?.data;
      if (d is Map && d['error'] != null) return code != null ? '[$code] ${d['error']}' : d['error'].toString();
      if (code != null) return 'Server error [$code]. Retry karo.';
    } catch (_) {}
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('connection')) return 'Network issue. Internet check karo.';
    if (s.contains('Timeout')) return 'Server slow hai. Retry karo.';
    return s.length > 120 ? s.substring(0, 120) : s;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom + 76),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(28), boxShadow: AppColors.neuRaisedShadows),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16, left: 16, right: 16, top: 16),
        child: Column(children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.shadowDark, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text('Comments', style: AppTypography.soraHeading3()),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _loadError != null && _comments.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 32), const SizedBox(height: 8), Text(_loadError!, style: AppTypography.interBody(color: AppColors.error, size: 13), textAlign: TextAlign.center), const SizedBox(height: 10), GestureDetector(onTap: _load, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: AppColors.cyanDeep, borderRadius: BorderRadius.circular(10)), child: Text('Retry', style: AppTypography.interLabel(color: Colors.white))))]))
                    : _comments.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.chat_bubble_outline, color: AppColors.inkSoft, size: 32), const SizedBox(height: 8), Text('No comments yet', style: AppTypography.interBody(color: AppColors.inkSoft)), Text('Be the first to comment!', style: AppTypography.interCaption())]))
                    : ListView.separated(
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.shadowDark),
                        itemBuilder: (_, i) {
                          final c = _comments[i];
                          return ListTile(
                            leading: CircleAvatar(backgroundColor: AppColors.cyanDeep.withValues(alpha: 0.15), child: Text(c.author.name.isNotEmpty ? c.author.name[0].toUpperCase() : '?', style: AppTypography.interButton(color: AppColors.cyanDeep))),
                            title: Text(c.author.name, style: AppTypography.interButton(size: 13)),
                            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c.content, style: AppTypography.interBody(size: 13)), const SizedBox(height: 2), Text(timeago.format(c.createdAt, locale: 'en_short'), style: AppTypography.monoTimestamp())]),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _ctrl, decoration: InputDecoration(hintText: 'Add a comment...', hintStyle: AppTypography.interBody(color: AppColors.inkSoft), filled: true, fillColor: AppColors.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)), maxLength: 500, buildCounter: (_, {required currentLength, required isFocused, maxLength}) => const SizedBox.shrink())),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(width: 44, height: 44, decoration: BoxDecoration(gradient: AppColors.cyanGradient, borderRadius: BorderRadius.circular(12)), child: _sending ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, color: Colors.white, size: 18)),
            ),
          ]),
        ]),
      ),
    );
  }
}

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/bento_grid.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_chip.dart';
import '../../core/widgets/neu_dropdown.dart';
import '../../core/widgets/neu_text_field.dart';
import '../../core/widgets/premium_badge.dart';
import '../../core/widgets/ring_progress.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/router/app_router.dart';
import 'widgets/campus_id_card.dart';

class ProfileScreen extends ConsumerWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  static const _heroColor = Color(0xFF0E7490);

  void _openEdit(BuildContext context, WidgetRef ref, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(user: user, onSaved: () {
        ref.invalidate(profileProvider(userId));
        ref.invalidate(currentUserProvider);
      }),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SettingsSheet(),
    );
  }

  String _join(List<String?> parts, [String sep = ' · ']) =>
      parts.where((p) => p != null && p.trim().isNotEmpty).map((p) => p!.trim()).join(sep);

  // ── Bento block 1: hero + points + stats ─────────────────────────────
  List<BentoTile> _topTiles(BuildContext context, WidgetRef ref, UserModel user, bool isOwn) {
    final courseLine = _join([user.course, user.branch]);
    final collegeLine = _join([user.college, user.yearOfStudy != null ? 'Year ${user.yearOfStudy}' : null]);
    final locLine = _join([user.city, user.state], ', ');

    return [
      BentoTile(
        id: 'hero',
        kind: BentoKind.custom,
        w: 4,
        h: 2,
        color: _heroColor,
        fill: _heroColor,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: isOwn ? () => _openEdit(context, ref, user) : null,
                    child: Stack(alignment: Alignment.bottomRight, children: [
                      EnergyRing(
                        progress: user.profileCompletionScore,
                        size: 86,
                        centerChild: UserAvatar(name: user.name, imageUrl: user.photoUrl, size: 64, isVerified: user.isVerified),
                      ),
                      if (isOwn)
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: _heroColor, width: 2)),
                          child: const Icon(Icons.camera_alt_rounded, size: 12, color: _heroColor),
                        ),
                    ]),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          Flexible(
                            child: Text(
                              user.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.soraDisplay(size: 20, weight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                          if (user.isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, color: Colors.white, size: 17),
                          ],
                          if (user.isPremium) ...[
                            const SizedBox(width: 6),
                            const PremiumBadge(isSmall: true),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        if (courseLine.isNotEmpty)
                          Text(courseLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.interBody(size: 12.5, color: Colors.white.withValues(alpha: 0.92))),
                        if (collegeLine.isNotEmpty)
                          Text(collegeLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.interBody(size: 12, color: Colors.white.withValues(alpha: 0.8))),
                        if (locLine.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(children: [
                              Icon(Icons.location_on_outlined, size: 13, color: Colors.white.withValues(alpha: 0.8)),
                              const SizedBox(width: 4),
                              Expanded(child: Text(locLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.interBody(size: 11.5, color: Colors.white.withValues(alpha: 0.8)))),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (isOwn)
                GestureDetector(
                  onTap: () => _openEdit(context, ref, user),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.edit_outlined, size: 15, color: _heroColor),
                      const SizedBox(width: 6),
                      Text('Edit profile', style: AppTypography.interBody(size: 13, weight: FontWeight.w700, color: _heroColor)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
      BentoTile(
        id: 'points',
        kind: BentoKind.feature,
        w: 2,
        h: 2,
        icon: Icons.emoji_events_rounded,
        color: AppColors.gold,
        title: 'Points',
        subtitle: 'Earn with Helping Hand',
        count: '${user.points}',
        bigLabel: 'points',
        onTap: isOwn ? () => context.push(AppRoutes.helping) : null,
      ),
      BentoTile(
        id: 'connections',
        kind: BentoKind.wide,
        w: 2,
        h: 1,
        icon: Icons.people_rounded,
        color: const Color(0xFF4A3FE0),
        title: 'Connections',
        subtitle: 'Your network',
        count: '${user.connectionsCount}',
        onTap: isOwn ? () => context.push(AppRoutes.connections) : null,
      ),
      BentoTile(
        id: 'projects',
        kind: BentoKind.wide,
        w: 2,
        h: 1,
        icon: Icons.folder_special_rounded,
        color: const Color(0xFF0B8A7E),
        title: 'Projects',
        subtitle: 'Built so far',
        count: '${user.projectsCount}',
      ),
    ];
  }

  // ── Bento block 2: shortcuts ─────────────────────────────────────────
  List<BentoTile> _actionTiles(BuildContext context, UserModel user, bool isOwn) {
    return [
      BentoTile(
        id: 'tshare',
        kind: BentoKind.dark,
        w: 4,
        h: 1,
        icon: Icons.share_outlined,
        color: AppColors.cyan,
        title: 'Tshare Profile',
        subtitle: 'Share or retrieve code',
        onTap: () => context.go(AppRoutes.tshare),
      ),
      BentoTile(
        id: 'resume',
        kind: BentoKind.wide,
        w: 2,
        h: 1,
        icon: Icons.article_outlined,
        color: const Color(0xFFD9560B),
        title: 'Resume',
        subtitle: 'Build & export',
        onTap: () => context.push(AppRoutes.resume),
      ),
      BentoTile(
        id: 'settings',
        kind: BentoKind.wide,
        w: 2,
        h: 1,
        icon: Icons.settings_outlined,
        color: const Color(0xFF1F5FD8),
        title: 'Settings',
        subtitle: 'Account & privacy',
        onTap: () => _openSettings(context),
      ),
      if (isOwn && user.isAdmin) ...[
        BentoTile(
          id: 'admin_deal',
          kind: BentoKind.wide,
          w: 2,
          h: 1,
          icon: Icons.local_offer,
          color: AppColors.gold,
          title: 'Add Deal',
          subtitle: 'Admin',
          onTap: () => context.push('/admin/add-deal'),
        ),
        BentoTile(
          id: 'admin_event',
          kind: BentoKind.wide,
          w: 2,
          h: 1,
          icon: Icons.event,
          color: Colors.indigo,
          title: 'Add Event',
          subtitle: 'Admin',
          onTap: () => context.push('/admin/add-event'),
        ),
      ],
      if (isOwn)
        BentoTile(
          id: 'signout',
          kind: BentoKind.wide,
          w: 4,
          h: 1,
          icon: Icons.logout_rounded,
          color: AppColors.error,
          title: 'Sign Out',
          subtitle: 'Log out of this device',
          onTap: () async {
            await AuthService().signOut();
            if (context.mounted) context.go(AppRoutes.welcome);
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUser = ref.watch(profileProvider(userId));
    final isOwn = userId == null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: asyncUser.when(
        data: (user) => CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: AppColors.bg,
            toolbarHeight: 64,
            titleSpacing: 20,
            title: Text('Profile', style: AppTypography.soraHeading2()),
            actions: [
              if (isOwn)
                NeuCard(
                  margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
                  padding: const EdgeInsets.all(8),
                  onTap: () => _openEdit(context, ref, user),
                  child: Icon(Icons.edit_outlined, size: 18, color: AppColors.ink),
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                BentoGrid(tiles: _topTiles(context, ref, user, isOwn)).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
                const SizedBox(height: 16),
                CampusIdCard(user: user, isOwn: isOwn).animate(delay: 80.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 16),
                if (user.bio != null && user.bio!.isNotEmpty)
                  _InfoTile(
                    title: 'About',
                    child: Text(user.bio!, style: AppTypography.interBody(height: 1.6)),
                  ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
                if (user.skills.isNotEmpty)
                  _InfoTile(
                    title: 'Skills',
                    child: Wrap(spacing: 8, runSpacing: 8, children: user.skills.map((s) => NeuChip(label: s)).toList()),
                  ).animate(delay: 150.ms).fadeIn(duration: 400.ms),
                BentoGrid(tiles: _actionTiles(context, user, isOwn)).animate(delay: 200.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ]),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Failed to load profile', style: AppTypography.interBody(color: AppColors.error)), Text(e.toString(), style: AppTypography.interCaption(), textAlign: TextAlign.center), const SizedBox(height: 16), GestureDetector(onTap: () => ref.invalidate(profileProvider(userId)), child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(gradient: AppColors.cyanGradient, borderRadius: BorderRadius.circular(12)), child: Text('Retry', style: AppTypography.interButton(color: Colors.white))))]))),
      ),
    );
  }
}

/// Section card that matches the bento tiles (used for About and Skills).
class _InfoTile extends StatelessWidget {
  final String title;
  final Widget child;
  const _InfoTile({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.inkMuted.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.soraSubtitle()),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final UserModel user;
  final VoidCallback onSaved;
  const _EditProfileSheet({required this.user, required this.onSaved});
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _name, _college, _city, _course, _branch, _bio, _skillInput;
  String? _state;
  int? _year;
  List<String> _skills = [];
  bool _loading = false;
  File? _photoFile;
  String? _photoUrl;

  static const _states = ['Andhra Pradesh','Arunachal Pradesh','Assam','Bihar','Chhattisgarh','Goa','Gujarat','Haryana','Himachal Pradesh','Jharkhand','Karnataka','Kerala','Madhya Pradesh','Maharashtra','Manipur','Meghalaya','Mizoram','Nagaland','Odisha','Punjab','Rajasthan','Sikkim','Tamil Nadu','Telangana','Tripura','Uttar Pradesh','Uttarakhand','West Bengal','Delhi','Jammu & Kashmir','Ladakh'];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _college = TextEditingController(text: widget.user.college ?? '');
    _city = TextEditingController(text: widget.user.city ?? '');
    _course = TextEditingController(text: widget.user.course ?? '');
    _branch = TextEditingController(text: widget.user.branch ?? '');
    _bio = TextEditingController(text: widget.user.bio ?? '');
    _skillInput = TextEditingController();
    _state = widget.user.state;
    _year = widget.user.yearOfStudy;
    _skills = List.from(widget.user.skills);
    _photoUrl = widget.user.photoUrl;
  }

  @override
  void dispose() {
    _name.dispose(); _college.dispose(); _city.dispose(); _course.dispose(); _branch.dispose(); _bio.dispose(); _skillInput.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 800);
      if (picked != null) setState(() => _photoFile = File(picked.path));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pick failed: $e')));
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name required'))); return; }
    setState(() => _loading = true);
    try {
      final uid = AuthService().currentUser?.uid ?? widget.user.firebaseUid;
      final token = await AuthService().getIdToken(forceRefresh: false);
      ApiService().setToken(token);
      String? uploadedUrl = _photoUrl;
      if (_photoFile != null) {
        bool firebaseOk = false;
        try {
          final ref = FirebaseStorage.instance.ref().child('profile_pics/$uid.jpg');
          await ref.putFile(_photoFile!, SettableMetadata(contentType: 'image/jpeg'));
          uploadedUrl = await ref.getDownloadURL();
          firebaseOk = true;
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo uploaded to Firebase ✓')));
        } catch (e) {
          debugPrint('Firebase upload failed: $e');
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Firebase failed: $e — trying server upload...'), duration: const Duration(seconds: 2)));
        }
        if (!firebaseOk) {
          try {
            final res = await ApiService().uploadProfilePhoto(uid, _photoFile!.path);
            uploadedUrl = (res['photo_url'] ?? res['file_url'] ?? res['photoUrl'] ?? '').toString();
            if (uploadedUrl.isEmpty) uploadedUrl = _photoUrl;
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo uploaded to server ✓'), backgroundColor: AppColors.success));
          } catch (e) {
            debugPrint('Backend upload failed: $e');
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error));
            uploadedUrl = _photoUrl;
          }
        }
      }
      await ApiService().updateProfile(uid, {
        'name': _name.text.trim(),
        'college': _college.text.trim(),
        'state': _state,
        'city': _city.text.trim(),
        'course': _course.text.trim(),
        'branch': _branch.text.trim(),
        'year_of_study': _year,
        'bio': _bio.text.trim(),
        'skills': _skills,
        'profile_complete': true,
        'photo_url': uploadedUrl,
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated ✓'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  void _addSkill(String v) {
    final t = v.trim();
    if (t.isNotEmpty && !_skills.contains(t)) setState(() => _skills.add(t));
    _skillInput.clear();
  }

  Widget _fallbackAvatar() => Container(color: AppColors.cyanDeep.withValues(alpha: 0.15), alignment: Alignment.center, child: Text(_name.text.isNotEmpty ? _name.text[0].toUpperCase() : '?', style: AppTypography.soraHeading2(color: AppColors.cyanDeep)));

  @override
  Widget build(BuildContext context) {
    final bottomNavPad = 84.0 + MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomNavPad),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(28), boxShadow: AppColors.neuRaisedShadows),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.shadowDark, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Edit Profile', style: AppTypography.soraHeading2()),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(alignment: Alignment.bottomRight, children: [
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.cyanDeep, width: 2), boxShadow: AppColors.neuSmallShadows),
                      child: ClipOval(
                        child: _photoFile != null
                            ? Image.file(_photoFile!, fit: BoxFit.cover, width: 96, height: 96)
                            : (_photoUrl != null && _photoUrl!.isNotEmpty
                                ? Image.network(_photoUrl!, fit: BoxFit.cover, width: 96, height: 96, errorBuilder: (_, __, ___) => _fallbackAvatar())
                                : _fallbackAvatar()),
                      ),
                    ),
                    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.cyanDeep, shape: BoxShape.circle, border: Border.all(color: AppColors.bg, width: 2)), child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white)),
                  ]),
                ),
              ),
              Center(child: TextButton(onPressed: _pickPhoto, child: Text('Change Photo', style: AppTypography.interLabel(color: AppColors.cyanDeep)))),
              const SizedBox(height: 8),
            NeuTextField(label: 'Name', hint: 'Full name', controller: _name),
            const SizedBox(height: 12),
            NeuTextField(label: 'College', hint: 'IIT Delhi', controller: _college),
            const SizedBox(height: 12),
            NeuDropdown<String>(label: 'State', hint: 'Select state', value: _state, items: _states.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(), onChanged: (v) => setState(() => _state = v)),
            const SizedBox(height: 12),
            NeuTextField(label: 'City', hint: 'Delhi', controller: _city),
            const SizedBox(height: 12),
            NeuTextField(label: 'Course', hint: 'B.Tech', controller: _course),
            const SizedBox(height: 12),
            NeuTextField(label: 'Branch', hint: 'Computer Science', controller: _branch),
            const SizedBox(height: 12),
            NeuDropdown<int>(label: 'Year', hint: 'Select year', value: _year, items: [1,2,3,4,5].map((e) => DropdownMenuItem(value: e, child: Text('Year $e'))).toList(), onChanged: (v) => setState(() => _year = v)),
            const SizedBox(height: 12),
            NeuTextField(label: 'Bio', hint: 'About you', controller: _bio, maxLines: 3, maxLength: 300),
            const SizedBox(height: 12),
            Text('Skills', style: AppTypography.interLabel()),
            const SizedBox(height: 6),
            Row(children: [Expanded(child: NeuTextField(hint: 'Add skill + Enter', controller: _skillInput, onFieldSubmitted: _addSkill)), const SizedBox(width: 8), NeuCard(padding: const EdgeInsets.all(12), onTap: () => _addSkill(_skillInput.text), child: const Icon(Icons.add_rounded, color: AppColors.cyanDeep))]),
            if (_skills.isNotEmpty) ...[const SizedBox(height: 10), Wrap(spacing: 6, runSpacing: 6, children: _skills.map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 12)), deleteIcon: const Icon(Icons.close, size: 14), onDeleted: () => setState(() => _skills.remove(s)))).toList())],
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _loading ? null : _save,
              child: Container(height: 54, decoration: BoxDecoration(gradient: AppColors.cyanGradient, borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Save Profile', style: AppTypography.interButton(color: Colors.white))),
            ),
            const SizedBox(height: 10),
          ]),
        ),
      ),
    ),
    );
  }
}

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();
  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  bool _notif = true;
  String _appVersion = 'v1.0.0';
  UpdateInfo? _updateInfo;
  bool _checking = true;
  bool _downloading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _checkUpdate();
  }

  Future<void> _loadVersion() async {
    try {
      final v = await UpdateService.getCurrentVersion();
      if (mounted) setState(() => _appVersion = 'v${v.split('+').first}');
    } catch (_) {}
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    final info = await UpdateService.checkForUpdate();
    if (mounted) setState(() { _updateInfo = info; _checking = false; });
  }

  Future<void> _doUpdate() async {
    if (_updateInfo == null || !_updateInfo!.hasUpdate) return;
    if (_updateInfo!.latestVersion == 'PlayStore') {
      final ok = await UpdateService.performPlayStoreUpdate();
      if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Play Store update not available')));
      return;
    }
    setState(() { _downloading = true; _progress = 0; });
    try {
      final path = await UpdateService.downloadApk(_updateInfo!.apkUrl!, onProgress: (r, t) {
        if (t > 0 && mounted) setState(() => _progress = r / t);
      });
      await UpdateService.installApk(path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(28), boxShadow: AppColors.neuRaisedShadows),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.shadowDark, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Settings', style: AppTypography.soraHeading2()),
            const SizedBox(height: 16),
            _tile(Icons.notifications_outlined, 'Notifications', Switch(value: _notif, onChanged: (v) => setState(() => _notif = v), activeThumbColor: AppColors.cyanDeep)),
            _tile(Icons.dark_mode_outlined, 'Dark Mode', Switch(value: isDark, onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(), activeThumbColor: AppColors.cyanDeep)),
            _tile(Icons.privacy_tip_outlined, 'Privacy Policy', Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.inkSoft), onTap: () { Navigator.pop(context); context.push(AppRoutes.privacy); }),
            _tile(Icons.description_outlined, 'Terms & Conditions', Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.inkSoft), onTap: () { Navigator.pop(context); context.push(AppRoutes.terms); }),
            _tile(Icons.info_outline_rounded, 'App Version', Text(_appVersion, style: AppTypography.interCaption())),
            const SizedBox(height: 8),
            if (_checking)
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), const SizedBox(width: 12), Text('Checking for updates...', style: AppTypography.interCaption())])),
            if (!_checking && _updateInfo != null && _updateInfo!.hasUpdate)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(gradient: AppColors.cyanGradient, borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [const Icon(Icons.system_update_rounded, color: Colors.white, size: 18), const SizedBox(width: 8), Text('Update available', style: AppTypography.interButton(color: Colors.white, size: 14)), const Spacer(), Text(_updateInfo!.latestVersion, style: AppTypography.interBadge(color: Colors.white))]),
                  if (_updateInfo!.releaseNotes != null && _updateInfo!.releaseNotes!.isNotEmpty) ...[const SizedBox(height: 6), Text(_updateInfo!.releaseNotes!, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 3, overflow: TextOverflow.ellipsis)],
                  const SizedBox(height: 10),
                  if (_downloading) ...[LinearProgressIndicator(value: _progress, color: Colors.white, backgroundColor: Colors.white24), const SizedBox(height: 6), Text('${(_progress * 100).toInt()}% downloading...', style: const TextStyle(color: Colors.white, fontSize: 11))],
                  if (!_downloading)
                    GestureDetector(
                      onTap: _doUpdate,
                      child: Container(height: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Text('Update Now →', style: AppTypography.interButton(color: AppColors.cyanDeep, size: 13))),
                    ),
                ]),
              ),
            if (!_checking && (_updateInfo == null || !_updateInfo!.hasUpdate))
              Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success), const SizedBox(width: 6), Text('App is up to date', style: AppTypography.interCaption(color: AppColors.success))])),
            if (!_checking)
              TextButton(onPressed: _checkUpdate, child: Text('Check again', style: AppTypography.interCaption(color: AppColors.cyanDeep))),
            const Divider(height: 24),
            NeuCard(padding: const EdgeInsets.all(14), onTap: () async { Navigator.pop(context); await AuthService().signOut(); if (context.mounted) context.go(AppRoutes.welcome); }, child: Row(children: [const Icon(Icons.logout_rounded, color: AppColors.error, size: 18), const SizedBox(width: 10), Text('Sign Out', style: AppTypography.interButton(color: AppColors.error))])),
            const SizedBox(height: 10),
            GestureDetector(onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete account — contact support'))), child: Text('Delete Account', style: AppTypography.interCaption(color: AppColors.error).copyWith(decoration: TextDecoration.underline))),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String title, Widget trailing, {VoidCallback? onTap}) => ListTile(leading: Icon(icon, color: AppColors.ink, size: 20), title: Text(title, style: AppTypography.interBody(size: 14)), trailing: trailing, onTap: onTap, contentPadding: EdgeInsets.zero, dense: true);
}
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/premium_badge.dart';
import 'resume_document_preview.dart';
import 'resume_templates.dart';

class ResumeScreen extends ConsumerStatefulWidget {
  const ResumeScreen({super.key});

  @override
  ConsumerState<ResumeScreen> createState() => _ResumeScreenState();
}

class _ResumeScreenState extends ConsumerState<ResumeScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _resumes = [];
  bool _loadingResumes = true;
  String? _resumeError;
  String? _openingKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadResumes();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadResumes();
  }

  Future<void> _loadResumes() async {
    if (mounted) {
      setState(() {
        _loadingResumes = true;
        _resumeError = null;
      });
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Sign in to see your saved resumes.');
      final token = await user.getIdToken();
      if (token != null) ApiService().setToken(token);
      final resumes = await ApiService().getMyResumes();
      if (mounted)
        setState(() {
          _resumes = resumes;
          _loadingResumes = false;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _resumeError = error.toString();
          _loadingResumes = false;
        });
    }
  }

  Future<void> _openEditor(ResumeTemplateSpec template,
      {String? resumeId, bool download = false}) async {
    final key = resumeId ?? template.id;
    if (_openingKey != null) return;
    if (template.isPremium &&
        !(ref.read(profileProvider(null)).value?.isPremium ?? false) &&
        resumeId == null) {
      _showPremiumDialog(template);
      return;
    }
    if (kIsWeb) {
      final query = <String, String>{
        if (resumeId != null) 'resumeId': resumeId,
        if (download) 'intent': 'download',
      };
      final suffix =
          query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
      context.go('/resume/${template.id}$suffix');
      return;
    }

    setState(() => _openingKey = key);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null)
        throw Exception('Please sign in again to open the resume editor.');
      final token = await user.getIdToken();
      if (token != null) ApiService().setToken(token);
      final code = await ApiService()
          .createResumeHandoff(templateId: template.id, resumeId: resumeId);
      final base = Uri.parse(AppConfig.userWebBaseUrl);
      final baseSegments =
          base.pathSegments.where((part) => part.isNotEmpty).toList();
      final uri = base.replace(
        pathSegments: [...baseSegments, 'resume', template.id],
        queryParameters: {
          'handoff': code,
          if (resumeId != null) 'resumeId': resumeId,
          if (download) 'intent': 'download',
        },
      );
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open the browser. Please try again.');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _openingKey = null);
    }
  }

  void _showPremiumDialog(ResumeTemplateSpec template) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [
          const PremiumBadge(label: 'PRO'),
          const SizedBox(width: 9),
          Expanded(child: Text('${template.name} template'))
        ]),
        content: const Text(
            'This design is part of the 10 Premium templates. Upgrade your CampusSetu account to use it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium =
        ref.watch(profileProvider(null)).value?.isPremium ?? false;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100
        ? 4
        : width >= 700
            ? 3
            : 2;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Resume Studio', style: AppTypography.soraHeading3()),
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.ink),
            onPressed: () => context.pop()),
        actions: [
          IconButton(
              tooltip: 'Refresh saved resumes',
              onPressed: _loadResumes,
              icon: Icon(Icons.refresh_rounded, color: AppColors.inkSoft))
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadResumes,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 34),
          children: [
            _intro(isPremium),
            const SizedBox(height: 23),
            Row(children: [
              Expanded(
                  child: Text('Choose a design',
                      style: AppTypography.soraHeading3())),
              Text('10 free  ·  10 premium',
                  style: AppTypography.interCaption(color: AppColors.inkSoft)),
            ]),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: resumeTemplates.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 15,
                childAspectRatio: columns == 2 ? 0.60 : 0.68,
              ),
              itemBuilder: (context, index) {
                final template = resumeTemplates[index];
                final sample = sampleResumeDocument();
                final isLocked = template.isPremium && !isPremium;
                final key = template.id;
                return _TemplateCard(
                  template: template,
                  document: sample,
                  locked: isLocked,
                  busy: _openingKey == key,
                  onTap: () => _openEditor(template),
                );
              },
            ),
            const SizedBox(height: 30),
            Row(children: [
              Expanded(
                  child:
                      Text('My resumes', style: AppTypography.soraHeading3())),
              if (!_loadingResumes && _resumeError == null)
                Text('${_resumes.length} saved',
                    style:
                        AppTypography.interCaption(color: AppColors.inkSoft)),
            ]),
            const SizedBox(height: 12),
            _savedResumes(),
          ],
        ),
      ),
    );
  }

  Widget _intro(bool isPremium) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(colors: [
            AppColors.cyanDeep.withValues(alpha: 0.23),
            AppColors.bg
          ]),
          border: Border.all(color: AppColors.cyanDeep.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: AppColors.cyanDeep.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.description_outlined,
                  color: AppColors.cyan, size: 24)),
          const SizedBox(width: 13),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Build it on a bigger screen',
                    style: AppTypography.interButton(
                        color: AppColors.ink, size: 15)),
                const SizedBox(height: 4),
                Text(
                    'Choose a template to open the secure CampusSetu web editor. Edit, save and download your PDF there.',
                    style:
                        AppTypography.interCaption(color: AppColors.inkSoft)),
              ])),
          if (isPremium)
            const Padding(
                padding: EdgeInsets.only(left: 8),
                child: PremiumBadge(label: 'PRO')),
        ]),
      );

  Widget _savedResumes() {
    if (_loadingResumes)
      return const Padding(
          padding: EdgeInsets.all(28),
          child: Center(child: CircularProgressIndicator()));
    if (_resumeError != null) {
      return _MessageCard(
        icon: Icons.cloud_off_outlined,
        text: 'Could not load saved resumes',
        actionLabel: 'Retry',
        onAction: _loadResumes,
      );
    }
    if (_resumes.isEmpty) {
      return const _MessageCard(
          icon: Icons.folder_open_outlined,
          text:
              'Your saved resumes will appear here. Select a template above to create your first one.');
    }
    return Column(children: [
      for (final resume in _resumes)
        Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: _SavedResumeCard(
            resume: resume,
            busy: _openingKey == resume['id']?.toString(),
            onEdit: () {
              final template =
                  resumeTemplateById((resume['template_id'] ?? '').toString());
              if (template != null)
                _openEditor(template, resumeId: resume['id']?.toString());
            },
            onDownload: () {
              final template =
                  resumeTemplateById((resume['template_id'] ?? '').toString());
              if (template != null)
                _openEditor(template,
                    resumeId: resume['id']?.toString(), download: true);
            },
          ),
        ),
    ]);
  }
}

class _TemplateCard extends StatelessWidget {
  final ResumeTemplateSpec template;
  final Map<String, dynamic> document;
  final bool locked;
  final bool busy;
  final VoidCallback onTap;

  const _TemplateCard(
      {required this.template,
      required this.document,
      required this.locked,
      required this.busy,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.isDark ? AppColors.darkTile : Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onTap,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(9, 9, 9, 0),
                    child: Stack(fit: StackFit.expand, children: [
                      ResumeDocumentPreview(
                          template: template, document: document),
                      if (locked)
                        Positioned.fill(
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    color:
                                        Colors.black.withValues(alpha: 0.16)),
                                child: const Center(
                                    child: Icon(Icons.lock_rounded,
                                        color: Colors.white, size: 24)))),
                      if (template.isPremium)
                        const Positioned(
                            top: 8,
                            right: 8,
                            child: PremiumBadge(label: 'PRO', isSmall: true)),
                    ]))),
            Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 11, 2),
                child: Row(children: [
                  Expanded(
                      child: Text(template.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.interButton(
                              color: AppColors.ink, size: 13))),
                  Icon(
                      locked
                          ? Icons.lock_outline_rounded
                          : Icons.arrow_outward_rounded,
                      size: 15,
                      color: locked ? AppColors.gold : AppColors.cyan),
                ])),
            Padding(
                padding: const EdgeInsets.fromLTRB(11, 0, 11, 11),
                child: Text(busy ? 'Opening editor…' : template.tagline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTypography.interCaption(color: AppColors.inkSoft))),
          ]),
        ),
      );
}

class _SavedResumeCard extends StatelessWidget {
  final Map<String, dynamic> resume;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDownload;

  const _SavedResumeCard(
      {required this.resume,
      required this.busy,
      required this.onEdit,
      required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final template =
        resumeTemplateById((resume['template_id'] ?? '').toString());
    if (template == null) return const SizedBox.shrink();
    final document = resume['content'] is Map
        ? Map<String, dynamic>.from(resume['content'] as Map)
        : sampleResumeDocument();
    final title = (resume['title'] ?? 'Untitled resume').toString();
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
          color: AppColors.isDark ? AppColors.darkTile : Colors.white,
          borderRadius: BorderRadius.circular(17),
          border:
              Border.all(color: AppColors.inkMuted.withValues(alpha: 0.22))),
      child: Row(children: [
        SizedBox(
            width: 68,
            child:
                ResumeDocumentPreview(template: template, document: document)),
        const SizedBox(width: 13),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.interButton(color: AppColors.ink, size: 14)),
          const SizedBox(height: 4),
          Text('${template.name} template',
              style: AppTypography.interCaption(color: AppColors.inkSoft)),
          const SizedBox(height: 11),
          Wrap(spacing: 8, runSpacing: 6, children: [
            OutlinedButton.icon(
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: Text(busy ? 'Opening…' : 'Edit')),
            FilledButton.tonalIcon(
                onPressed: busy ? null : onDownload,
                icon: const Icon(Icons.download_outlined, size: 15),
                label: const Text('Download')),
          ]),
        ])),
      ]),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageCard(
      {required this.icon,
      required this.text,
      this.actionLabel,
      this.onAction});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: AppColors.isDark ? AppColors.darkTile : Colors.white,
            borderRadius: BorderRadius.circular(17),
            border:
                Border.all(color: AppColors.inkMuted.withValues(alpha: 0.22))),
        child: Column(children: [
          Icon(icon, color: AppColors.inkSoft, size: 26),
          const SizedBox(height: 8),
          Text(text,
              textAlign: TextAlign.center,
              style: AppTypography.interBodySmall(color: AppColors.inkSoft)),
          if (actionLabel != null) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: onAction, child: Text(actionLabel!))
          ],
        ]),
      );
}

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(title: Text('Privacy Policy', style: AppTypography.soraHeading3()), backgroundColor: AppColors.bg, elevation: 0),
    body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
      NeuCard(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CampusSetu Privacy Policy', style: AppTypography.soraHeading2()),
        const SizedBox(height: 6),
        Text('Last updated: 29 Aug 2026', style: AppTypography.interCaption()),
        const SizedBox(height: 16),
        _h('1. Data we collect'),
        _p('We collect name, email, college, course, branch, city, state, bio, skills, profile photo, posts, notes, products and usage analytics. Firebase Auth provides email/name/photo for sign-in.'),
        _h('2. How we use it'),
        _p('To connect students across India, show discover feed, personalize jobs/notes/marketplace, improve recommendations and prevent abuse.'),
        _h('3. Storage & Sharing'),
        _p('Data stored on secured PostgreSQL (Neon) and Firebase. We never sell your data. Share only when you connect, post or list items.'),
        _h('4. Your controls'),
        _p('Edit profile anytime via pencil icon. Delete account from Settings → Delete Account (contact support). You can request data export.'),
        _h('5. Cookies & Analytics'),
        _p('We use minimal analytics for crash and performance. No third-party ad trackers.'),
        _h('6. Retention'),
        _p('Tshare codes auto-delete in 24h. Posts/notes stay until you delete or report violation.'),
        _h('7. Contact'),
        _p('privacy@campussetu.in — reply within 48 hours.'),
      ])),
    ]),
  );
  Widget _h(String t) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(t, style: AppTypography.interButton(size: 14, color: AppColors.cyanDeep)));
  Widget _p(String t) => Text(t, style: AppTypography.interBody(size: 13, height: 1.6, color: AppColors.inkSoft));
}

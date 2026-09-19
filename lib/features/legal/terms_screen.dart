import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(title: Text('Terms & Conditions', style: AppTypography.soraHeading3()), backgroundColor: AppColors.bg, elevation: 0),
    body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
      NeuCard(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CampusSetu Terms', style: AppTypography.soraHeading2()),
        const SizedBox(height: 6),
        Text('Effective: 29 Aug 2026', style: AppTypography.interCaption()),
        const SizedBox(height: 16),
        _h('1. Acceptance'),
        _p('By using CampusSetu you agree to these Terms, Privacy Policy and community guidelines. If you disagree, do not use the app.'),
        _h('2. Eligibility'),
        _p('Must be a student (13+). Provide accurate college/course info. Fake profiles may be verified/banned.'),
        _h('3. User Content'),
        _p('You own your posts, notes, products and code shares. You grant us license to display them. No plagiarism, spam, hate or illegal content.'),
        _h('4. Marketplace & Jobs'),
        _p('CampusSetu is a campus-locked listing platform, not a party to transactions. Verify before payment. Report fraud immediately.'),
        _h('5. Tshare'),
        _p('Codes expire in 24h, max 5/day. Do not share sensitive secrets (passwords, keys).'),
        _h('6. Conduct & Reports'),
        _p('Respect peers. Reports are reviewed; violations may lead to content removal or ban.'),
        _h('7. Disclaimer & Liability'),
        _p('Provided as-is. We do not guarantee job/note accuracy. Max liability = amount you paid (free tier = 0).'),
        _h('8. Changes'),
        _p('We may update Terms; continued use = acceptance. Major changes notified in-app.'),
        _h('9. Contact'),
        _p('support@campussetu.in'),
      ])),
    ]),
  );
  Widget _h(String t) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(t, style: AppTypography.interButton(size: 14, color: AppColors.cyanDeep)));
  Widget _p(String t) => Text(t, style: AppTypography.interBody(size: 13, height: 1.6, color: AppColors.inkSoft));
}

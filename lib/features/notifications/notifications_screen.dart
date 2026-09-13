import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final items = [
      {'title': 'New connection request', 'body': 'Ankit Patel wants to connect', 'time': '2m'},
      {'title': 'Job alert', 'body': 'Flutter Intern at Razorpay — Apply now', 'time': '1h'},
      {'title': 'Tshare retrieved', 'body': 'Someone retrieved your code A7K9', 'time': '3h'},
      {'title': 'Comment on your post', 'body': 'Priya: Nice project!', 'time': '5h'},
      {'title': 'Welcome to CampusSetu', 'body': 'Complete your profile to get discovered', 'time': '1d'},
    ];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text('Notifications', style: AppTypography.soraHeading3()), backgroundColor: AppColors.bg, elevation: 0),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => NeuCard(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.cyanDeep.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.notifications_rounded, color: AppColors.cyanDeep, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(items[i]['title']!, style: AppTypography.interButton(size: 13)), const SizedBox(height: 2), Text(items[i]['body']!, style: AppTypography.interBodySmall())])),
            Text(items[i]['time']!, style: AppTypography.monoTimestamp()),
          ]),
        ),
      ),
    );
  }
}

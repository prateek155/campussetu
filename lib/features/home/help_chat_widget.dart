import 'package:flutter/material.dart';
import 'package:campussetu/core/theme/app_colors.dart';
import 'package:campussetu/core/theme/app_typography.dart';

class HelpChatWidget extends StatefulWidget {
  const HelpChatWidget({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const HelpChatWidget(),
      ),
    );
  }

  @override
  State<HelpChatWidget> createState() => _HelpChatWidgetState();
}

class _HelpChatWidgetState extends State<HelpChatWidget> {
  final List<Map<String, String>> _messages = [
    {
      'sender': 'bot',
      'text': 'Hi! I am CampusSetu Support. How can I help you today?',
    },
  ];

  final Map<String, String> _qaPairs = {
    'how can i get premium and what we get new features': 'Get premium by paying 99 rupees per month and you get more resume design options, get extra points, get best support, get new features like helping hand tasks and more.',
    'how can i cancel my subscription': 'You just send request for cancellation and after that within 24 hours your request will be approved.',
  };

  final TextEditingController _controller = TextEditingController();

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
    });

    _controller.clear();

    // Check if it matches any predefined questions
    final lowerText = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    String botReply = 'I am sorry, I did not understand that. For more complex issues, please email our support team.';

    for (var question in _qaPairs.keys) {
      if (lowerText.contains(question.replaceAll(RegExp(r'[^\w\s]'), '')) || 
          question.replaceAll(RegExp(r'[^\w\s]'), '').contains(lowerText)) {
        botReply = _qaPairs[question]!;
        break;
      }
    }

    // Small delay to simulate typing
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _messages.add({'sender': 'bot', 'text': botReply});
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                const Icon(Icons.support_agent, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'CampusSetu Help Support',
                    style: AppTypography.soraHeading3().copyWith(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Suggested Questions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _qaPairs.keys.map((q) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    label: Text(q, style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      _controller.text = q;
                      _sendMessage();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Chat Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? const Radius.circular(0) : null,
                        bottomLeft: !isUser ? const Radius.circular(0) : null,
                      ),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask a question...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

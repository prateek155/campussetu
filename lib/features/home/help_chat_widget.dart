import 'package:flutter/material.dart';
import 'package:campussetu/core/theme/app_colors.dart';

class HelpChatWidget extends StatefulWidget {
  final bool isWebDocked;
  const HelpChatWidget({super.key, this.isWebDocked = false});

  static void show(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 650;
    if (isDesktop) {
      showDialog(
        context: context,
        barrierColor: Colors.transparent,
        builder: (context) => Stack(
          children: [
            Positioned(
              bottom: 80,
              right: 86,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 370,
                  height: 520,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: const HelpChatWidget(isWebDocked: true),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: const HelpChatWidget(isWebDocked: false),
        ),
      );
    }
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
      height: widget.isWebDocked ? null : MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(widget.isWebDocked ? 20 : 24),
          bottom: Radius.circular(widget.isWebDocked ? 20 : 0),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(widget.isWebDocked ? 20 : 24)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.support_agent, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'CampusSetu Support',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.circle, color: Color(0xFF22C55E), size: 8),
                          SizedBox(width: 5),
                          Text(
                            'Online • Instant Bot',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          
          // Suggested Questions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: _qaPairs.keys.map((q) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ActionChip(
                    label: Text(q, style: const TextStyle(fontSize: 11)),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    backgroundColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUser ? const Radius.circular(2) : null,
                        bottomLeft: !isUser ? const Radius.circular(2) : null,
                      ),
                      border: isUser ? null : Border.all(color: Colors.grey.shade200),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: widget.isWebDocked ? 260 : MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Input Area
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ask a question...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                      padding: EdgeInsets.zero,
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

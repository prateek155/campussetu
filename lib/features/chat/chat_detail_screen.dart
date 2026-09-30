// lib/features/chat/chat_detail_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_text_field.dart';
import '../../core/widgets/user_avatar.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String displayName;
  final String? avatarUrl;
  const ChatDetailScreen({
    super.key,
    required this.chatId,
    this.displayName = 'Conversation',
    this.avatarUrl,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  CollectionReference get _messagesRef => FirebaseFirestore.instance
      .collection('chats')
      .doc(widget.chatId)
      .collection('messages');

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    if (_sending) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to send a message.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await _messagesRef.add({
        'text': text,
        'sender_uid': user.uid,
        'sender_name': user.displayName ?? '',
        'sender_photo_url': user.photoURL,
        'type': 'text',
        'created_at': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      if (_msgCtrl.text.trim() == text) _msgCtrl.clear();

      Future.delayed(300.ms, () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: 300.ms,
            curve: Curves.easeOut,
          );
        }
      });
    } on FirebaseException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message could not be sent. Please try again.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message could not be sent. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: NeuCard(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.ink),
          ),
        ),
        title: Row(
          children: [
            UserAvatar(name: widget.displayName, imageUrl: widget.avatarUrl, size: 36),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.displayName, style: AppTypography.interButton(color: AppColors.ink, size: 14)),
                Text('Conversation', style: AppTypography.interCaption(color: AppColors.inkSoft)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Messages ─────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesRef
                  .orderBy('created_at', descending: false)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.cyanDeep));
                }

                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Messages could not be loaded. Check your connection and try again.',
                        style: AppTypography.interBody(color: AppColors.inkSoft),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Send a hello to start.',
                      style: AppTypography.interBody(color: AppColors.inkSoft),
                    ),
                  );
                }
                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                final messages = docs.map((d) => d.data() as Map<String, dynamic>).toList();

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final msg = messages[i];
                    final isMe = currentUid != null && msg['sender_uid'] == currentUid;
                    return _MessageBubble(text: msg['text']?.toString() ?? '', isMe: isMe)
                        .animate(delay: (i * 40).ms)
                        .fadeIn(duration: 200.ms)
                        .slideX(begin: isMe ? 0.05 : -0.05);
                  },
                );
              },
            ),
          ),

          // ── Input bar ─────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: NeuTextField(
                      hint: 'Message...',
                      controller: _msgCtrl,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sending ? null : _sendMessage,
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.cyanGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  const _MessageBubble({required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.cyanDeep : AppColors.bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: isMe ? null : AppColors.neuSmallShadows,
        ),
        child: Text(
          text,
          style: AppTypography.interBody(
            color: isMe ? Colors.white : AppColors.ink,
            size: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

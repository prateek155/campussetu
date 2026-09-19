// lib/features/faculty/quiz/create_quiz_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';

class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({super.key});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _titleC = TextEditingController();
  final List<_QuestionData> _questions = [];
  bool _loading = false;

  @override
  void dispose() {
    _titleC.dispose();
    super.dispose();
  }

  void _addQuestion() {
    setState(() => _questions.add(_QuestionData()));
  }

  void _removeQuestion(int index) {
    setState(() => _questions.removeAt(index));
  }

  Future<void> _submit() async {
    if (_titleC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a quiz title')),
      );
      return;
    }
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one question')),
      );
      return;
    }
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.questionC.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Question ${i + 1}: Enter question text')),
        );
        return;
      }
      if (!q.options.any((o) => o.isCorrect)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Question ${i + 1}: Mark at least one correct answer')),
        );
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final baseUrl = dotenv.env['API_BASE_URL'] ?? '';
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {'Authorization': 'Bearer $token'},
      ));

      // Upload images first
      List<Map<String, dynamic>> questionsData = [];
      for (final q in _questions) {
        String? imageUrl;
        if (q.imageFile != null || q.imageBytes != null) {
          final formData = FormData.fromMap({
            'image': (kIsWeb && q.imageBytes != null)
                ? MultipartFile.fromBytes(q.imageBytes!, filename: 'question_image.jpg')
                : await MultipartFile.fromFile(q.imageFile!.path, filename: 'question_image.jpg'),
          });
          final imgResp = await dio.post('/quiz/upload/image', data: formData);
          imageUrl = imgResp.data['url'];
        }


        questionsData.add({
          'question_text': q.questionC.text.trim(),
          'image_url': imageUrl,
          'options': q.options.map((o) => {'text': o.textC.text.trim(), 'isCorrect': o.isCorrect}).toList(),
        });
      }

      final resp = await dio.post('/quiz', data: {
        'title': _titleC.text.trim(),
        'questions': questionsData,
      });


      final quizId = resp.data['id'];
      if (!mounted) return;

      // Show PIN dialog then navigate
      final pin = resp.data['pin'];
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Quiz Created! 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your quiz PIN:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  pin,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 8),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Share this PIN with students to join the quiz.', textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(context); context.go('/faculty/quizzes/$quizId/dashboard'); },
              child: const Text('Open Dashboard'),
            ),
          ],
        ),
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? 'Failed to create quiz';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Quiz'),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, color: Colors.white),
            label: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quiz Title
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quiz Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleC,
                        decoration: const InputDecoration(
                          labelText: 'Quiz Title',
                          hintText: 'e.g. Chapter 5 — Newton\'s Laws',
                          prefixIcon: Icon(Icons.quiz_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Questions
              const Text('Questions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              ..._questions.asMap().entries.map((entry) =>
                _QuestionCard(
                  index: entry.key,
                  data: entry.value,
                  onRemove: () => _removeQuestion(entry.key),
                  onChanged: () => setState(() {}),
                ),
              ),

              const SizedBox(height: 16),

              // Add Question Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Question'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFF6C63FF)),
                    foregroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Individual Question Card ──────────────────────────────────
class _QuestionCard extends StatefulWidget {
  final int index;
  final _QuestionData data;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _QuestionCard({required this.index, required this.data, required this.onRemove, required this.onChanged});

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    if (kIsWeb) {
      widget.data.imageBytes = await picked.readAsBytes();
      widget.data.imageFile = null;
    } else {
      widget.data.imageFile = File(picked.path);
      widget.data.imageBytes = null;
    }
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Header
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: const BoxDecoration(color: Color(0xFF6C63FF), shape: BoxShape.circle),
                  child: Center(child: Text('${widget.index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 12),
                const Text('Question', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                IconButton(onPressed: widget.onRemove, icon: const Icon(Icons.delete_outline, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 16),

            // Question Text
            TextField(
              controller: widget.data.questionC,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Question Text',
                hintText: 'Enter your question here...',
              ),
              onChanged: (_) => widget.onChanged(),
            ),
            const SizedBox(height: 16),

            // Image
            Row(
              children: [
                if (widget.data.imageFile != null || widget.data.imageBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb && widget.data.imageBytes != null
                        ? Image.memory(widget.data.imageBytes!, height: 80, width: 120, fit: BoxFit.cover)
                        : Image.file(widget.data.imageFile!, height: 80, width: 120, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () { setState(() { widget.data.imageFile = null; widget.data.imageBytes = null; }); },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Remove'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ] else
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Add Image (Optional)'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Options
            const Text('Answer Options (mark the correct one)', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 12),
            ...widget.data.options.asMap().entries.map((entry) {
              final i = entry.key;
              final opt = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    // ignore: deprecated_member_use
                    Radio<int>(
                      value: i,
                      // ignore: deprecated_member_use
                      groupValue: widget.data.options.indexWhere((o) => o.isCorrect),
                      // ignore: deprecated_member_use
                      onChanged: (val) {
                        setState(() {
                          for (var o in widget.data.options) {
                            o.isCorrect = false;
                          }
                          widget.data.options[i].isCorrect = true;
                        });
                        widget.onChanged();
                      },
                      activeColor: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: opt.textC,
                        decoration: InputDecoration(
                          labelText: 'Option ${String.fromCharCode(65 + i)}',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: opt.isCorrect,
                          fillColor: opt.isCorrect ? const Color(0x1A4CAF50) : null,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: opt.isCorrect ? Colors.green : Colors.grey.shade300),
                          ),
                        ),
                        onChanged: (_) => widget.onChanged(),
                      ),
                    ),
                  ],
                ),
              );
            }),

          ],
        ),
      ),
    );
  }
}

// ── Data models for quiz creation ─────────────────────────────
class _OptionData {
  final textC = TextEditingController();
  bool isCorrect = false;
}

class _QuestionData {
  final questionC = TextEditingController();
  File? imageFile;
  Uint8List? imageBytes;
  final List<_OptionData> options = List.generate(4, (_) => _OptionData());
}


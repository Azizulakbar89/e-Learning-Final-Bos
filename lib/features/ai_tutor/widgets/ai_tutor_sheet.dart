import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/ai_service.dart';

class AiTutorSheet extends StatefulWidget {
  final String materialTitle;
  final String materialContent;
  final String? mediaType;

  const AiTutorSheet({
    super.key,
    required this.materialTitle,
    required this.materialContent,
    this.mediaType,
  });

  @override
  State<AiTutorSheet> createState() => _AiTutorSheetState();
}

class _AiTutorSheetState extends State<AiTutorSheet> {
  final _inputController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'ai',
      'text':
          'Halo! Saya AI Tutor resmi materi "${widget.materialTitle}". Saya siap menjawab konsep, rumus, atau cara kerja modul ini. Pertanyaan dibatasi khusus seputar materi ini ya! 💡',
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _handleSend([String? presetText]) async {
    final text = presetText ?? _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isTyping = true;
    });
    if (presetText == null) {
      _inputController.clear();
    }

    final response = await AiService.askMaterialQuestion(
      materialTitle: widget.materialTitle,
      materialContent: widget.materialContent,
      userQuestion: text,
      mediaType: widget.mediaType,
    );

    if (mounted) {
      setState(() {
        _messages.add({'role': 'ai', 'text': response});
        _isTyping = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle & Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.aiGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Study Companion',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Terkoneksi langsung dengan materi ini',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.purple.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.purple.withAlpha(50)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: AppColors.purple),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'RAG Guardrail Aktif: Diskusi dibatasi khusus materi "${widget.materialTitle}"',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6D28D9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                final isOutOfContext = !isUser &&
                    (msg['text']?.contains('[DI LUAR KONTEKS PEMBELAJARAN]') ?? false);

                final displayText = isOutOfContext
                    ? (msg['text'] ?? '')
                        .replaceAll('⚠️ [DI LUAR KONTEKS PEMBELAJARAN]', '')
                        .replaceAll('[DI LUAR KONTEKS PEMBELAJARAN]', '')
                        .trim()
                    : (msg['text'] ?? '');

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.85,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? AppColors.primary
                          : (isOutOfContext
                              ? const Color(0xFFFFFBEB)
                              : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(16),
                      border: isOutOfContext
                          ? Border.all(color: const Color(0xFFF59E0B), width: 1.5)
                          : null,
                      boxShadow: isOutOfContext
                          ? [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withAlpha(30),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isOutOfContext) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 15,
                                  color: Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'DI LUAR KONTEKS PEMBELAJARAN',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF991B1B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SelectableText(
                          displayText,
                          style: TextStyle(
                            color: isUser
                                ? Colors.white
                                : (isOutOfContext
                                    ? const Color(0xFF78350F)
                                    : const Color(0xFF1E293B)),
                            height: 1.45,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text('AI sedang menyusun jawaban...', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),

          // Quick Starter Prompt Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.summarize_rounded, size: 14, color: AppColors.purple),
                  label: const Text('Ringkasan Materi', style: TextStyle(fontSize: 11)),
                  onPressed: () => _handleSend('Tolong berikan ringkasan poin-poin utama materi ini secara singkat dan jelas.'),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(Icons.lightbulb_outline_rounded, size: 14, color: Color(0xFFF59E0B)),
                  label: const Text('Contoh Penerapan', style: TextStyle(fontSize: 11)),
                  onPressed: () => _handleSend('Berikan contoh nyata penerapan konsep materi ini dalam kehidupan sehari-hari.'),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(Icons.help_outline_rounded, size: 14, color: Color(0xFF059669)),
                  label: const Text('Poin Penting Ujian', style: TextStyle(fontSize: 11)),
                  onPressed: () => _handleSend('Apa saja konsep penting dari materi ini yang sering keluar saat kuis atau ujian?'),
                ),
              ],
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      hintText: 'Tanyakan sesuatu seputar materi...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _handleSend,
                  icon: const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.purple),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

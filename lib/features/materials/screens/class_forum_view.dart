import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/content_filter_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';

class ClassForumView extends StatefulWidget {
  final String materialId;
  final String classId;

  const ClassForumView({
    super.key,
    required this.materialId,
    required this.classId,
  });

  @override
  State<ClassForumView> createState() => _ClassForumViewState();
}

class _ClassForumViewState extends State<ClassForumView> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Cek apakah pesan mengandung konten tidak pantas
    final filtered = ContentFilterService.instance.filter(text);
    final wasFiltered = filtered != text;

    final fbService = context.read<FirebaseService>();
    fbService.sendForumMessage(
      materialId: widget.materialId,
      classId: widget.classId,
      message: text,
    );

    _messageController.clear();

    if (wasFiltered) {
      AppSnackBar.warning(
        context,
        'Pesan terkirim. Konten tidak pantas telah disensor. 🚫',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fbService = context.watch<FirebaseService>();
    final currentUser = fbService.currentUser;
    final messages = fbService.getForumMessages(
      materialId: widget.materialId,
      classId: widget.classId,
    );

    return Column(
      children: [
        // Security & Isolation Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.primary.withAlpha(20),
          child: Row(
            children: [
              const Icon(Icons.lock_clock_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Forum Khusus Kelas ${widget.classId} (Akses Terisolasi • Kelas Lain Tidak Dapat Melihat)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Message List
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Belum ada diskusi untuk kelas ${widget.classId}.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const Text(
                        'Jadilah yang pertama bertanya atau berdiskusi!',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUser?.id;
                    final isTeacher = msg.senderRole == 'guru';

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.primary
                              : (isTeacher ? Colors.purple.shade50 : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(16),
                          border: isTeacher ? Border.all(color: Colors.purple.shade200) : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  msg.senderName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isMe
                                        ? Colors.white.withAlpha(220)
                                        : (isTeacher ? Colors.purple.shade700 : Colors.black87),
                                  ),
                                ),
                                if (isTeacher) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade700,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'GURU',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              msg.message,
                              style: TextStyle(
                                fontSize: 14,
                                color: isMe ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Message Input
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: const Border(top: BorderSide(color: AppColors.borderLight)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Tulis pesan forum kelas ${widget.classId}...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

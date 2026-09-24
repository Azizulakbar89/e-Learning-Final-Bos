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

  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
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
    _scrollToBottom();

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
    // Fitur forum tetap terisolasi per classId
    final messages = fbService.getForumMessages(
      materialId: widget.materialId,
      classId: widget.classId,
    );

    return Column(
      children: [
        // Message List
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.navy.withAlpha(12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.forum_rounded,
                            size: 42,
                            color: AppColors.navyMid,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Belum Ada Diskusi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navyDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Jadilah yang pertama bertanya atau berdiskusi dengan teman & guru!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryLight,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUser?.id;
                    final isTeacher = msg.senderRole == 'guru';
                    final timeStr =
                        '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment:
                            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            // Avatar sender
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: isTeacher
                                  ? AppColors.orangePale
                                  : AppColors.navy.withAlpha(20),
                              child: Text(
                                msg.senderName.isNotEmpty
                                    ? msg.senderName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isTeacher
                                      ? AppColors.orangeDark
                                      : AppColors.navyDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.74,
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: isMe
                                    ? const LinearGradient(
                                        colors: [Color(0xFF1E3A8A), Color(0xFF0F2552)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                color: isMe
                                    ? null
                                    : (isTeacher
                                        ? const Color(0xFFFFFBF7)
                                        : Colors.white),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 16),
                                ),
                                border: isMe
                                    ? null
                                    : Border.all(
                                        color: isTeacher
                                            ? AppColors.orange.withAlpha(80)
                                            : AppColors.borderLight,
                                        width: 1,
                                      ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isMe
                                        ? AppColors.navyDark.withAlpha(35)
                                        : const Color(0x0A0F172A),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (!isMe) ...[
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            msg.senderName,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: isTeacher
                                                  ? AppColors.orangeDark
                                                  : AppColors.navyDark,
                                            ),
                                          ),
                                        ),
                                        if (isTeacher) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  AppColors.orange,
                                                  AppColors.orangeDark
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.verified,
                                                    size: 10,
                                                    color: Colors.white),
                                                SizedBox(width: 3),
                                                Text(
                                                  'GURU',
                                                  style: TextStyle(
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  Text(
                                    msg.message,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.35,
                                      color: isMe
                                          ? Colors.white
                                          : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: isMe
                                          ? Colors.white.withAlpha(180)
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Message Input Bottom Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: AppColors.borderLight, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 10,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.borderLight,
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textPrimaryLight,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Tulis pesan diskusi kelas...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _sendMessage,
                    borderRadius: BorderRadius.circular(22),
                    child: Ink(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.orange, AppColors.orangeDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.orange.withAlpha(90),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.send_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

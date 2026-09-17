import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/streak_model.dart';
import '../../../core/services/content_filter_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/curved_header_card.dart';

class ChatConversationScreen extends StatefulWidget {
  final StreakModel streak;

  const ChatConversationScreen({super.key, required this.streak});

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final _msgController = TextEditingController();
  final _focusNode = FocusNode();

  ChatMessageModel? _replyingTo;
  ChatMessageModel? _editingMessage;

  @override
  void dispose() {
    _msgController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final fb = context.read<FirebaseService>();

    // Cek apakah pesan mengandung konten tidak pantas
    final filtered = ContentFilterService.instance.filter(text);
    final wasFiltered = filtered != text;

    if (_editingMessage != null) {
      // Mode Edit Pesan
      fb.editChatMessage(
        messageId: _editingMessage!.id,
        newText: text,
      );
      setState(() {
        _editingMessage = null;
      });
      _msgController.clear();
      if (wasFiltered) {
        AppSnackBar.warning(
          context,
          'Pesan diperbarui. Beberapa konten tidak pantas telah disensor. 🚫',
        );
      } else {
        AppSnackBar.success(
          context,
          'Pesan berhasil diperbarui!',
        );
      }
      return;
    }

    // Mode Kirim Pesan Biasa / Balas
    fb.sendChatMessage(
      streakId: widget.streak.id,
      message: text,
      replyToMessageId: _replyingTo?.id,
      replyToSenderName: _replyingTo?.senderName,
      replyToText: _replyingTo?.message,
    );

    setState(() {
      _replyingTo = null;
    });
    _msgController.clear();

    // Tampilkan peringatan jika ada konten yang disensor
    if (wasFiltered) {
      AppSnackBar.warning(
        context,
        'Pesan terkirim. Beberapa kata tidak pantas telah disensor otomatis. 🚫',
      );
    }
  }

  void _startReply(ChatMessageModel msg) {
    setState(() {
      _replyingTo = msg;
      _editingMessage = null;
    });
    _focusNode.requestFocus();
  }

  void _startEdit(ChatMessageModel msg) {
    setState(() {
      _editingMessage = msg;
      _replyingTo = null;
      _msgController.text = msg.message;
    });
    _focusNode.requestFocus();
  }

  void _copyMessage(ChatMessageModel msg) {
    Clipboard.setData(ClipboardData(text: msg.message));
    AppSnackBar.info(
      context,
      'Pesan berhasil disalin ke clipboard! 📋',
    );
  }

  void _deleteMessage(ChatMessageModel msg) {
    final fb = context.read<FirebaseService>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Hapus Pesan?'),
        content: const Text('Pesan ini akan dihapus dari obrolan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () {
              Navigator.pop(ctx);
              fb.deleteChatMessage(messageId: msg.id);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context, ChatMessageModel msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: AppColors.primary),
                title: const Text('Balas Pesan', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _startReply(msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Color(0xFF64748B)),
                title: const Text('Salin Teks', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _copyMessage(msg);
                },
              ),
              if (isMe) ...[
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: Color(0xFF0284C7)),
                  title: const Text('Edit Pesan', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _startEdit(msg);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.rose),
                  title: const Text('Hapus Pesan', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.rose)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteMessage(msg);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _restoreStreak(FirebaseService fb, String streakId) {
    fb.restoreStreak(streakId: streakId);
    AppSnackBar.success(
      context,
      'Streak berhasil dipulihkan! Api belajar menyala kembali 🔥',
    );
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final currentUser = fb.currentUser;
    final liveStreak = fb.streaks.firstWhere(
      (s) => s.id == widget.streak.id,
      orElse: () => widget.streak,
    );

    // Guard: ensure teacher only accesses chats for their assigned classes & students
    if (currentUser?.isGuru == true) {
      final teacherClasses = fb.getTeacherClasses(currentUser);
      final teacherClassesLower = teacherClasses.map((c) => c.toLowerCase()).toSet();
      final teacherStudents = fb.getTeacherStudents(currentUser);
      final teacherStudentIds = teacherStudents.map((s) => s.id).toSet();
      final teacherStudentNames = teacherStudents.map((s) => s.fullName.toLowerCase()).toSet();

      bool isAuthorized = false;
      if (liveStreak.type == StreakType.group) {
        isAuthorized = teacherClassesLower.isNotEmpty &&
            teacherClassesLower.any((cls) => liveStreak.title.toLowerCase().contains(cls));
      } else if (liveStreak.type == StreakType.teacher) {
        final otherIds = liveStreak.participantIds.where((id) => id != currentUser!.id);
        final otherNames = liveStreak.participantNames.where((n) => n != currentUser!.fullName);
        isAuthorized = otherIds.any((id) => teacherStudentIds.contains(id)) ||
            otherNames.any((name) => teacherStudentNames.contains(name.toLowerCase()));
      } else {
        isAuthorized = liveStreak.participantIds.contains(currentUser?.id);
      }

      if (!isAuthorized) {
        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_rounded, size: 56, color: Color(0xFFDC2626)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Akses Obrolan Dibatasi',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Anda tidak ditugaskan mengajar kelas atau siswa dalam obrolan ini oleh Admin Sekolah.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Kembali'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    final messages = fb.chatMessages.where((c) => c.streakId == widget.streak.id).toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));

    final isDead = liveStreak.isDead;
    final hoursLeft = liveStreak.expiresAt.difference(DateTime.now()).inHours;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CurvedHeaderCard(
              title: liveStreak.title,
              subtitle: liveStreak.type.label,
              actions: [
                GestureDetector(
                  onTap: isDead ? () => _restoreStreak(fb, liveStreak.id) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: isDead
                          ? const LinearGradient(colors: [Color(0xFF64748B), Color(0xFF94A3B8)])
                          : AppColors.flameGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isDead
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.orange.withAlpha(100),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(isDead ? '❄️' : '🔥', style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          isDead ? 'Padam' : '${liveStreak.streakCount}',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Column(
                children: [
                  // Streak Status Bar (Real-time & Unlimited Restoration)
                  Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDead
                ? const Color(0xFFF1F5F9)
                : (liveStreak.isExpiringSoon ? Colors.red.shade50 : Colors.amber.shade50),
            child: Row(
              children: [
                Icon(
                  isDead
                      ? Icons.ac_unit_rounded
                      : (liveStreak.isExpiringSoon ? Icons.local_fire_department : Icons.local_fire_department_rounded),
                  size: 18,
                  color: isDead
                      ? const Color(0xFF64748B)
                      : (liveStreak.isExpiringSoon ? Colors.red : Colors.orange),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isDead
                        ? 'Streak padam (> 24 jam tidak chat). Pulihkan api belajar Anda tanpa batas!'
                        : (liveStreak.isExpiringSoon
                            ? 'PERINGATAN: Streak padam dalam $hoursLeft jam! Kirim chat sekarang 🔥'
                            : 'Streak aktif (${liveStreak.streakCount} hari). Sisa waktu: $hoursLeft jam.'),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDead
                          ? const Color(0xFF475569)
                          : (liveStreak.isExpiringSoon ? Colors.red.shade900 : Colors.orange.shade900),
                    ),
                  ),
                ),
                if (isDead)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      foregroundColor: const Color(0xFFFF5722),
                    ),
                    onPressed: () => _restoreStreak(fb, liveStreak.id),
                    icon: const Icon(Icons.replay_rounded, size: 15),
                    label: const Text('Pulihkan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                  ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withAlpha(40),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.local_fire_department_rounded,
                              size: 44,
                              color: Color(0xFFFF5722),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Ruang Obrolan Belum Dimulai',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Kirim pesan pertama Anda di bawah untuk mulai mengobrol & menyalakan api streak belajar! 🔥',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == currentUser?.id;
                      final timeStr =
                          '${msg.sentAt.hour.toString().padLeft(2, '0')}:${msg.sentAt.minute.toString().padLeft(2, '0')}';

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: GestureDetector(
                          onLongPress: () => _showMessageOptions(context, msg, isMe),
                          onDoubleTap: () => _startReply(msg),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xFF3B82F6) : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMe ? 16 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 16),
                              ),
                              border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(isMe ? 25 : 10),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Sender name if other person
                                if (!isMe) ...[
                                  Text(
                                    msg.senderName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5,
                                      color: Color(0xFF047857),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                ],

                                // WhatsApp-style Quoted Reply Preview Box
                                if (msg.hasReply)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isMe ? Colors.blue.shade800.withAlpha(120) : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border(
                                        left: BorderSide(
                                          color: isMe ? Colors.white : const Color(0xFF0284C7),
                                          width: 3.5,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          msg.replyToSenderName ?? 'Pesan',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10.5,
                                            color: isMe ? Colors.white : const Color(0xFF0284C7),
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          msg.replyToText ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isMe ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Main Message Text
                                Text(
                                  msg.message,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : const Color(0xFF1E293B),
                                    fontSize: 14,
                                    height: 1.35,
                                  ),
                                ),

                                const SizedBox(height: 3),

                                // Time and "(diedit)" indicator (WhatsApp style)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (msg.isEdited) ...[
                                      Text(
                                        '(diedit) ',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          fontSize: 10,
                                          color: isMe ? Colors.white70 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isMe ? Colors.white70 : Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Quoted Reply Preview Banner (Above text input)
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                  left: const BorderSide(color: Color(0xFF3B82F6), width: 4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 18, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Membalas ${_replyingTo!.senderName}:',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          _replyingTo!.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),

          // Edit Message Banner (Above text input)
          if (_editingMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border(
                  top: BorderSide(color: Colors.amber.shade200),
                  left: const BorderSide(color: Colors.amber, width: 4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded, size: 18, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Mengedit pesan Anda...',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.brown),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.brown),
                    onPressed: () {
                      setState(() {
                        _editingMessage = null;
                        _msgController.clear();
                      });
                    },
                  ),
                ],
              ),
            ),

          // Message Input Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: _editingMessage != null
                          ? 'Perbarui pesan...'
                          : (_replyingTo != null ? 'Tulis balasan pesan...' : 'Kirim pesan & rawat api streak 🔥...'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendMessage,
                  icon: Icon(_editingMessage != null ? Icons.check_rounded : Icons.send_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: _editingMessage != null ? const Color(0xFF059669) : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ],
),
),
);
}
}

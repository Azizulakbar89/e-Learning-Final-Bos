import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/models/notification_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../materials/screens/material_detail_screen.dart';
import '../../exams/screens/student_exams_screen.dart';
import 'chat_conversation_screen.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  String _filter = 'all'; // all | material | exam | chat

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _onNotificationTap(BuildContext context, FirebaseService fb, AppNotificationModel notif) {
    final userId = fb.currentUser?.id;
    if (userId != null) {
      fb.markNotificationAsRead(notif.id, userId);
    }

    if (notif.type == 'material' && notif.referenceId != null) {
      final material = fb.materials.where((m) => m.id == notif.referenceId).firstOrNull;
      if (material != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MaterialDetailScreen(material: material)),
        );
        return;
      }
    } else if (notif.type == 'exam') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StudentExamsScreen()),
      );
      return;
    } else if (notif.type == 'chat' && notif.referenceId != null) {
      final streak = fb.streaks.where((s) => s.id == notif.referenceId).firstOrNull;
      if (streak != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatConversationScreen(streak: streak)),
        );
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(notif.title),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final user = fb.currentUser;
    final allNotifs = fb.getNotificationsForUser(user);

    final filteredNotifs = allNotifs.where((n) {
      if (_filter == 'material') return n.type == 'material';
      if (_filter == 'exam') return n.type == 'exam';
      if (_filter == 'chat') return n.type == 'chat';
      return true;
    }).toList();

    final unreadCount = fb.getUnreadNotificationCount(user);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF071540),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pusat Notifikasi',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              user?.isSiswa == true
                  ? 'Pemberitahuan Kelas ${user?.className ?? user?.classId ?? "-"}'
                  : 'Semua Pemberitahuan Pembelajaran',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (unreadCount > 0 && user != null)
            TextButton.icon(
              onPressed: () => fb.markAllNotificationsAsRead(user.id),
              icon: const Icon(Icons.done_all_rounded, color: Color(0xFF38BDF8), size: 16),
              label: const Text(
                'Tandai Dibaca',
                style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Semua (${allNotifs.length})', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    '📚 Materi (${allNotifs.where((n) => n.type == "material").length})',
                    'material',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    '📝 Kuis (${allNotifs.where((n) => n.type == "exam").length})',
                    'exam',
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    '💬 Chat (${allNotifs.where((n) => n.type == "chat").length})',
                    'chat',
                  ),
                ],
              ),
            ),
          ),

          // Notification List
          Expanded(
            child: filteredNotifs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D2B6E).withAlpha(15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notifications_off_outlined, size: 48, color: Color(0xFF0D2B6E)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum Ada Notifikasi',
                            style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user?.isSiswa == true
                                ? 'Notifikasi materi baru, kuis kelas, dan pesan chat dari guru akan muncul di sini secara otomatis.'
                                : 'Notifikasi penerbitan materi, kuis, dan pesan chat akan tercatat di sini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    itemCount: filteredNotifs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final notif = filteredNotifs[i];
                      final isUnread = user != null && !notif.readByUserIds.contains(user.id);
                      final isExam = notif.type == 'exam';
                      final isChat = notif.type == 'chat';

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _onNotificationTap(context, fb, notif),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isUnread ? Colors.white : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isUnread
                                  ? (isExam
                                      ? const Color(0xFFFED7AA)
                                      : isChat
                                          ? const Color(0xFFA7F3D0)
                                          : const Color(0xFFBAE6FD))
                                  : const Color(0xFFE2E8F0),
                              width: isUnread ? 1.5 : 1.0,
                            ),
                            boxShadow: [
                              if (isUnread)
                                BoxShadow(
                                  color: (isExam
                                          ? const Color(0xFFEA580C)
                                          : isChat
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF0284C7))
                                      .withAlpha(20),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Type Icon
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: isExam
                                      ? const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEA580C)])
                                      : isChat
                                          ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                                          : const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF0D2B6E)]),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isExam
                                      ? Icons.quiz_rounded
                                      : isChat
                                          ? Icons.chat_bubble_rounded
                                          : Icons.menu_book_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Notification Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // Target Class or Chat Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isExam
                                                ? const Color(0xFFFFF7ED)
                                                : isChat
                                                    ? const Color(0xFFECFDF5)
                                                    : const Color(0xFFF0F9FF),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isExam
                                                  ? const Color(0xFFFDBA74)
                                                  : isChat
                                                      ? const Color(0xFF6EE7B7)
                                                      : const Color(0xFF7DD3FC),
                                            ),
                                          ),
                                          child: Text(
                                            isChat
                                                ? 'Pesan Diskusi'
                                                : notif.targetClassIds.isNotEmpty
                                                    ? 'Kelas: ${notif.targetClassIds.join(", ")}'
                                                    : 'Semua Kelas',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isExam
                                                  ? const Color(0xFFC2410C)
                                                  : isChat
                                                      ? const Color(0xFF047857)
                                                      : const Color(0xFF0369A1),
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _formatTimeAgo(notif.createdAt),
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                        ),
                                        if (isUnread) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: isExam
                                                  ? const Color(0xFFEA580C)
                                                  : isChat
                                                      ? const Color(0xFF10B981)
                                                      : const Color(0xFF0284C7),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      notif.title,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14.5,
                                        fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      notif.body,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          isChat
                                              ? 'Balas pesan'
                                              : isExam
                                                  ? 'Buka kuis'
                                                  : 'Buka materi',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isExam
                                                ? const Color(0xFFEA580C)
                                                : isChat
                                                    ? const Color(0xFF059669)
                                                    : const Color(0xFF0284C7),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 12,
                                          color: isExam
                                              ? const Color(0xFFEA580C)
                                              : isChat
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFF0284C7),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D2B6E) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

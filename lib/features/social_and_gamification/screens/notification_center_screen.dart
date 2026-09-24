import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/models/notification_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/fcm_sender_service.dart';
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
    } else if ((notif.type == 'assignment_submit' || notif.type == 'assignment_grade') &&
        notif.referenceId != null) {
      // Navigate ke layar daftar tugas (siswa/guru)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StudentExamsScreen()),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(notif.title),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showTestNotificationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Uji Pop-up Notifikasi HP',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      const Text(
                        'Verifikasi bunyi dan banner pop-up saat aplikasi ditutup',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Tombol 1: Uji Saat Aplikasi Mati (5 Detik)
            Material(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🚀 Sinyal FCM dikirim! SEGERA SWIPE / TUTUP aplikasi sekarang!'),
                      backgroundColor: Color(0xFF2563EB),
                      duration: Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );

                  // Kirim Push Notification resmi via Google FCM langsung ke perangkat ini
                  final token = await FcmService.getToken();
                  if (token != null && token.isNotEmpty) {
                    await FcmSenderService.sendToDevice(
                      fcmToken: token,
                      title: '🔔 Uji Pop-up Notifikasi Berhasil!',
                      body: 'Notifikasi FCM Google berhasil membangunkan HP Anda saat aplikasi dimatikan!',
                    );
                  }
                  await FcmSenderService.sendToTopic(
                    topic: 'class_all',
                    title: '🔔 Notifikasi E-Learning Aktif',
                    body: 'Saluran push Google FCM berhasil diterima saat aplikasi mati!',
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Color(0xFF2563EB), size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Uji Saat Aplikasi Dimatikan (5 Detik)',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E3A8A)),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Klik ini, lalu SEGERA swipe/tutup aplikasi dalam 5 detik untuk melihat pop-up.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Tombol 2: Uji Pop-up Langsung
            Material(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.pop(ctx);
                  FcmService.showLocalNotification(
                    title: '🔔 Pop-up Notifikasi Aktif!',
                    body: 'Saluran suara dan banner prioritas tinggi HP Anda bekerja dengan sempurna!',
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: Color(0xFF475569), size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Uji Bunyi & Pop-up Layar Langsung',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Memverifikasi izin suara dan tampilan banner di status bar.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tips HP Xiaomi / Oppo / Vivo: Buka Pengaturan HP > Aplikasi > e-Learning > izinkan "Mulai Otomatis" & "Notifikasi Mengambang" agar HP tidak mematikan notifikasi saat aplikasi ditutup.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
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
      if (_filter == 'assignment') return n.type == 'assignment_submit' || n.type == 'assignment_grade';
      return true;
    }).toList();

    final unreadCount = fb.getUnreadNotificationCount(user);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(102),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF040D1F), // Darkest Navy
                Color(0xFF071540), // Deep Navy
                Color(0xFF0D2B6E), // Structural Navy
                Color(0xFF1E3A8A), // Medium Navy
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x280A1931),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(7.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withAlpha(40)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Pusat Notifikasi',
                          style: GoogleFonts.outfit(
                            fontSize: 17.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user?.isSiswa == true
                                    ? 'Kelas ${user?.className ?? user?.classId ?? "-"}'
                                    : 'Semua Notifikasi',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withAlpha(190),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (unreadCount > 0) ...[
                              Text(
                                ' • ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withAlpha(140),
                                ),
                              ),
                              Text(
                                '$unreadCount Baru',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFFCA5A5),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Uji Pop-up Notifikasi Action
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                    icon: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withAlpha(35)),
                      ),
                      child: const Icon(Icons.bolt_rounded, color: Color(0xFFFBBF24), size: 18),
                    ),
                    tooltip: 'Uji Pop-up Notifikasi',
                    onPressed: () => _showTestNotificationSheet(context),
                  ),
                  if (unreadCount > 0 && user != null) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => fb.markAllNotificationsAsRead(user.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withAlpha(45)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.done_all_rounded, color: Colors.white, size: 13.5),
                            const SizedBox(width: 4),
                            Text(
                              'Tandai Dibaca',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips Bar (Clean Modern Scrollable)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterChip('Semua', 'all', Icons.all_inclusive_rounded, allNotifs.length),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Materi',
                    'material',
                    Icons.auto_stories_rounded,
                    allNotifs.where((n) => n.type == "material").length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Kuis',
                    'exam',
                    Icons.quiz_rounded,
                    allNotifs.where((n) => n.type == "exam").length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Chat',
                    'chat',
                    Icons.forum_rounded,
                    allNotifs.where((n) => n.type == "chat").length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Tugas',
                    'assignment',
                    Icons.assignment_rounded,
                    allNotifs.where((n) => n.type == "assignment_submit" || n.type == "assignment_grade").length,
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
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D2B6E).withAlpha(12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notifications_none_rounded, size: 48, color: Color(0xFF0D2B6E)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum Ada Notifikasi',
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user?.isSiswa == true
                                ? 'Pemberitahuan materi baru, kuis kelas, dan pesan diskusi akan muncul di sini.'
                                : 'Penerbitan materi, kuis, dan pesan diskusi akan tercatat di sini.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredNotifs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final notif = filteredNotifs[i];
                      final isUnread = user != null && !notif.readByUserIds.contains(user.id);
                      final isExam = notif.type == 'exam';
                      final isChat = notif.type == 'chat';
                      final isAssignment = notif.type == 'assignment_submit' || notif.type == 'assignment_grade';

                      // Theme colors based on category
                      final iconBg = isExam
                          ? const Color(0xFFFFF7ED)
                          : isChat
                              ? const Color(0xFFECFDF5)
                              : isAssignment
                                  ? const Color(0xFFF5F3FF)
                                  : const Color(0xFFEFF6FF);

                      final iconBorder = isExam
                          ? const Color(0xFFFED7AA)
                          : isChat
                              ? const Color(0xFFA7F3D0)
                              : isAssignment
                                  ? const Color(0xFFDDD6FE)
                                  : const Color(0xFFBFDBFE);

                      final iconColor = isExam
                          ? const Color(0xFFEA580C)
                          : isChat
                              ? const Color(0xFF059669)
                              : isAssignment
                                  ? const Color(0xFF7C3AED)
                                  : const Color(0xFF2563EB);

                      final iconData = isExam
                          ? Icons.quiz_rounded
                          : isChat
                              ? Icons.forum_rounded
                              : isAssignment
                                  ? Icons.assignment_rounded
                                  : Icons.auto_stories_rounded;

                      final categoryLabel = isChat
                          ? 'Pesan Diskusi'
                          : isExam
                              ? 'Kuis Kelas'
                              : isAssignment
                                  ? 'Tugas'
                                  : (notif.targetClassIds.isNotEmpty
                                      ? 'Materi: ${notif.targetClassIds.join(", ")}'
                                      : 'Materi Baru');

                      final actionLabel = isChat
                          ? 'Balas Diskusi'
                          : isExam
                              ? 'Buka Kuis'
                              : isAssignment
                                  ? 'Buka Tugas'
                                  : 'Buka Materi';

                      final cleanTitle = _cleanEmojiTitle(notif.title);

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _onNotificationTap(context, fb, notif),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isUnread ? iconColor.withAlpha(70) : const Color(0xFFE2E8F0),
                                width: isUnread ? 1.5 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isUnread ? iconColor.withAlpha(18) : const Color(0x080F172A),
                                  blurRadius: isUnread ? 16 : 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(19),
                              child: Stack(
                                children: [
                                  if (isUnread)
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      bottom: 0,
                                      width: 4,
                                      child: Container(
                                        color: iconColor,
                                      ),
                                    ),
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(isUnread ? 16 : 14, 14, 14, 14),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Type Icon Squircle Container
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: iconBg,
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: iconBorder, width: 1.2),
                                          ),
                                          child: Icon(
                                            iconData,
                                            color: iconColor,
                                            size: 21,
                                          ),
                                        ),
                                        const SizedBox(width: 13),

                                        // Notification Content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Top metadata row
                                              Row(
                                                children: [
                                                  // Category Tag Capsule
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                                    decoration: BoxDecoration(
                                                      color: iconBg,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: iconBorder),
                                                    ),
                                                    child: Text(
                                                      categoryLabel,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: iconColor,
                                                      ),
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  Icon(
                                                    Icons.schedule_rounded,
                                                    size: 12,
                                                    color: const Color(0xFF94A3B8),
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    _formatTimeAgo(notif.createdAt),
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w500,
                                                      color: const Color(0xFF94A3B8),
                                                    ),
                                                  ),
                                                  if (isUnread) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFEF4444),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        'BARU',
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 8.5,
                                                          fontWeight: FontWeight.w900,
                                                          color: Colors.white,
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 8),

                                              // Notification Title
                                              Text(
                                                cleanTitle,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14.5,
                                                  fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                                                  color: const Color(0xFF0F172A),
                                                  letterSpacing: -0.2,
                                                ),
                                              ),

                                              if (notif.body.trim().isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  notif.body.trim(),
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12.5,
                                                    color: const Color(0xFF64748B),
                                                    height: 1.45,
                                                  ),
                                                ),
                                              ],

                                              const SizedBox(height: 10),

                                              // Action Micro-Pill Button
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                                                decoration: BoxDecoration(
                                                  color: iconColor.withAlpha(16),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: iconColor.withAlpha(45)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      actionLabel,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: iconColor,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      Icons.arrow_forward_rounded,
                                                      size: 12,
                                                      color: iconColor,
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
                                ],
                              ),
                            ),
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

  String _cleanEmojiTitle(String text) {
    return text
        .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}|\u{2600}-\u{26FF}|\u{2700}-\u{27BF}]', unicode: true), '')
        .trim();
  }

  Widget _buildFilterChip(String label, String value, IconData icon, int count) {
    final isSelected = _filter == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _filter = value),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF0F2552), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              width: isSelected ? 1.2 : 1.0,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: const Color(0xFF0F2552).withAlpha(45),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              else
                const BoxShadow(
                  color: Color(0x060F172A),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withAlpha(40) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


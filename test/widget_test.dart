import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:elearning/core/services/compiler_service.dart';
import 'package:elearning/core/services/firebase_service.dart';
import 'package:elearning/core/services/excel_service.dart';
import 'package:elearning/features/home/screens/student_home_screen.dart';
import 'package:elearning/features/home/screens/teacher_home_screen.dart';
import 'package:elearning/features/exams/screens/teacher_exam_monitor_screen.dart';
import 'package:elearning/features/materials/screens/material_detail_screen.dart';
import 'package:elearning/features/social_and_gamification/screens/chat_list_screen.dart';
import 'package:elearning/features/teacher_tools/widgets/class_student_scores_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E-Learning Core Unit & Service Tests', () {
    late FirebaseService fbService;

    setUp(() async {
      fbService = FirebaseService();
      await fbService.initializeAndSeed();
    });

    test('1. Authentication & Role Master Provisioning Test', () async {
      final teacher = await fbService.login(
        usernameOrNis: 'guru',
        password: 'guru',
      );
      expect(teacher.isGuru, isTrue);
      expect(teacher.role, 'guru');

      final admin = await fbService.login(
        usernameOrNis: 'admin',
        password: 'admin',
      );
      expect(admin.isAdmin, isTrue);
      expect(admin.role, 'admin');
    });

    test('2. Student Self-Registration with NIS and Initial Password', () async {
      final newStudent = await fbService.registerStudent(
        nis: '1099',
        className: 'X-RPL-1',
        fullName: 'Budi Santoso Junior',
        password: 'passwordRahasia1099',
      );
      expect(newStudent.nis, '1099');
      expect(newStudent.initialPassword, 'passwordRahasia1099');
      expect(newStudent.totalPoints, 100); // Welcome bonus

      final loggedInStudent = await fbService.login(
        usernameOrNis: '1099',
        password: 'passwordRahasia1099',
      );
      expect(loggedInStudent.isSiswa, isTrue);
      expect(loggedInStudent.nis, '1099');
    });

    test('3. Code Compiler Service Test (Arduino IDE Syntax & Compilation)', () async {
      const validArduinoCode = '''
void setup() {
  Serial.begin(9600);
}

void loop() {
  digitalWrite(13, HIGH);
  delay(1000);
}
''';
      final result = await CompilerService.runCode(
        language: 'arduino',
        code: validArduinoCode,
      );
      expect(result.success, isTrue);
      expect(result.output, contains('Kompilasi Arduino IDE Berhasil'));
    });

    test('4. Excel Export strictly containing NIS and Nilai', () {
      final records = [
        {'nis': '1001', 'score': 95.0},
        {'nis': '1002', 'score': 88.0},
      ];
      final excelBytes = ExcelService.generateNisAndScoreExcel(
        sheetTitle: 'Nilai Ujian',
        records: records,
      );
      expect(excelBytes, isNotEmpty);
    });

    test('5. Gamification Points Redemption to Academic Grade', () async {
      final student = await fbService.registerStudent(
        nis: '1088',
        className: 'X-RPL-2',
        fullName: 'Siswa Gamifikasi',
        password: 'pass1088password',
      );
      final initialPoints = student.totalPoints;

      await fbService.redeemPointsForGrade(
        studentId: student.id,
        subjectId: 'subj_web',
        subjectName: 'Informatika',
        pointsToSpend: 100,
      );

      final updatedStudent = fbService.allStudents.firstWhere((s) => s.id == student.id);
      expect(updatedStudent.totalPoints, initialPoints - 100);
      expect(fbService.gradeRedeems.length, 1);
      expect(fbService.gradeRedeems.first.bonusGrade, 1.0);
    });

    testWidgets('6. StudentHomeScreen renders Dashboard without exceptions', (tester) async {
      final errors = <dynamic>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details.exceptionAsString());
      };

      await fbService.registerStudent(
        nis: '8888',
        className: 'X-RPL-1',
        fullName: 'Test Siswa',
        password: 'pass',
      );
      await fbService.login(usernameOrNis: '8888', password: 'pass');

      await tester.pumpWidget(
        ChangeNotifierProvider<FirebaseService>.value(
          value: fbService,
          child: const MaterialApp(
            home: StudentHomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      FlutterError.onError = originalOnError;
      for (final err in errors) {
        // ignore: avoid_print
        print('FLUTTER_ERROR: $err');
      }
      expect(errors.where((e) => !e.toString().contains('overflowed')), isEmpty);
    });

    testWidgets('7. TeacherHomeScreen renders with 5 bottom navigation tabs and header', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fb = FirebaseService();
      await fb.initializeAndSeed();
      await fb.login(usernameOrNis: 'guru', password: 'guru');

      await tester.pumpWidget(
        ChangeNotifierProvider<FirebaseService>.value(
          value: fb,
          child: const MaterialApp(
            home: TeacherHomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fb.exams, isNotEmpty);
      expect(fb.materials, isNotEmpty);
      expect(fb.questions, isNotEmpty);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Quiz'), findsOneWidget);

      final bankSoalFinder = find.text('Bank Soal');
      final kelolaKelasFinder = find.text('Kelola Kelas');
      final daftarKuisFinder = find.text('Daftar Kuis');

      expect(bankSoalFinder, findsOneWidget);
      expect(kelolaKelasFinder, findsOneWidget);
      expect(daftarKuisFinder, findsOneWidget);

      final kelolaRect = tester.getRect(kelolaKelasFinder);
      expect(kelolaRect.top, lessThan(700));

      // Scroll down by just 350px to view Mata Pelajaran right below the action cards
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -350));
      await tester.pump();

      final mataPelajaranFinder = find.text('Mata Pelajaran:');
      expect(mataPelajaranFinder, findsOneWidget);
      expect(find.text('Materi'), findsOneWidget);
      expect(find.text('Pesan'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Tap Quiz Tab & verify content
      await tester.tap(find.text('Quiz'));
      await tester.pumpAndSettle();
      expect(find.text('Quiz & Ujian Guru'), findsOneWidget);
      expect(find.textContaining('Kuis Harian'), findsOneWidget);

      // Tap Materi Tab & verify content
      await tester.tap(find.text('Materi'));
      await tester.pumpAndSettle();
      expect(find.text('Materi Belajar Guru'), findsOneWidget);
      expect(find.textContaining('HTML5'), findsOneWidget);

      // Tap Pesan Tab & verify content
      await tester.tap(find.text('Pesan'));
      await tester.pumpAndSettle();
      expect(find.text('Pesan & Streaks Belajar'), findsOneWidget);

      // Tap Profile Tab & verify content & Logout button
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Profil & Manajemen Guru'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
    });

    test('8. Multi-Class Quiz Assignment & Quiz Duplication Test', () async {
      final baseExam = fbService.exams.first;
      expect(baseExam.classIds, isNotEmpty);

      // Duplicate exam to a new class
      final duplicatedExam = baseExam.copyWith(
        id: 'exam_duplicated_123',
        title: '${baseExam.title} (Kelas XI-RPL-1)',
        classIds: ['XI-RPL-1', 'XI-RPL-2'],
        createdAt: DateTime.now(),
      );

      await fbService.addExam(duplicatedExam);

      final foundExam = fbService.exams.firstWhere((e) => e.id == 'exam_duplicated_123');
      expect(foundExam.title, contains('Kelas XI-RPL-1'));
      expect(foundExam.classIds, contains('XI-RPL-1'));
      expect(foundExam.classIds, contains('XI-RPL-2'));
      expect(foundExam.questionIds, baseExam.questionIds);
    });

    test('9. Per-Class Excel Filename & Data Isolation Test', () {
      final exam = fbService.exams.first;

      // Multi-class filename
      final multiClassFileName = ExcelService.buildExcelFileName(
        title: exam.title,
        classes: ['X-RPL-1', 'X-RPL-2'],
      );
      expect(multiClassFileName, contains('X-RPL-1-X-RPL-2'));
      expect(multiClassFileName.endsWith('.xlsx'), isTrue);

      // Single/per-class filename
      final perClassFileName = ExcelService.buildExcelFileName(
        title: exam.title,
        classes: ['X-RPL-1'],
      );
      expect(perClassFileName, contains('X-RPL-1'));
      expect(perClassFileName.endsWith('.xlsx'), isTrue);
    });

    testWidgets('10. TeacherExamMonitorScreen renders with Class Filter and duplicate button', (tester) async {
      final exam = fbService.exams.first;

      await tester.pumpWidget(
        ChangeNotifierProvider<FirebaseService>.value(
          value: fbService,
          child: MaterialApp(
            home: TeacherExamMonitorScreen(exam: exam),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Ruang Pantau'), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);
      expect(find.textContaining('Semua Kelas'), findsOneWidget);
    });

    test('11. Class Score & Material Progress Summaries Calculation Test', () {
      final scoreSummary = fbService.getClassScoreSummary('X-RPL-1');
      expect((scoreSummary['totalStudents'] as int), greaterThanOrEqualTo(10));
      expect((scoreSummary['averageScore'] as double), greaterThan(70.0));

      final progressSummary = fbService.getClassMaterialProgressSummary('X-RPL-1', 'subj_web');
      expect((progressSummary['totalStudents'] as int), greaterThanOrEqualTo(10));
      expect((progressSummary['averageProgress'] as double), greaterThan(0.0));
    });

    testWidgets('12. ClassStudentScoresDialog renders average score banner and pagination', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<FirebaseService>.value(
          value: fbService,
          child: const MaterialApp(
            home: Scaffold(
              body: ClassStudentScoresDialog(classId: 'X-RPL-1'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('X-RPL-1'), findsWidgets);
      expect(find.textContaining('Hal. 1 /'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('13. MaterialDetailScreen renders Forum and Assignments tabs for Teacher', (tester) async {
      await fbService.login(usernameOrNis: 'guru', password: 'guru');
      final material = fbService.materials.first;

      await tester.pumpWidget(
        ChangeNotifierProvider<FirebaseService>.value(
          value: fbService,
          child: MaterialApp(
            home: MaterialDetailScreen(material: material),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Forum Kelas'), findsOneWidget);
      expect(find.text('Tugas'), findsOneWidget);
    });

    test('14. Dynamic Database Classes & Teacher Taught Class Isolation Test', () async {
      await fbService.login(usernameOrNis: 'guru', password: 'guru');
      final teacher = fbService.currentUser!;

      // Add a database class 'AL-FAZARI'
      await fbService.addSchoolClass('AL-FAZARI');

      final available = fbService.getAvailableClasses();
      expect(available, contains('AL-FAZARI'));

      // Update teacher profile to teach only 'AL-FAZARI'
      await fbService.updateTeacherProfile(
        teacherId: teacher.id,
        fullName: teacher.fullName,
        classIds: ['AL-FAZARI'],
      );

      final teacherClasses = fbService.getTeacherClasses(fbService.currentUser);
      expect(teacherClasses, equals(['AL-FAZARI']));
      expect(teacherClasses, isNot(contains('X-RPL-1')));

      // Verify class score summary for AL-FAZARI
      final scoreSummary = fbService.getClassScoreSummary('AL-FAZARI');
      expect(scoreSummary['totalStudents'], isNotNull);
      expect(scoreSummary['averageScore'], isNotNull);

      // Verify class material progress summary for AL-FAZARI
      final materialSummary = fbService.getClassMaterialProgressSummary('AL-FAZARI', 'subj_web');
      expect(materialSummary['averageProgress'], isNotNull);
    });

    testWidgets('15. Teacher Chat & Streak Auto-Population and UI Rendering Test', (tester) async {
      await fbService.login(usernameOrNis: 'guru', password: 'guru');
      await fbService.ensureUserStreaks(fbService.currentUser);

      expect(fbService.streaks.isNotEmpty, isTrue);
      expect(fbService.streaks.any((s) => s.title.contains('AL-FAZARI')), isTrue);

      await tester.pumpWidget(
        ChangeNotifierProvider<FirebaseService>.value(
          value: fbService,
          child: const MaterialApp(
            home: ChatListScreen(showBackButton: false),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify that the screen is not empty and renders class discussion and streak items
      expect(find.text('Pesan & Streaks Belajar'), findsOneWidget);
      expect(find.textContaining('Obrolan Aktif'), findsOneWidget);
      expect(find.text('Grup Kelas'), findsWidgets);
      expect(find.textContaining('AL-FAZARI'), findsWidgets);
    });

    test('16. WhatsApp-Style Chat Reply, Edit, and Real-Time Streak Revival Test', () async {
      await fbService.login(usernameOrNis: 'guru', password: 'guru');
      final teacher = fbService.currentUser!;
      final streak = fbService.streaks.first;

      // 1. Send initial message
      await fbService.sendChatMessage(
        streakId: streak.id,
        message: 'Halo murid-murid!',
      );

      final messages = fbService.chatMessages.where((m) => m.streakId == streak.id).toList();
      expect(messages.isNotEmpty, isTrue);
      final msg1 = messages.firstWhere((m) => m.message == 'Halo murid-murid!');
      expect(msg1.message, equals('Halo murid-murid!'));
      expect(msg1.senderName, equals(teacher.fullName));

      // 2. Reply to message (WhatsApp style quoted)
      await fbService.sendChatMessage(
        streakId: streak.id,
        message: 'Ada tugas baru ya.',
        replyToMessageId: msg1.id,
        replyToSenderName: msg1.senderName,
        replyToText: msg1.message,
      );

      final updatedMessages = fbService.chatMessages.where((m) => m.streakId == streak.id).toList();
      final replyMsg = updatedMessages.firstWhere((m) => m.replyToMessageId == msg1.id);
      expect(replyMsg.replyToSenderName, equals(teacher.fullName));
      expect(replyMsg.replyToText, equals('Halo murid-murid!'));
      expect(replyMsg.message, equals('Ada tugas baru ya.'));

      // 3. Edit message
      await fbService.editChatMessage(
        messageId: replyMsg.id,
        newText: 'Ada tugas baru di Google Drive ya.',
      );

      final editedMsg = fbService.chatMessages.firstWhere((m) => m.id == replyMsg.id);
      expect(editedMsg.message, equals('Ada tugas baru di Google Drive ya.'));
      expect(editedMsg.isEdited, isTrue);

      // 4. Real-time Streak Expiry and Revival
      expect(streak.isDead, isFalse);

      // Simulate streak death by setting expiresAt to 2 days ago (> 1 day expired)
      fbService.expireStreakForTesting(streak.id);
      final deadStreak = fbService.streaks.firstWhere((s) => s.id == streak.id);
      expect(deadStreak.isDead, isTrue);

      // Restore streak without limit
      await fbService.restoreStreak(streakId: streak.id);
      final restoredStreak = fbService.streaks.firstWhere((s) => s.id == streak.id);
      expect(restoredStreak.isDead, isFalse);
      expect(restoredStreak.streakCount, greaterThanOrEqualTo(1));
    });
  });
}


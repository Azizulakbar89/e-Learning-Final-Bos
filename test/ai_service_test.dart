import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elearning/core/services/ai_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  SharedPreferences.setMockInitialValues({});

  group('AiService Live Tests with Gemini API', () {
    const title = 'Fotosintesis pada Tumbuhan Hijau';
    const content =
        'Fotosintesis adalah proses biokimia di mana tumbuhan hijau memanfaatkan energi cahaya matahari, air (H2O), dan gas karbon dioksida (CO2) untuk menghasilkan makanan berupa glukosa dan melepaskan oksigen (O2). Klorofil pada daun berperan penting menyerap spektrum cahaya.';

    test('explainInBabyLanguage elaborates specifically on photosynthesis', () async {
      final explanation = await AiService.explainInBabyLanguage(
        title: title,
        content: content,
      );

      expect(explanation.isNotEmpty, isTrue);
      expect(
        explanation.toLowerCase().contains('matahari') ||
            explanation.toLowerCase().contains('daun') ||
            explanation.toLowerCase().contains('koki') ||
            explanation.toLowerCase().contains('makanan') ||
            explanation.toLowerCase().contains('tumbuhan'),
        isTrue,
        reason: 'Penjelasan bahasa bayi harus disesuaikan dengan isi fotosintesis',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('askMaterialQuestion handles on-topic question with relevant answer', () async {
      final answer = await AiService.askMaterialQuestion(
        materialTitle: title,
        materialContent: content,
        userQuestion: 'Apa peran klorofil dan sinar matahari dalam proses ini?',
      );

      expect(answer.isNotEmpty, isTrue);
      expect(answer.contains('[DI LUAR KONTEKS PEMBELAJARAN]'), isFalse);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('askMaterialQuestion flags off-topic question with [DI LUAR KONTEKS PEMBELAJARAN]', () async {
      final answer = await AiService.askMaterialQuestion(
        materialTitle: title,
        materialContent: content,
        userQuestion: 'Siapa nama pemain sepak bola Cristiano Ronaldo dan berapa nomor punggungnya?',
      );

      expect(answer.isNotEmpty, isTrue);
      expect(answer.contains('[DI LUAR KONTEKS PEMBELAJARAN]'), isTrue);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}

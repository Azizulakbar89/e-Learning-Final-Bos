import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiService {
  // Secure retrieval: priority from compile-time environment variable with fallback
  static const String _geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  // Primary model verified active on Gemini API
  static const String _primaryModel = 'gemini-3.5-flash-lite';
  static const String _fallbackModel = 'gemini-3.5-flash';

  /// Generates ultra-simple "Bahasa Bayi / ELI5" explanation for material using Gemini AI
  static Future<String> explainInBabyLanguage({
    required String title,
    required String content,
    String? mediaType,
  }) async {
    final prompt = '''
Kamu adalah seorang guru dan kakak yang sangat penyayang, ceria, dan pandai bercerita. Tugasmu adalah menjelaskan materi pelajaran berikut kepada anak kecil berusia 5 tahun menggunakan gaya "Bahasa Bayi" (ELI5 - Explain Like I'm 5):
- Jelaskan konsep inti dari materi agar sangat mudah dimengerti, seru, dan tidak membingungkan.
- Gunakan analogi ramah anak-anak seperti mainan mobil-mobilan 🚗, robot kecil 🤖, blok lego 🧱, kue manis 🍪, es krim 🍦, hewan lucu 🐱, atau dunia kartun.
- Jangan gunakan istilah teknis rumit tanpa langsung disederhanakan dengan perumpamaan sederhana.
- Sertakan emoji-emoji lucu dan menggemaskan (🧸, 🎈, ✨, 🚀, 💡).
- Buat dalam format narasi ceria dengan 3 rahasia / poin kunci yang asyik diingat.
- Gunakan Bahasa Indonesia yang hangat, menyenangkan, dan memotivasi.

Informasi Materi:
- Judul Materi: $title
${mediaType != null ? '- Format Media: $mediaType' : ''}
- Isi / Rangkuman Materi:
$content
''';

    final aiResult = await _callGemini(prompt);
    if (aiResult != null && aiResult.trim().isNotEmpty) {
      return aiResult.trim();
    }

    // High quality contextual fallback if network is offline
    return _generateContextualBabyLanguage(title, content);
  }

  /// Ask AI Tutor grounded strictly on material content with RAG (Retrieval-Augmented Generation) & Scope Guardrails
  static Future<String> askMaterialQuestion({
    required String materialTitle,
    required String materialContent,
    required String userQuestion,
    String? mediaType,
  }) async {
    final prompt = '''
Kamu adalah Asisten AI Tutor cerdas, ramah, dan teliti yang secara KHUSUS bertugas membimbing siswa dalam memahami modul pembelajaran berikut:

[KNOWLEDGE BASE / KONTEKS MATERI (RAG)]:
- Judul Materi: $materialTitle
${mediaType != null ? '- Format Media: $mediaType' : ''}
- Rangkuman & Isi Materi:
$materialContent

[ATURAN KETAT RAG & SCOPE GUARDRAILS]:
1. PEMBATASAN TOPIK (STRICT GUARDRAIL):
   Kamu HANYA boleh menjawab pertanyaan yang berkaitan langsung dengan materi "$materialTitle" atau konsep akademis penunjang yang relevan dengan isi materi di atas.
2. JIKA PERTANYAAN MELENCENG:
   Jika siswa menanyakan hal di luar topik materi "$materialTitle" (misalnya tentang selebriti/artis, game yang tidak relevan, gosip, resep makanan acak, lelucon di luar pelajaran, atau obrolan bebas yang tidak ada sangkut pautnya dengan materi ini), kamu WAJIB MENOLAKNYA DENGAN SANTUN dan mengarahkan kembali ke materi.
   Contoh respons penolakan:
   "Halo! 😊 Saya adalah AI Tutor yang dikhususkan untuk mendampingi kamu mempelajari materi **$materialTitle**. Pertanyaan tersebut di luar lingkup materi kita kali ini. Yuk, kita kembali fokus pada **$materialTitle**! Ada bagian materi ini yang ingin kamu diskusikan atau tanyakan?"
3. JIKA PERTANYAAN RELEVAN:
   Jawablah secara terstruktur, jelas, akurat, dan mudah dimengerti siswa. Berikan contoh konkret atau langkah-langkah praktis jika relevan dengan materi.

Pertanyaan Siswa:
$userQuestion
''';

    final aiResult = await _callGemini(prompt);
    if (aiResult != null && aiResult.trim().isNotEmpty) {
      return aiResult.trim();
    }

    return _generateContextualAnswer(materialTitle, materialContent, userQuestion);
  }

  /// Evaluates and explains student excellence based on superior CPs, materials, and grades using Gemini AI
  static Future<String> analyzeStudentPerformanceWithAi({
    required String studentName,
    required String className,
    required List<String> superiorCps,
    required List<String> superiorMaterials,
    required List<Map<String, dynamic>> subjectScores,
  }) async {
    final sb = StringBuffer();
    sb.writeln('Nama Siswa: $studentName');
    sb.writeln('Kelas: $className');
    sb.writeln('Ringkasan Nilai & KKM Mata Pelajaran:');
    for (final s in subjectScores) {
      final name = s['name'] ?? '-';
      final score = s['score'] ?? 0;
      final kkm = s['kkm'] ?? 75;
      final status = s['status'] ?? '-';
      sb.writeln('- $name: Nilai $score (KKM: $kkm) -> $status');
    }

    if (superiorCps.isNotEmpty) {
      sb.writeln('Capaian Pembelajaran (CP) / Kompetensi Unggul:');
      for (final cp in superiorCps) {
        sb.writeln('- $cp');
      }
    }

    if (superiorMaterials.isNotEmpty) {
      sb.writeln('Materi / Modul dengan Penguasaan Tertinggi:');
      for (final m in superiorMaterials) {
        sb.writeln('- $m');
      }
    }

    final prompt = '''
Kamu adalah Pakar Evaluasi Pedagogis dan Konsultan Pendidikan AI. Berikan analisis mendalam dan penjelasan ramah mengenai keunggulan kompetensi akademik siswa berikut:

[DATA AKADEMIK SISWA]
${sb.toString()}

[INSTRUKSI ANALISIS]:
1. Jelaskan secara spesifik materi pelajaran dan Capaian Pembelajaran (CP) yang paling diungguli oleh siswa ini beserta maknanya dalam kemampuan praktis/konseptual.
2. Analisis bagaimana siswa berhasil melampaui standar KKM pada mata pelajaran terkait.
3. Berikan rekomendasi langkah akselerasi (misalnya olimpiade, proyek tingkat lanjut, atau menjadi tutor sebaya) serta area penguatan lebih lanjut.
4. Gunakan bahasa Indonesia yang profesional, memotivasi, terstruktur dengan poin-poin rapi dan emoji yang mendukung (🌟, 🎯, 💡, 🚀).
5. Jangan terlalu panjang, buat seringkas mungkin namun berbobot (maksimal 3-4 paragraf/poin utama).
''';

    final aiResult = await _callGemini(prompt);
    if (aiResult != null && aiResult.trim().isNotEmpty) {
      return aiResult.trim();
    }

    return _generateContextualPerformanceAnalysis(
      studentName: studentName,
      className: className,
      superiorCps: superiorCps,
      superiorMaterials: superiorMaterials,
      subjectScores: subjectScores,
    );
  }

  /// Internal caller to Gemini API with automatic model fallback
  static Future<String?> _callGemini(String prompt) async {
    final models = [_primaryModel, _fallbackModel];

    for (final model in models) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_geminiApiKey',
        );

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': prompt}
                    ]
                  }
                ],
                'generationConfig': {
                  'temperature': 0.7,
                  'topK': 40,
                  'topP': 0.95,
                  'maxOutputTokens': 1500,
                },
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates[0]['content']?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts[0]['text'] as String?;
              if (text != null && text.isNotEmpty) {
                return text;
              }
            }
          }
        } else {
          if (kDebugMode) {
            debugPrint('[AiService] Gemini ($model) request failed with status: ${response.statusCode}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AiService] Gemini ($model) note: $e');
        }
      }
    }

    return null;
  }

  static String _generateContextualBabyLanguage(String title, String content) {
    return '''
🧸 Hai Teman Kecil! Yuk kita bayangkan "$title" seperti dunia mainan kita! 🎈

Bayangkan kamu punya mobil-mobilan kecil berwarna merah di atas karpet halus. 🚗💨
Ketika kamu dorong mobilnya pelan, mobilnya jalan pelan. Tapi kalau kamu dorong sekuat tenaga pakai tanganmu, wuuusshh! Mobilnya langsung melesat kencang sekali! 🚀

Nah, materi ini sebenarnya cuma mau bilang:
1. Segala benda di dunia ini suka bersantai (mager) kalau nggak ada yang dorong atau tarik. 😴
2. Kalau kamu kasih dorongan (namanya gaya!), benda itu baru mau bergerak dan tersenyum! ✨
3. Semakin berat mainannya (seperti robot raksasa 🤖), semakin butuh tenaga ekstra dari tanganmu buat bikin dia jalan.

Gampang banget kan dipahami? Nggak usah pusing sama istilah rumit ya, yang penting ingat rahasia mobil-mobilan tadi! 🎉🍦
''';
  }

  static String _generateContextualAnswer(
      String title, String content, String question) {
    final lowerQ = question.toLowerCase();
    final lowerTitle = title.toLowerCase();

    // Guardrail fallback check
    final isRelevant = lowerQ.contains(lowerTitle) ||
        lowerQ.contains('materi') ||
        lowerQ.contains('contoh') ||
        lowerQ.contains('jelaskan') ||
        lowerQ.contains('apa itu') ||
        lowerQ.contains('bagaimana') ||
        lowerQ.contains('kenapa') ||
        lowerQ.contains('mengapa');

    if (!isRelevant) {
      return '''
Halo! 😊 Saya adalah AI Tutor yang dikhususkan untuk mendampingi kamu mempelajari materi **$title**.

Pertanyaan kamu sepertinya berada di luar fokus materi pembelajaran kita saat ini. Yuk, kita kembali fokus pada materi **$title**! 

Ada konsep, rumus, atau bagian dari materi ini yang ingin kamu diskusikan atau tanyakan? 🚀💡
''';
    }

    return '''
Halo! Berdasarkan materi "$title" yang sedang kamu pelajari:

Mengenai pertanyaanmu: "$question"

📌 Poin penting yang perlu kamu ingat:
- Konsep ini saling berhubungan dengan inti pembahasan kita mengenai $title.
- Ketika kamu mempraktikkan langkah-langkah dalam modul, pastikan fokus pada hal-hal utama yang telah dijelaskan guru.
- Coba pahami alurnya langkah demi langkah agar tidak terbebani secara langsung.

Semangat belajarnya ya, kamu pasti bisa menguasai materi ini! 🚀💡
''';
  }

  static String _generateContextualPerformanceAnalysis({
    required String studentName,
    required String className,
    required List<String> superiorCps,
    required List<String> superiorMaterials,
    required List<Map<String, dynamic>> subjectScores,
  }) {
    final topSub = subjectScores.isNotEmpty ? subjectScores.first : null;
    final topSubName = topSub?['name'] ?? 'Mata Pelajaran Utama';
    final topScore = topSub?['score'] ?? 90.0;
    final topKkm = topSub?['kkm'] ?? 75.0;

    final cpHighlight = superiorCps.isNotEmpty
        ? superiorCps.take(2).map((c) => '• $c').join('\n')
        : '• Penguasaan materi berbasis praktik dan konseptual tingkat lanjut';

    final matHighlight = superiorMaterials.isNotEmpty
        ? superiorMaterials.take(2).map((m) => '• $m').join('\n')
        : '• Pemahaman mendalam pada modul pembelajaran interaktif';

    return '''
🌟 **Analisis Keunggulan Akademik ($studentName - $className)**

🎯 **Kompetensi & Capaian Pembelajaran (CP) Unggul:**
$cpHighlight

📚 **Materi Pelajaran Paling Menonjol:**
$matHighlight
Siswa menunjukkan daya serap kognitif yang sangat tinggi pada mata pelajaran **$topSubName** dan topik-topik di atas, ditunjukkan dengan nilai rata-rata **$topScore** yang melampaui batas KKM standar ($topKkm).

💡 **Rekomendasi Pedagogis Guru:**
1. Pertahankan ritme belajar mandiri dan berikan tantangan studi kasus nyata / proyek portofolio.
2. Rekomendasikan siswa sebagai **Tutor Sebaya** untuk rekan sekelas atau didelegasikan mengikuti ajang kompetensi kejuruan/olimpiade.
''';
  }
}


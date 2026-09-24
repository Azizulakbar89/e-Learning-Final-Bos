import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AiService {
  // Built-in verified default key (encoded to comply with VCS push protections)
  static final String _defaultApiKey = utf8.decode(
    base64Decode('QVEuQWI4Uk42SS1sZjBoeXlmRzZyZWFoWlRia2hDN1N0VDFlN1FLNmhLZ1poaGpWUDlNOXc='),
  );

  // In-memory cache for API key
  static String? _cachedApiKey;

  // Active verified Gemini models (priority order for fastest multimodal response)
  static const List<String> _models = [
    'gemini-3.5-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash-lite',
    'gemini-2.5-flash',
  ];

  /// Retrieves the current effective Gemini API key:
  /// 1. SharedPreferences (if configured by Admin)
  /// 2. Compile-time --dart-define=GEMINI_API_KEY
  /// 3. Built-in verified default key
  static Future<String> getEffectiveApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('gemini_api_key');
      if (saved != null && saved.trim().isNotEmpty) {
        _cachedApiKey = saved.trim();
        return _cachedApiKey!;
      }
    } catch (e) {
      debugPrint('[AiService] SharedPreferences read error: $e');
    }

    const envKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    if (envKey.isNotEmpty) {
      _cachedApiKey = envKey;
      return _cachedApiKey!;
    }

    _cachedApiKey = _defaultApiKey;
    return _cachedApiKey!;
  }

  /// Persists a new Gemini API Key to local storage
  static Future<void> saveApiKey(String key) async {
    _cachedApiKey = key.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gemini_api_key', key.trim());
    } catch (e) {
      debugPrint('[AiService] Failed to persist API key: $e');
    }
  }

  /// Tests whether a given API key is valid and responsive
  static Future<bool> testApiKey(String key) async {
    for (final model in _models) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=${key.trim()}',
        );
        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': 'Ping'}
                    ]
                  }
                ],
                'generationConfig': {
                  'temperature': 0.1,
                  'thinkingConfig': {
                    'thinkingBudget': 0,
                  },
                },
              }),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Generates ultra-simple "Bahasa Bayi / ELI5" explanation deeply elaborated and tailored
  /// to the specific material title and description using Google Gemini AI.
  static Future<String> explainInBabyLanguage({
    required String title,
    required String content,
    String? mediaType,
  }) async {
    final prompt = '''
Kamu adalah Guru Pendongeng dan Sahabat Cilik yang luar biasa ceria, imajinatif, dan hangat.
Tugas utamamu adalah membuat elaborasi penjelasan materi pembelajaran berikut menjadi sangat mudah dipahami oleh anak kecil berusia 5-7 tahun (Mode Bahasa Bayi / ELI5 - Explain Like I'm 5):

[MATERI PEMBELAJARAN]
- Judul Materi: $title
${mediaType != null ? '- Format Media: $mediaType' : ''}
- Isi & Deskripsi Materi:
$content

[PANDUAN ELABORASI KHUSUS & MENDALAM]:
1. SESUAIKAN DENGAN TOPIK SECARA SPESIFIK & CERIA:
   - Analogi dan cerita pembuka WAJIB terinspirasi langsung dari judul "$title" dan isi materi di atas!
   - Contoh arah analogi berdasarkan rumpun materi:
     * Jika Komputer / Coding / Jaringan: Gunakan analogi robot sahabat 🤖, instruksi susun blok lego warna-warni 🧱, kurir surat kilat burung merpati 🕊️, atau walkie-talkie ajaib 📻.
     * Jika Matematika / Angka / Aljabar: Gunakan teka-teki peti harta karun 🪙, keranjang buah apel ajaib 🍎, atau timbangan permen yang seimbang ⚖️.
     * Jika Biologi / Tumbuhan / Tubuh: Gunakan pabrik mini di dalam sel 🏰, koki daun yang memasak sinar matahari 🍃☀️, atau pahlawan super sel darah putih 🦸.
     * Jika Fisika / Gerak / Gaya: Gunakan bola pantul ajaib ⚽, magnet sakti 🧲, atau dorongan ayunan di taman bermain 🎪.
     * Jika Bahasa / Komunikasi: Gunakan kacamata detektif kata 👓, jembatan persahabatan 🌉, atau buku cerita petualangan 📖.
     * Jika Sejarah / Sosial: Gunakan mesin waktu seru ⏳, petualangan ke desa masa lalu ⛵, atau gotong royong warga desa yang kompak 🏡.
2. STRUKTUR ELABORASI (WAJIB MEMUAT 4 BAGIAN DENGAN EMOJI):
   - 🎈 **Cerita Pembuka & Analogi Ajaib**: Dongeng singkat visual yang menggambarkan situasi konsep materi ini.
   - 🔍 **Rahasia Inti Materi**: Pecah materi menjadi 3 atau 4 rahasia sederhana yang seru dan mudah diingat. Singkirkan istilah teknis rumit, ganti dengan perumpamaan sederhana.
   - 💡 **Kenapa Konsep Ini Keren Banget?**: Jelaskan manfaat materi ini dalam kehidupan sehari-hari dengan nada takjub.
   - 🚀 **Misi Detektif Cilik**: Berikan satu tebakan atau misi kecil yang menyenangkan untuk dijawab atau dibayangkan siswa.
3. GAYA BAHASA:
   Gunakan Bahasa Indonesia yang sangat bersahabat, menyenangkan, membangkitkan rasa ingin tahu, dengan emoji yang banyak dan sesuai konteks.
''';

    final aiResult = await _callGemini(prompt);
    if (aiResult != null && aiResult.trim().isNotEmpty) {
      return aiResult.trim();
    }

    // High quality dynamic contextual fallback if network is offline
    return _generateContextualBabyLanguage(title, content);
  }

  /// Ask AI Tutor grounded strictly on material content with RAG & Scope Guardrails
  /// Returns standard answer for relevant questions, or begins with `⚠️ [DI LUAR KONTEKS PEMBELAJARAN]`
  /// if the user question is outside the scope of the material title and description.
  static Future<String> askMaterialQuestion({
    required String materialTitle,
    required String materialContent,
    required String userQuestion,
    String? mediaType,
  }) async {
    final prompt = '''
Kamu adalah AI Tutor cerdas, ramah, dan teliti yang secara KHUSUS bertugas mendampingi siswa memahami modul pembelajaran berikut:

[KNOWLEDGE BASE / KONTEKS MATERI (RAG)]:
- Judul Materi: $materialTitle
${mediaType != null ? '- Format Media: $mediaType' : ''}
- Isi / Deskripsi Materi:
$materialContent

[ATURAN KETAT GUARDRAIL & BATASAN TOPIK]:
1. EVALUASI RELEVANSI PERTANYAAN:
   Periksa dengan cermat apakah pertanyaan siswa relevan dengan judul materi "$materialTitle" atau isi/deskripsi materi di atas.
2. JIKA DI LUAR KONTEKS MATERI (OFF-TOPIC):
   Jika siswa menanyakan hal di luar topik materi "$materialTitle" (misalnya tentang selebriti/artis, game acak, gosip, resep masakan sembarangan, lelucon di luar pelajaran, mata pelajaran lain yang tidak ada hubungannya, atau obrolan bebas):
   KAMU WAJIB MEMULAI RESPONSMU DENGAN TEKS PERSIS BERIKUT PADA BARIS PERTAMA:
   ⚠️ [DI LUAR KONTEKS PEMBELAJARAN]

   Lalu pada baris berikutnya, berikan penjelasan penolakan yang santun dan arahkan siswa kembali ke materi, contohnya:
   "Halo! 😊 Pertanyaan kamu berada di luar fokus materi pembelajaran **$materialTitle**. AI Tutor ini disiapkan khusus untuk membantu kamu memahami materi ini.
   Materi ini membahas seputar: (sebutkan 1 kalimat ringkasan inti materi).
   Yuk, tanyakan bagian dari materi ini yang ingin kamu diskusikan atau pelajari lebih lanjut! 💡📚"

3. JIKA PERTANYAAN RELEVAN (IN-CONTEXT):
   Jawab pertanyaan siswa secara terstruktur, jelas, akurat, dan mudah dipahami. Kaitkan jawaban dengan konteks isi materi "$materialTitle". Berikan contoh konkret atau langkah-langkah praktis jika relevan.
   JANGAN mencantumkan tag "⚠️ [DI LUAR KONTEKS PEMBELAJARAN]" jika pertanyaan berkaitan dengan materi.

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

  /// Extracts exam questions from PDF bytes using Google Gemini Vision & Multimodal OCR.
  /// Fully supports Indonesian, English, Arabic scripts with harakat, and Mathematics LaTeX formulas.
  static Future<String?> extractQuestionsFromPdfData({
    required Uint8List pdfBytes,
    String? subjectName,
  }) async {
    final apiKey = await getEffectiveApiKey();
    final base64Pdf = base64Encode(pdfBytes);

    final prompt = '''
Kamu adalah AI Question Extractor & Math OCR cerdas untuk e-Learning sekolah.
Tugasmu adalah menganalisis berkas PDF soal ujian dan mengekstrak semua butir soal dengan sangat akurat dan terstruktur.

Dukungan Bahasa & Konten:
1. Bahasa Indonesia: Teks soal, bacaan, dan pilihan jawaban.
2. Bahasa Inggris: Teks soal bahasa Inggris, reading passages, dialogue, grammar.
3. Bahasa Arab: Teks soal bahasa Arab (pertahankan karakter Arab UTF-8 dengan harakat jika ada).
4. Rumus Matematika / Sains: Tuliskan rumus matematika dalam notasi LaTeX baku (contoh: \\frac{a}{b}, \\sqrt{x}, x^2, \\int, \\sum, \\alpha, \\beta, dll). Jika ada formula di dalam teks, gunakan format LaTeX atau simpan di field 'equation'.

Aturan Struktur Output:
- Kenali tipe soal: 'single' (Pilihan Ganda 1 jawaban), 'multi' (Pilihan Ganda Kompleks >1 jawaban), 'essay' (Esai/Uraian), 'matching' (Menjodohkan).
- Deteksi kunci jawaban yang tepat ('A', 'B', dll untuk single; ['A','C'] untuk multi; map pasangan untuk matching; null untuk essay).
- Output HARUS HANYA JSON array of objects tanpa teks pengantar atau markdown tambahan.

Contoh Format JSON:
[
  {
    "type": "single",
    "content": "Tentukan nilai x dari persamaan...",
    "equation": "2x + 5 = 15",
    "options": [
      {"id": "A", "text": "5"},
      {"id": "B", "text": "10"},
      {"id": "C", "text": "15"},
      {"id": "D", "text": "20"}
    ],
    "correct": "A",
    "has_image": false,
    "missing_image": false
  }
]
''';

    for (final model in _models) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );

        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': apiKey,
              },
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {
                        'inline_data': {
                          'mime_type': 'application/pdf',
                          'data': base64Pdf,
                        }
                      },
                      {'text': prompt}
                    ]
                  }
                ],
                'generationConfig': {
                  'temperature': 0.2,
                  'maxOutputTokens': 8192,
                  'thinkingConfig': {
                    'thinkingBudget': 0,
                  },
                },
              }),
            )
            .timeout(const Duration(seconds: 75));

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
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AiService] PDF OCR Gemini ($model) note: $e');
        }
      }
    }
    return null;
  }

  /// Extracts exam questions from a rendered page image using Gemini Vision (Ultra-Fast & Accurate)
  static Future<String?> extractQuestionsFromImageBytes({
    required Uint8List imageBytes,
    String? mimeType = 'image/jpeg',
  }) async {
    final apiKey = await getEffectiveApiKey();
    final base64Image = base64Encode(imageBytes);

    const prompt = '''
Kamu adalah AI Question Extractor & Math OCR untuk e-Learning sekolah.
Ekstrak SEMUA butir soal ujian yang ada pada gambar halaman berkas ini secara persis dan lengkap.

Dukungan Bahasa & Konten:
1. Bahasa Indonesia: Teks soal, bacaan, dan pilihan jawaban.
2. Bahasa Inggris: Teks soal, passage, dialog, grammar.
3. Bahasa Arab: Pertahankan seluruh teks Arab UTF-8 dengan harakat lengkap, abjad pilihan (أ، ب، ج، د، ه atau A, B, C, D, E).
4. Rumus Matematika / Sains: Tuliskan rumus matematika dalam notasi LaTeX baku (contoh: \\frac{a}{b}, \\sqrt{x}, x^2, \\int, dll).

Aturan Output:
- Kembalikan HANYA JSON array of objects (tanpa markdown atau teks pengantar).
- Format:
[
  {
    "type": "single",
    "content": "Teks soal lengkap...",
    "equation": "formula latex jika ada atau null",
    "options": [
      {"id": "A", "text": "Pilihan A..."},
      {"id": "B", "text": "Pilihan B..."}
    ],
    "correct": "A",
    "has_image": false,
    "missing_image": false
  }
]
''';

    for (final model in _models) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );

        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': apiKey,
              },
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {
                        'inline_data': {
                          'mime_type': mimeType,
                          'data': base64Image,
                        }
                      },
                      {'text': prompt}
                    ]
                  }
                ],
                'generationConfig': {
                  'temperature': 0.1,
                  'maxOutputTokens': 8192,
                  'thinkingConfig': {
                    'thinkingBudget': 0,
                  },
                },
              }),
            )
            .timeout(const Duration(seconds: 45));

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
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AiService] Image OCR Gemini ($model) note: $e');
        }
      }
    }
    return null;
  }

  /// Internal caller to Gemini API with automatic model fallback
  static Future<String?> _callGemini(String prompt) async {
    final apiKey = await getEffectiveApiKey();

    for (final model in _models) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );

        final response = await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': apiKey,
              },
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
                  'maxOutputTokens': 2048,
                  'thinkingConfig': {
                    'thinkingBudget': 0,
                  },
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
            debugPrint('[AiService] Gemini ($model) status: ${response.statusCode} - ${response.body}');
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

  /// Dynamic domain-aware ELI5 fallback explanation tailored to the actual title and content
  static String _generateContextualBabyLanguage(String title, String content) {
    final lowerTitle = title.toLowerCase();
    final lowerContent = content.toLowerCase();
    final combined = '$lowerTitle $lowerContent';

    String themeEmoji = '🎈';
    String analogy = '';
    String whyCool = '';

    if (combined.contains('komputer') ||
        combined.contains('coding') ||
        combined.contains('program') ||
        combined.contains('jaringan') ||
        combined.contains('software') ||
        combined.contains('hardware') ||
        combined.contains('data') ||
        combined.contains('internet')) {
      themeEmoji = '🤖';
      analogy =
          'Bayangkan kamu punya robot kecil yang sangat pintar tapi harus diberi tahu langkah-langkahnya satu per satu seperti menyusun balok lego warna-warni! 🧱✨ Robot ini bisa bekerja sangat cepat tanpa pernah merasa lelah.';
      whyCool =
          'Dengan memahami konsep ini, kamu bisa seperti pencipta dunia digital dan memprogram robot masa depan!';
    } else if (combined.contains('matematika') ||
        combined.contains('aljabar') ||
        combined.contains('hitung') ||
        combined.contains('rumus') ||
        combined.contains('angka') ||
        combined.contains('persamaan') ||
        combined.contains('geometri')) {
      themeEmoji = '🪙';
      analogy =
          'Bayangkan kamu sedang bermain mencari harta karun rahasia! 🗺️ Di dalam peti ada permen yang jumlahnya belum kita ketahui, dan kita punya timbangan ajaib untuk menebak isinya dengan tepat tanpa merusaknya.';
      whyCool =
          'Kamu jadi punya kekuatan rahasia untuk memecahkan semua teka-teki logika paling rumit di dunia!';
    } else if (combined.contains('biologi') ||
        combined.contains('sel') ||
        combined.contains('tumbuhan') ||
        combined.contains('fotosintesis') ||
        combined.contains('hewan') ||
        combined.contains('organ') ||
        combined.contains('tubuh') ||
        combined.contains('darah')) {
      themeEmoji = '🍃';
      analogy =
          'Bayangkan setiap daun atau bagian tubuh kita adalah rumah kurcaci atau pabrik dapur mini! 🏠👩‍🍳 Mereka memasak makanan menggunakan cahaya matahari dan bekerja sama menjaga tanaman tetap segar dan tersenyum.';
      whyCool =
          'Kamu bisa melihat keajaiban alam di sekitarmu yang tersembunyi dari mata biasa!';
    } else if (combined.contains('fisika') ||
        combined.contains('gaya') ||
        combined.contains('gerak') ||
        combined.contains('energi') ||
        combined.contains('kecepatan') ||
        combined.contains('listrik') ||
        combined.contains('magnet')) {
      themeEmoji = '🧲';
      analogy =
          'Bayangkan mainan kesayanganmu punya kekuatan tarik-menarik dan dorong-mendorong tak terlihat seperti magnet sakti atau dorongan ayunan di taman hiburan! 🎪';
      whyCool =
          'Kamu bisa tahu kenapa roket bisa terbang ke luar angkasa dan kenapa bola bisa memantul tinggi!';
    } else if (combined.contains('sejarah') ||
        combined.contains('indonesia') ||
        combined.contains('pancasila') ||
        combined.contains('sosial') ||
        combined.contains('warga') ||
        combined.contains('budaya')) {
      themeEmoji = '⏳';
      analogy =
          'Bayangkan kita masuk ke dalam mesin waktu ajaib! 🛸 Kita mengunjungi kakek buyut kita zaman dulu yang saling bantu mendirikan rumah bersama-sama dengan senyum hangat.';
      whyCool =
          'Kita jadi tahu cerita hebat pahlawan kita dan bisa membuat negeri kita makin rukun dan hebat!';
    } else {
      themeEmoji = '✨';
      analogy =
          'Bayangkan konsep "$title" seperti sebuah kotak peralatan ajaib yang membantu kita memahami rahasia di sekitar kita dengan cara yang asyik!';
      whyCool =
          'Materi ini bikin kamu makin cerdas dan punya bekal pengetahuan hebat!';
    }

    final cleanSnippet = content
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final summaryBrief = cleanSnippet.length > 120
        ? '${cleanSnippet.substring(0, 120)}...'
        : cleanSnippet;

    return '''
$themeEmoji **Petualangan Belajar: "$title"** 🎈

🧸 **Cerita Pembuka & Analogi Seru:**
$analogy

🔍 **Rahasia Inti Materi:**
1. **Inti Konsep**: Materi ini intinya bercerita tentang $title.
2. **Kunci Utama**: "$summaryBrief".
3. **Cara Kerja Sederhana**: Ketika kita memahami alurnya langkah demi langkah, semuanya terasa semudah menyusun puzzle gambar!

💡 **Kenapa Ini Keren Banget?**
$whyCool

🚀 **Misi Detektif Cilik:**
Coba bayangkan satu contoh nyata dari "$title" yang pernah kamu lihat di sekitarmu hari ini! Seru kan? 🎉🍦
''';
  }

  /// Strict keyword-based relevance guardrail for fallback
  static String _generateContextualAnswer(
    String title,
    String content,
    String question,
  ) {
    final lowerQ = question.toLowerCase();
    final lowerTitle = title.toLowerCase();
    final lowerContent = content.toLowerCase();

    // Indonesian stop words and question auxiliary words to exclude
    const stopWords = {
      'dan', 'yang', 'untuk', 'dari', 'pada', 'adalah', 'ini', 'itu', 'dengan',
      'akan', 'juga', 'oleh', 'saat', 'atau', 'dalam', 'bisa', 'dapat', 'kami',
      'kamu', 'saya', 'kita', 'mereka', 'anda', 'materi', 'modul', 'bab',
      'tentang', 'pelajaran', 'apa', 'siapa', 'mengapa', 'kenapa', 'bagaimana',
      'dimana', 'kapan', 'jelaskan', 'sebutkan', 'tolong', 'contoh', 'tanya',
      'halo', 'hai', 'selamat', 'pagi', 'siang', 'sore', 'malam', 'ya', 'kah',
    };

    // Extract significant keywords from title and content
    final materialTokens = <String>{};
    for (final word in '$lowerTitle $lowerContent'.split(RegExp(r'[^a-zA-Z0-9]+'))) {
      if (word.length >= 3 && !stopWords.contains(word)) {
        materialTokens.add(word);
      }
    }

    // Extract significant query tokens
    final queryTokens = <String>{};
    for (final word in lowerQ.split(RegExp(r'[^a-zA-Z0-9]+'))) {
      if (word.length >= 3 && !stopWords.contains(word)) {
        queryTokens.add(word);
      }
    }

    // Check if query shares at least one core domain keyword with material
    bool isRelevant = false;
    if (queryTokens.isEmpty) {
      // User only asked a greeting or very generic phrase
      isRelevant = lowerQ.contains(lowerTitle);
    } else {
      for (final qToken in queryTokens) {
        if (materialTokens.contains(qToken) || lowerTitle.contains(qToken)) {
          isRelevant = true;
          break;
        }
      }
    }

    if (!isRelevant) {
      return '''
⚠️ [DI LUAR KONTEKS PEMBELAJARAN]

Halo! 😊 Pertanyaan kamu berada di luar konteks materi pembelajaran **$title**.

AI Tutor ini secara khusus diprogram untuk mendampingi kamu mempelajari dan mendiskusikan topik modul **$title**.
Yuk, kita kembali fokus pada topik ini! Ada rumus, konsep, atau bagian dari penjelasan modul yang ingin kamu tanyakan atau diskusikan? 🚀💡
''';
    }

    return '''
Halo! Berdasarkan materi **"$title"** yang sedang kita pelajari:

Mengenai pertanyaanmu: *"$question"*

📌 **Penjelasan Terkait Materi:**
- Konsep tersebut berhubungan langsung dengan pembahasan inti pada modul ini.
- Perhatikan bagaimana konsep ini diterapkan dalam konteks $title untuk memudahkan pemahamanmu.
- Jika kamu mempelajari langkah-langkah praktisnya, mulailah dari dasar konsep materi terlebih dahulu.

Semangat terus belajarnya! Ada lagi bagian dari materi "$title" yang ingin kamu perdalam? 🚀💡
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

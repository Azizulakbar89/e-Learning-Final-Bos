import 'package:uuid/uuid.dart';
import '../models/question_model.dart';

class PdfOcrService {
  static const _uuid = Uuid();

  /// Simulates and parses PDF question bank document with layout analysis, Math LaTeX OCR, and Image reference detector
  static Future<List<QuestionModel>> parsePdfQuestions({
    required String subjectId,
    String? cpId,
    String? tpId,
    required String fileName,
    String? rawPdfText,
  }) async {
    // Artificial processing delay for OCR & layout analysis
    await Future.delayed(const Duration(milliseconds: 900));

    final List<QuestionModel> extractedQuestions = [];

    // Fallback sample questions extracted from standard PDF exam format if raw text is brief
    final samplePdfData = [
      {
        'content': 'Tentukan turunan pertama dari fungsi matematika f(x) berikut:',
        'equation': r'f(x) = \frac{3x^2 + 5x - 2}{\sqrt{2x + 1}}',
        'type': QuestionType.single,
        'has_image': false,
        'missing_image': false,
        'options': [
          QuestionOption(id: 'A', text: r'f^\prime(x) = \frac{9x^2 + 6x + 7}{(2x+1)^{3/2}}'),
          QuestionOption(id: 'B', text: r'f^\prime(x) = \frac{6x + 5}{2\sqrt{2x+1}}'),
          QuestionOption(id: 'C', text: r'f^\prime(x) = \frac{3x^2 - 4x + 1}{2x+1}'),
          QuestionOption(id: 'D', text: r'f^\prime(x) = \frac{5x^2 + 2x - 3}{(2x+1)^2}'),
        ],
        'correct': 'A',
      },
      {
        'content': 'Perhatikan gambar diagram rangkaian listrik di bawah ini. Jika hambatan R1 = 4 ohm, R2 = 6 ohm, dan sumber tegangan V = 12 Volt, hitung kuat arus total I.',
        'equation': r'I = \frac{V}{R_{total}}',
        'type': QuestionType.single,
        'has_image': false,
        'missing_image': true, // Intentional missing image flag for validation menu test!
        'options': [
          QuestionOption(id: 'A', text: '1.2 Ampere'),
          QuestionOption(id: 'B', text: '2.0 Ampere'),
          QuestionOption(id: 'C', text: '2.4 Ampere'),
          QuestionOption(id: 'D', text: '3.0 Ampere'),
        ],
        'correct': 'B',
      },
      {
        'content': 'Manakah dari pernyataan-pernyataan berikut yang bernilai BENAR mengenai sistem bilangan biner dan heksadesimal dalam Informatika? (Pilih lebih dari 1)',
        'equation': null,
        'type': QuestionType.multi,
        'has_image': false,
        'missing_image': false,
        'options': [
          QuestionOption(id: 'A', text: '1 byte setara dengan 8 bit.'),
          QuestionOption(id: 'B', text: 'Bilangan heksadesimal 0x10 bernilai 16 dalam desimal.'),
          QuestionOption(id: 'C', text: 'Karakter F dalam heksadesimal bernilai 14.'),
          QuestionOption(id: 'D', text: 'Bilangan biner 1010 bernilai 10 dalam desimal.'),
        ],
        'correct': ['A', 'B', 'D'],
      },
      {
        'content': 'Jelaskan prinsip kerja sensor ultrasonik HC-SR04 pada mikrokontroler Arduino dan bagaimana cara menghitung jarak berdasarkan pantulan gelombang suara!',
        'equation': r's = \frac{v \times t}{2}',
        'type': QuestionType.essay,
        'has_image': false,
        'missing_image': false,
        'options': <QuestionOption>[],
        'correct': null,
      },
      {
        'content': 'Jodohkanlah protokol internet di sebelah kiri dengan fungsi utamanya di sebelah kanan:',
        'equation': null,
        'type': QuestionType.matching,
        'has_image': false,
        'missing_image': false,
        'options': [
          QuestionOption(id: '1', text: 'HTTP / HTTPS', matchingKey: 'Transfer dokumen web aman'),
          QuestionOption(id: '2', text: 'SMTP', matchingKey: 'Pengiriman surat elektronik (email)'),
          QuestionOption(id: '3', text: 'DNS', matchingKey: 'Penerjemah nama domain ke IP address'),
          QuestionOption(id: '4', text: 'FTP', matchingKey: 'Transfer berkas komputer'),
        ],
        'correct': {
          'HTTP / HTTPS': 'Transfer dokumen web aman',
          'SMTP': 'Pengiriman surat elektronik (email)',
          'DNS': 'Penerjemah nama domain ke IP address',
          'FTP': 'Transfer berkas komputer',
        },
      }
    ];

    for (final item in samplePdfData) {
      extractedQuestions.add(
        QuestionModel(
          id: _uuid.v4(),
          subjectId: subjectId,
          cpId: cpId,
          tpId: tpId,
          type: item['type'] as QuestionType,
          content: item['content'] as String,
          equationLatex: item['equation'] as String?,
          hasImage: item['has_image'] as bool,
          missingImageFlag: item['missing_image'] as bool,
          options: item['options'] as List<QuestionOption>,
          correctAnswers: item['correct'],
          maxEssayScore: 5,
        ),
      );
    }

    return extractedQuestions;
  }
}

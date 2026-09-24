import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';
import '../models/question_model.dart';
import 'ai_service.dart';

class PdfOcrService {
  static const _uuid = Uuid();

  /// Detects if a string contains Arabic characters
  static bool containsArabic(String text) {
    return RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]').hasMatch(text);
  }

  /// Parses PDF question bank document with Gemini Vision OCR, Layout Analysis, Math LaTeX, and Multilingual recognition
  static Future<List<QuestionModel>> parsePdfQuestions({
    required String subjectId,
    String? cpId,
    String? tpId,
    required String fileName,
    Uint8List? pdfBytes,
    String? rawPdfText,
    Function(String status, double progress)? onProgress,
  }) async {
    List<QuestionModel> extractedQuestions = [];

    // 1. If real PDF bytes are provided, attempt AI Vision OCR page-by-page
    if (pdfBytes != null && pdfBytes.isNotEmpty) {
      try {
        onProgress?.call('Membuka dokumen PDF...', 0.05);
        PdfDocument? document;
        try {
          document = await PdfDocument.openData(pdfBytes);
        } catch (e) {
          debugPrint('[PdfOcrService] pdfx openData error: $e');
        }

        if (document != null && document.pagesCount > 0) {
          final totalPages = document.pagesCount;
          debugPrint('[PdfOcrService] Document opened with $totalPages pages for OCR');

          for (int pageNum = 1; pageNum <= totalPages; pageNum++) {
            final progress = (pageNum / totalPages) * 0.9;
            onProgress?.call(
              'Memindai Halaman $pageNum dari $totalPages (${extractedQuestions.length} soal ditemukan)...',
              progress,
            );

            try {
              final page = await document.getPage(pageNum);
              // Compact 750px width produces ~35KB JPEG (50x faster upload than raw canvas)
              final pageImage = await page.render(
                width: 750,
                height: (750 * (page.height / page.width)).toDouble(),
                format: PdfPageImageFormat.jpeg,
              );
              await page.close();

              if (pageImage != null && pageImage.bytes.isNotEmpty) {
                final jsonResult = await AiService.extractQuestionsFromImageBytes(
                  imageBytes: pageImage.bytes,
                );

                if (jsonResult != null && jsonResult.trim().isNotEmpty) {
                  final pageQuestions = _parseJsonQuestions(
                    rawJson: jsonResult,
                    subjectId: subjectId,
                    cpId: cpId,
                    tpId: tpId,
                  );
                  extractedQuestions.addAll(pageQuestions);
                }
              }
            } catch (pageErr) {
              debugPrint('[PdfOcrService] Page $pageNum OCR note: $pageErr');
            }
          }

          try {
            await document.close();
          } catch (_) {}
        }

        // If page-by-page vision OCR extracted questions, return them directly!
        if (extractedQuestions.isNotEmpty) {
          onProgress?.call('Selesai mengekstrak ${extractedQuestions.length} butir soal!', 1.0);
          return extractedQuestions;
        }

        // 2. Direct full-stream PDF fallback via Gemini multimodal
        onProgress?.call('Memproses dokumen PDF secara keseluruhan...', 0.85);
        final aiRawResult = await AiService.extractQuestionsFromPdfData(
          pdfBytes: pdfBytes,
          subjectName: fileName,
        );

        if (aiRawResult != null && aiRawResult.trim().isNotEmpty) {
          extractedQuestions = _parseJsonQuestions(
            rawJson: aiRawResult,
            subjectId: subjectId,
            cpId: cpId,
            tpId: tpId,
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[PdfOcrService] Gemini PDF OCR Error: $e');
        }
      }
    }

    if (extractedQuestions.isEmpty) {
      onProgress?.call('Tidak ada butir soal yang berhasil diekstrak oleh AI.', 1.0);
    } else {
      onProgress?.call('Selesai mengekstrak ${extractedQuestions.length} butir soal!', 1.0);
    }

    return extractedQuestions;
  }

  /// Parses structured JSON output from Gemini AI with auto-repair for truncated JSON
  static List<QuestionModel> _parseJsonQuestions({
    required String rawJson,
    required String subjectId,
    String? cpId,
    String? tpId,
  }) {
    final List<QuestionModel> questions = [];

    try {
      String cleanJson = rawJson.trim();
      // Extract from the first '[' or '{' to the last ']' or '}'
      final firstBracket = cleanJson.indexOf('[');
      final firstBrace = cleanJson.indexOf('{');
      int startIndex = 0;
      if (firstBracket != -1 && (firstBrace == -1 || firstBracket < firstBrace)) {
        startIndex = firstBracket;
      } else if (firstBrace != -1) {
        startIndex = firstBrace;
      }

      int lastBracket = cleanJson.lastIndexOf(']');
      int lastBrace = cleanJson.lastIndexOf('}');
      int endIndex = cleanJson.length;
      if (lastBracket != -1 && lastBracket > lastBrace) {
        endIndex = lastBracket + 1;
      } else if (lastBrace != -1) {
        endIndex = lastBrace + 1;
      }

      if (startIndex < endIndex) {
        cleanJson = cleanJson.substring(startIndex, endIndex);
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(cleanJson);
      } catch (_) {
        // Auto-repair truncated JSON array by truncating at the last complete object
        if (cleanJson.startsWith('[')) {
          final lastValidObjEnd = cleanJson.lastIndexOf('}');
          if (lastValidObjEnd != -1) {
            final repaired = '${cleanJson.substring(0, lastValidObjEnd + 1)}]';
            try {
              decoded = jsonDecode(repaired);
            } catch (_) {}
          }
        }
      }

      final List items = decoded is List
          ? decoded
          : (decoded is Map ? (decoded['questions'] as List? ?? [decoded]) : []);

      for (final item in items) {
        if (item is! Map) continue;

        final rawType = item['type']?.toString().toLowerCase() ?? 'single';
        final qType = QuestionTypeExtension.fromString(rawType);

        final rawOptions = item['options'] as List? ?? [];
        final List<QuestionOption> options = [];

        for (int i = 0; i < rawOptions.length; i++) {
          final opt = rawOptions[i];
          if (opt is Map) {
            options.add(
              QuestionOption(
                id: opt['id']?.toString() ?? String.fromCharCode(65 + i),
                text: opt['text']?.toString() ?? '',
                equationLatex: opt['equation_latex']?.toString(),
                matchingKey: opt['matching_key']?.toString(),
              ),
            );
          } else if (opt is String) {
            options.add(
              QuestionOption(
                id: String.fromCharCode(65 + i),
                text: opt,
              ),
            );
          }
        }

        questions.add(
          QuestionModel(
            id: _uuid.v4(),
            subjectId: subjectId,
            cpId: cpId,
            tpId: tpId,
            type: qType,
            content: item['content']?.toString() ?? item['question']?.toString() ?? 'Soal Tanpa Judul',
            equationLatex: item['equation']?.toString() ?? item['equation_latex']?.toString(),
            hasImage: item['has_image'] == true,
            missingImageFlag: item['missing_image'] == true,
            options: options,
            correctAnswers: item['correct'] ?? item['correct_answers'] ?? item['correct_answer'],
            maxEssayScore: (item['max_essay_score'] as num?)?.toInt() ?? 5,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PdfOcrService] JSON Parsing failed: $e');
      }
    }

    return questions;
  }
}

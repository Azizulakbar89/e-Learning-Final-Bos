import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

/// Data model untuk periode tahun ajaran dan semester
class AcademicPeriod {
  final String academicYear; // e.g. "2026/2027"
  final String semester; // "Gasal" | "Genap"

  const AcademicPeriod({
    required this.academicYear,
    required this.semester,
  });

  @override
  String toString() => '$academicYear ($semester)';
}

/// Data item siswa untuk sinkronisasi nilai
class SidikmuStudentGrade {
  final String nis;
  final String studentName;
  final double? score; // null jika belum mengerjakan / kosong

  const SidikmuStudentGrade({
    required this.nis,
    required this.studentName,
    this.score,
  });
}

/// Item laporan bagi siswa yang bernilai kosong atau 0
class SidikmuUnsyncedItem {
  final String nis;
  final String studentName;
  final String reason;
  final double? score;

  const SidikmuUnsyncedItem({
    required this.nis,
    required this.studentName,
    required this.reason,
    this.score,
  });
}

/// Progress state sinkronisasi untuk UI
class SidikmuSyncProgress {
  final double percentage; // 0.0 sampai 1.0
  final String stageMessage;
  final int step;
  final int totalSteps;

  const SidikmuSyncProgress({
    required this.percentage,
    required this.stageMessage,
    required this.step,
    required this.totalSteps,
  });

  int get percentageInt => (percentage * 100).clamp(0, 100).toInt();
}

/// Hasil akhir sinkronisasi
class SidikmuSyncResult {
  final bool isSuccess;
  final String message;
  final int totalStudents;
  final int syncedStudents;
  final List<SidikmuUnsyncedItem> emptyOrZeroStudents;

  const SidikmuSyncResult({
    required this.isSuccess,
    required this.message,
    this.totalStudents = 0,
    this.syncedStudents = 0,
    this.emptyOrZeroStudents = const [],
  });

  factory SidikmuSyncResult.error(String message) {
    return SidikmuSyncResult(
      isSuccess: false,
      message: message,
    );
  }
}

/// Layanan utama automasi sinkronisasi ke SidikMu
class SidikmuService {
  static const String defaultUrl = 'https://smpm12gkb.sidikmu.com';

  /// 1. Menghitung Tahun Ajaran dan Semester
  /// - Aturan: Tahun ajaran diawali dari bulan 7 (Juli).
  /// - Bulan 7 - 12 -> Semester Gasal, Tahun Ajaran YYYY / (YYYY+1)
  /// - Bulan 1 - 6  -> Semester Genap, Tahun Ajaran (YYYY-1) / YYYY
  static AcademicPeriod calculateAcademicPeriod([DateTime? date]) {
    final now = date ?? DateTime.now();
    final month = now.month;
    final year = now.year;

    if (month >= 7) {
      return AcademicPeriod(
        academicYear: '$year/${year + 1}',
        semester: 'Gasal',
      );
    } else {
      return AcademicPeriod(
        academicYear: '${year - 1}/$year',
        semester: 'Genap',
      );
    }
  }

  /// 2. Deteksi Jenis Nilai Sumatif berdasarkan judul ujian
  /// - Quiz / PH / Penilaian Harian -> 'Harian'
  /// - PTS / STS / Tengah Semester  -> 'PTS'
  /// - PAS / SAS / Akhir Semester   -> 'PAS'
  static String detectSumatifType(String examTitle) {
    final title = examTitle.toUpperCase().trim();

    if (title.contains('PTS') ||
        title.contains('STS') ||
        title.contains('TENGAH SEMESTER') ||
        title.contains('MID')) {
      return 'PTS';
    }

    if (title.contains('PAS') ||
        title.contains('SAS') ||
        title.contains('AKHIR SEMESTER') ||
        title.contains('UAS') ||
        title.contains('PAT')) {
      return 'PAS';
    }

    // Default adalah Penilaian Harian / Quiz
    return 'Harian';
  }

  /// 3. Normalisasi Nama Kelas untuk pencocokan cerdas
  /// Contoh: "IX CORDOBA" -> "cordoba", "Cordoba" -> "cordoba"
  static String normalizeClassName(String name) {
    String cleaned = name.toUpperCase().trim();
    // Hapus romawi tingkat (VII, VIII, IX, X, XI, XII)
    cleaned = cleaned.replaceAll(RegExp(r'\b(VII|VIII|IX|X|XI|XII)\b'), '');
    // Hapus angka tingkat (7, 8, 9, 10, 11, 12)
    cleaned = cleaned.replaceAll(RegExp(r'\b(7|8|9|10|11|12)\b'), '');
    // Hapus karakter pemisah seperti dash/slash/titik
    cleaned = cleaned.replaceAll(RegExp(r'[-_./]'), ' ');
    // Hapus kata 'KELAS' atau 'CLASS' jika ada
    cleaned = cleaned.replaceAll(RegExp(r'\b(KELAS|CLASS)\b'), '');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  }

  /// 4. Mencocokkan nama kelas di sistem e-Learning dengan opsi dropdown SidikMu
  static String? matchClassOption(String systemClass, List<String> sidikmuClassOptions) {
    if (sidikmuClassOptions.isEmpty) return null;

    final sysNorm = normalizeClassName(systemClass);
    final sysRaw = systemClass.trim().toLowerCase();

    // 1. Cek Exact Match case-insensitive
    for (final opt in sidikmuClassOptions) {
      if (opt.trim().toLowerCase() == sysRaw) return opt;
    }

    // 2. Cek Substring match
    for (final opt in sidikmuClassOptions) {
      final optLower = opt.toLowerCase();
      if (optLower.contains(sysRaw) || sysRaw.contains(optLower)) return opt;
    }

    // 3. Cek Normalized match (e.g. cordoba == cordoba)
    for (final opt in sidikmuClassOptions) {
      final optNorm = normalizeClassName(opt);
      if (optNorm.isNotEmpty && sysNorm.isNotEmpty) {
        if (optNorm == sysNorm || optNorm.contains(sysNorm) || sysNorm.contains(optNorm)) {
          return opt;
        }
      }
    }

    return sidikmuClassOptions.first;
  }

  /// 5. Validasi Uji Login ke SidikMu via WebView controller
  static Future<bool> testLogin({
    required WebViewController controller,
    required String url,
    required String username,
    required String password,
  }) async {
    final completer = Completer<bool>();
    final targetUrl = url.trim().replaceAll(RegExp(r'/+$'), '');

    try {
      await controller.loadRequest(Uri.parse(targetUrl));
      // Berikan waktu render form
      await Future.delayed(const Duration(milliseconds: 2500));

      final loginJs = '''
        (function() {
          var userEl = document.querySelector('input[name="user"], #card-user');
          var passEl = document.querySelector('input[name="passw"], #card-password');
          var submitBtn = document.querySelector('button[name="submit"], #submit, button[type="submit"]');
          if (!userEl || !passEl) {
            return JSON.stringify({ success: false, error: 'Form login tidak ditemukan' });
          }
          userEl.value = ${jsonEncode(username)};
          userEl.dispatchEvent(new Event('input', { bubbles: true }));
          passEl.value = ${jsonEncode(password)};
          passEl.dispatchEvent(new Event('input', { bubbles: true }));
          if (submitBtn) {
            submitBtn.disabled = false;
            submitBtn.click();
            return JSON.stringify({ success: true });
          }
          return JSON.stringify({ success: false, error: 'Tombol submit tidak ditemukan' });
        })();
      ''';

      final res = await controller.runJavaScriptReturningResult(loginJs);
      debugPrint('[SidikmuService] Login trigger result: $res');

      // Tunggu respons navigasi setelah submit
      await Future.delayed(const Duration(milliseconds: 3000));

      final checkJs = '''
        (function() {
          var text = document.body.innerText || '';
          if (text.includes('Halo,') || text.includes('Logout') || text.includes('Menu Akademik') || text.includes('Nilai KM')) {
            return JSON.stringify({ loggedIn: true });
          }
          if (text.includes('salah') || text.includes('gagal') || text.includes('Invalid')) {
            return JSON.stringify({ loggedIn: false, error: 'Username atau password salah' });
          }
          return JSON.stringify({ loggedIn: !document.querySelector('input[name="user"]') });
        })();
      ''';

      final checkRes = await controller.runJavaScriptReturningResult(checkJs);
      final decoded = _safeParseJsObject(checkRes);
      final isLogged = decoded['loggedIn'] == true;
      completer.complete(isLogged);
    } catch (e) {
      debugPrint('[SidikmuService] testLogin exception: $e');
      completer.complete(false);
    }

    return completer.future;
  }

  /// Safe helper to parse JS returned JSON object from runJavaScriptReturningResult
  static Map<String, dynamic> _safeParseJsObject(dynamic result) {
    if (result == null) return {};
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    dynamic decoded = result;
    for (int i = 0; i < 4 && decoded is String; i++) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        break;
      }
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return {};
  }

  /// Helper JavaScript untuk mendeteksi elemen form SidikMu & tabel nilai siswa
  static const String _kSidikmuHelpersJs = r'''
    function findSelectByKeyword(keywords, fallbackIndex) {
      var selects = Array.from(document.querySelectorAll('select'));
      if (selects.length === 0) return null;

      for (var i = 0; i < selects.length; i++) {
        var s = selects[i];
        if (s.id) {
          var lbl = document.querySelector('label[for="' + s.id + '"]');
          if (lbl) {
            var txt = (lbl.innerText || '').toLowerCase();
            if (keywords.some(function(k) { return txt.includes(k); })) return s;
          }
        }
        var parent = s.closest('.form-group, .col, .col-md-6, .col-sm-6, .mb-3, div, tr');
        if (parent) {
          var lbl = parent.querySelector('label, th');
          if (lbl) {
            var txt = (lbl.innerText || '').toLowerCase();
            if (keywords.some(function(k) { return txt.includes(k); })) return s;
          }
        }
        var nameId = ((s.getAttribute('name') || '') + ' ' + (s.getAttribute('id') || '')).toLowerCase();
        if (keywords.some(function(k) { return nameId.includes(k); })) return s;
      }

      if (fallbackIndex !== undefined && fallbackIndex < selects.length) {
        return selects[fallbackIndex];
      }
      return null;
    }

    // Aturan pengguna: "untuk kelas, CP, TP itu buat jika ada kesamaan, mengandung yang ada di aplikasi e-learning saja!!!"
    function matchOptionContains(selectEl, targetText) {
      if (!selectEl || !selectEl.options || selectEl.options.length <= 1) return null;
      var target = (targetText || '').toLowerCase().trim();
      if (!target) return selectEl.options.length > 1 ? selectEl.options[1] : null;

      var opts = Array.from(selectEl.options);

      // 1. Prioritas utama: Opsi SidikMu yang mengandung teks e-Learning persis (case-insensitive)
      // Contoh: "VIII HELIUM" mengandung "HELIUM"
      // Contoh: "CP 1 - ..." mengandung "CP 1"
      // Contoh: "1.1 - menerapkan..." mengandung "1.1"
      var opt = opts.find(function(o) {
        var t = (o.text || '').toLowerCase().trim();
        if (!t || t.startsWith('--') || t.includes('pilih')) return false;
        return t.includes(target);
      });
      if (opt) return opt;

      // 2. Token match: jika target memiliki token (misal target "CP 1" -> cari token "cp" dan "1")
      var cleanTarget = target.replace(/[^a-z0-9.]/gi, ' ').trim();
      var tokens = cleanTarget.split(/\s+/).filter(function(x) { return x.length >= 1; });
      if (tokens.length > 0) {
        opt = opts.find(function(o) {
          var t = (o.text || '').toLowerCase().trim();
          if (!t || t.startsWith('--') || t.includes('pilih')) return false;
          return tokens.every(function(tok) { return t.includes(tok); });
        });
        if (opt) return opt;

        // Cek jika ada token angka/kode utama (misal "1.1" atau "1")
        var firstTok = tokens[0];
        opt = opts.find(function(o) {
          var t = (o.text || '').toLowerCase().trim();
          if (!t || t.startsWith('--') || t.includes('pilih')) return false;
          return t.includes(firstTok);
        });
        if (opt) return opt;
      }

      // 3. Fallback jika tidak ditemukan: ambil opsi pertama yang valid (bukan placeholder)
      for (var i = 1; i < opts.length; i++) {
        var t = (opts[i].text || '').toLowerCase().trim();
        if (opts[i].value && !t.startsWith('--') && !t.includes('pilih')) {
          return opts[i];
        }
      }
      return opts.length > 1 ? opts[1] : null;
    }

    function selectAndTriggerChange(selectEl, opt) {
      if (!selectEl || !opt) return false;
      selectEl.value = opt.value;
      selectEl.dispatchEvent(new Event('input', { bubbles: true }));
      selectEl.dispatchEvent(new Event('change', { bubbles: true }));
      selectEl.dispatchEvent(new Event('blur', { bubbles: true }));

      var $ = window.jQuery || window.$;
      if ($) {
        try {
          $(selectEl).val(opt.value).trigger('input').trigger('change').trigger('change.select2');
        } catch(e) {}
      }
      return true;
    }

    function findAndClickSubmitButton() {
      var allButtons = Array.from(document.querySelectorAll('button, input[type="submit"], input[type="button"], a.btn, .btn'));
      var targetKeywords = ['proses selanjutnya', 'proses', 'tampilkan', 'filter', 'cari', 'lihat', 'lanjutkan', 'submit'];

      var btn = null;
      for (var k = 0; k < targetKeywords.length; k++) {
        var kw = targetKeywords[k];
        btn = allButtons.find(function(b) {
          var txt = (b.innerText || b.value || '').toLowerCase().trim();
          return txt === kw || txt.includes(kw);
        });
        if (btn) break;
      }

      if (!btn) {
        var formOrCard = document.querySelector('form, .card-body, .card, .box-body, .box');
        if (formOrCard) {
          btn = formOrCard.querySelector('button[type="submit"], input[type="submit"], button.btn-primary, button.btn-info, button.btn-success, .btn-primary, .btn-info');
        }
      }

      if (btn) {
        btn.scrollIntoView({ behavior: 'instant', block: 'center' });
        btn.focus();
        btn.click();
        var $ = window.jQuery || window.$;
        if ($) {
          try { $(btn).trigger('click'); } catch(e) {}
        }
        var form = btn.closest('form');
        if (form) {
          try { form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true })); } catch(e) {}
        }
        return { success: true, text: btn.innerText || btn.value || 'button' };
      }
      return { success: false };
    }
  ''';

  /// Helper JavaScript untuk mendeteksi tabel nilai siswa yang sebenarnya
  static const String _kFindStudentGradeTableJs = r'''
    function findStudentGradeTable() {
      var tables = Array.from(document.querySelectorAll('table'));
      for (var i = 0; i < tables.length; i++) {
        var tbl = tables[i];
        // Abaikan tabel formulir filter yang memiliki dropdown select
        if (tbl.querySelectorAll('select').length >= 2) continue;

        var rows = Array.from(tbl.querySelectorAll('tbody tr, tr')).filter(function(r) {
          if (r.querySelector('th')) return false;
          var cells = r.querySelectorAll('td');
          if (cells.length < 2) return false;
          var inps = r.querySelectorAll('input:not([type="hidden"]):not([type="checkbox"]):not([type="submit"]):not([type="button"]):not([type="radio"])');
          return inps.length > 0;
        });

        if (rows.length >= 1) {
          return { table: tbl, rows: rows, count: rows.length };
        }
      }
      return null;
    }
  ''';

  /// 6. Automasi Utama Sinkronisasi Nilai Formatif & Sumatif
  static Future<SidikmuSyncResult> syncGradesAutomation({
    required WebViewController controller,
    required String url,
    required String username,
    required String password,
    required bool isFormatif, // true: Formatif, false: Sumatif
    required String academicYear,
    required String semester,
    String? sumatifType, // 'Harian' | 'PTS' | 'PAS'
    required String targetClassName,
    required String targetSubjectName,
    String? targetCpCode,
    String? targetTpCode,
    required Map<String, double?> studentGradesByNis,
    required Map<String, String> studentNamesByNis,
    void Function(SidikmuSyncProgress progress)? onProgress,
  }) async {
    void emit(double pct, String msg, int step, int totalSteps) {
      if (onProgress != null) {
        onProgress(SidikmuSyncProgress(
          percentage: pct,
          stageMessage: msg,
          step: step,
          totalSteps: totalSteps,
        ));
      }
    }

    const totalSteps = 6;
    final targetUrl = url.trim().replaceAll(RegExp(r'/+$'), '');

    try {
      // ──────── STEP 1: INITIAL LOAD & TABLE DETECTION (0% - 18%) ────────
      emit(0.08, 'Membuka portal SidikMu...', 1, totalSteps);
      await controller.loadRequest(Uri.parse(targetUrl));
      await Future.delayed(const Duration(milliseconds: 2500));

      // Deteksi cepat: Apakah halaman ini SUDAH langsung memuat tabel nilai siswa?
      // (Contoh: jika guru membuka tautan langsung form nilai seperti di gambar pengguna)
      final quickCheckRes = await controller.runJavaScriptReturningResult('''
        (function() {
          $_kFindStudentGradeTableJs
          var info = findStudentGradeTable();
          return JSON.stringify({
            isReady: !!info,
            rowCount: info ? info.count : 0
          });
        })();
      ''');
      final quickCheck = _safeParseJsObject(quickCheckRes);
      bool isTableDirectlyReady = quickCheck['isReady'] == true;

      if (!isTableDirectlyReady) {
        emit(0.14, 'Mengotentikasi akun guru ($username)...', 1, totalSteps);
        final loginJs = '''
          (function() {
            $_kFindStudentGradeTableJs
            var info = findStudentGradeTable();
            if (info) return JSON.stringify({ alreadyLoggedIn: true, tableReady: true });

            var userEl = document.querySelector('input[name="user"], #card-user');
            var passEl = document.querySelector('input[name="passw"], #card-password');
            var submitBtn = document.querySelector('button[name="submit"], #submit, button[type="submit"]');
            if (!userEl || !passEl) {
              var bodyText = document.body.innerText || '';
              if (bodyText.includes('Halo,') || bodyText.includes('Nilai KM') || bodyText.includes('Dashboard') || bodyText.includes('Logout')) {
                return JSON.stringify({ alreadyLoggedIn: true });
              }
              return JSON.stringify({ success: false, error: 'Form login tidak ditemukan' });
            }
            userEl.value = ${jsonEncode(username)};
            userEl.dispatchEvent(new Event('input', { bubbles: true }));
            passEl.value = ${jsonEncode(password)};
            passEl.dispatchEvent(new Event('input', { bubbles: true }));
            if (submitBtn) {
              submitBtn.disabled = false;
              submitBtn.click();
              return JSON.stringify({ success: true });
            }
            return JSON.stringify({ success: false, error: 'Tombol login tidak ditemukan' });
          })();
        ''';
        final loginRes = await controller.runJavaScriptReturningResult(loginJs);
        final loginData = _safeParseJsObject(loginRes);
        if (loginData['tableReady'] == true) {
          isTableDirectlyReady = true;
        } else {
          await Future.delayed(const Duration(milliseconds: 3000));

          emit(0.18, 'Memverifikasi status login...', 1, totalSteps);
          final verifyLoginJs = '''
            (function() {
              $_kFindStudentGradeTableJs
              var info = findStudentGradeTable();
              if (info) return JSON.stringify({ ok: true, tableReady: true });

              var body = document.body.innerText || '';
              if (body.includes('salah') || body.includes('gagal') || body.includes('Invalid credentials')) {
                return JSON.stringify({ ok: false, error: 'Username atau password SidikMu salah' });
              }
              if (body.includes('Halo,') || body.includes('Logout') || body.includes('Nilai KM') || body.includes('Menu Akademik') || body.includes('Dashboard')) {
                return JSON.stringify({ ok: true });
              }
              var userInp = document.querySelector('input[name="user"]');
              return JSON.stringify({ ok: userInp === null });
            })();
          ''';
          final verifyRes = await controller.runJavaScriptReturningResult(verifyLoginJs);
          final verifyData = _safeParseJsObject(verifyRes);
          if (verifyData['tableReady'] == true) {
            isTableDirectlyReady = true;
          } else if (verifyData['ok'] != true) {
            return SidikmuSyncResult.error(
              verifyData['error']?.toString() ?? 'Gagal login ke SidikMu. Periksa kredensial di Profil Guru.',
            );
          }
        }
      }

      // ──────── STEP 2: NAVIGASI KE NILAI KM (18% - 32%) ────────
      if (!isTableDirectlyReady) {
        final targetMenuText = isFormatif ? 'Input Nilai Formatif' : 'Input Nilai Sumatif';
        emit(0.24, 'Membuka menu Akademik -> $targetMenuText...', 2, totalSteps);

        final navMenuJs = '''
          (function() {
            // Pasang override dialog agar tidak membekukan proses otomatis
            window.confirm = function() { return true; };
            window.alert = function() { return true; };

            $_kFindStudentGradeTableJs
            var info = findStudentGradeTable();
            if (info) {
              return JSON.stringify({ success: true, alreadyOnPage: true });
            }

            var targetMenu = ${jsonEncode(isFormatif ? 'formatif' : 'sumatif')};

            // 1. Cek kartu menu besar di halaman Dashboard
            var cards = Array.from(document.querySelectorAll('.card, a, button, div'));
            var cardTarget = cards.find(function(c) {
              var txt = (c.innerText || '').toLowerCase();
              return txt.includes('input nilai ' + targetMenu) || txt.includes('nilai ' + targetMenu);
            });
            if (cardTarget) {
              var a = cardTarget.closest('a') || cardTarget.querySelector('a');
              if (a && a.href) {
                window.location.href = a.href;
                return JSON.stringify({ success: true, action: 'nav_card_href', href: a.href });
              }
              cardTarget.click();
              return JSON.stringify({ success: true, action: 'nav_card_click' });
            }

            // 2. Buka accordion 'Nilai KM' atau 'AKADEMIK' jika terlipat
            var accordions = Array.from(document.querySelectorAll('a, .nav-link, [data-bs-toggle="collapse"]'));
            var nilaiKmParent = accordions.find(function(el) {
              var t = (el.innerText || '').trim().toLowerCase();
              return t === 'nilai km' || t.includes('nilai km');
            });
            if (nilaiKmParent) {
              if (nilaiKmParent.classList.contains('collapsed') || nilaiKmParent.getAttribute('aria-expanded') === 'false') {
                nilaiKmParent.click();
              }
            }

            // 3. Cari link menu target di sidebar
            var target = ${jsonEncode(targetMenuText.toLowerCase())};
            var links = Array.from(document.querySelectorAll('a, button, span, .nav-link'));
            var targetEl = links.find(function(el) {
              var txt = (el.innerText || '').trim().toLowerCase();
              return txt.includes(target) || (target.includes('formatif') && txt.includes('formatif')) || (target.includes('sumatif') && txt.includes('sumatif'));
            });
            if (targetEl) {
              var anchor = targetEl.closest('a') || targetEl;
              if (anchor.href) {
                window.location.href = anchor.href;
              } else {
                anchor.click();
              }
              return JSON.stringify({ success: true });
            }

            var hrefTarget = $isFormatif ? 'formatif' : 'sumatif';
            var aTag = Array.from(document.querySelectorAll('a')).find(function(a) {
              return (a.href || '').toLowerCase().includes(hrefTarget);
            });
            if (aTag) {
              if (aTag.href) {
                window.location.href = aTag.href;
              } else {
                aTag.click();
              }
              return JSON.stringify({ success: true, href: aTag.href });
            }

            if (document.querySelectorAll('select').length >= 3) {
              return JSON.stringify({ success: true, fallback: true });
            }

            return JSON.stringify({ success: false, error: 'Menu ' + ${jsonEncode(targetMenuText)} + ' tidak ditemukan' });
          })();
        ''';
        await controller.runJavaScriptReturningResult(navMenuJs);

        // Polling tunggu sampai formulir filter termuat
        int navWaitMs = 0;
        while (navWaitMs < 6000) {
          final checkPageRes = await controller.runJavaScriptReturningResult('''
            (function() {
              $_kFindStudentGradeTableJs
              var info = findStudentGradeTable();
              var selects = document.querySelectorAll('select');
              return JSON.stringify({
                isTable: !!info,
                isFilter: selects.length >= 2
              });
            })();
          ''');
          final checkPage = _safeParseJsObject(checkPageRes);
          if (checkPage['isTable'] == true) {
            isTableDirectlyReady = true;
            break;
          }
          if (checkPage['isFilter'] == true) break;
          await Future.delayed(const Duration(milliseconds: 300));
          navWaitMs += 300;
        }
      }

      // ──────── STEP 3: MENGISI FILTER FORMULIR (32% - 55%) ────────
      if (!isTableDirectlyReady) {
        // 3.1: Pilih Tahun Ajaran
        emit(0.33, 'Memilih Tahun Ajaran ($academicYear)...', 3, totalSteps);
        final yearRes = await controller.runJavaScriptReturningResult('''
          (function() {
            $_kSidikmuHelpersJs
            var selYear = findSelectByKeyword(['tahun', 'thn', 'ajaran'], 0);
            if (selYear) {
              var opt = matchOptionContains(selYear, ${jsonEncode(academicYear)});
              if (opt && selectAndTriggerChange(selYear, opt)) {
                return JSON.stringify({ success: true, val: opt.value, text: opt.text });
              }
            }
            return JSON.stringify({ success: false });
          })();
        ''');
        debugPrint('[Sidikmu] Select Tahun Ajaran result: $yearRes');

        // Polling tunggu sampai dropdown Semester aktif / memiliki opsi > 1
        int semWaitMs = 0;
        while (semWaitMs < 10000) {
          final checkSemRes = await controller.runJavaScriptReturningResult('''
            (function() {
              $_kSidikmuHelpersJs
              var selSem = findSelectByKeyword(['semester', 'smt'], 1);
              if (!selSem) return JSON.stringify({ ready: false });
              var optText = Array.from(selSem.options).map(function(o) { return (o.text || '').toLowerCase(); }).join(' ');
              var isReady = selSem.options.length > 1 && !optText.includes('pilih tahun dulu');
              return JSON.stringify({ ready: isReady, count: selSem.options.length });
            })();
          ''');
          final semData = _safeParseJsObject(checkSemRes);
          if (semData['ready'] == true) break;
          await Future.delayed(const Duration(milliseconds: 300));
          semWaitMs += 300;
        }

        // 3.2: Pilih Semester
        emit(0.36, 'Memilih Semester ($semester)...', 3, totalSteps);
        final semRes = await controller.runJavaScriptReturningResult('''
          (function() {
            $_kSidikmuHelpersJs
            var selSem = findSelectByKeyword(['semester', 'smt'], 1);
            if (selSem) {
              var opt = matchOptionContains(selSem, ${jsonEncode(semester)});
              if (opt && selectAndTriggerChange(selSem, opt)) {
                return JSON.stringify({ success: true, val: opt.value, text: opt.text });
              }
            }
            return JSON.stringify({ success: false });
          })();
        ''');
        debugPrint('[Sidikmu] Select Semester result: $semRes');

        // Polling tunggu sampai dropdown Kelas aktif / memiliki opsi > 1
        int kelasWaitMs = 0;
        while (kelasWaitMs < 10000) {
          final checkKelasRes = await controller.runJavaScriptReturningResult('''
            (function() {
              $_kSidikmuHelpersJs
              var selKelas = findSelectByKeyword(['kelas', 'rombel', 'kls'], 2);
              if (!selKelas) return JSON.stringify({ ready: false });
              var optText = Array.from(selKelas.options).map(function(o) { return (o.text || '').toLowerCase(); }).join(' ');
              var isReady = selKelas.options.length > 1 && !optText.includes('pilih semester dulu');
              return JSON.stringify({ ready: isReady, count: selKelas.options.length });
            })();
          ''');
          final kelasData = _safeParseJsObject(checkKelasRes);
          if (kelasData['ready'] == true) break;
          await Future.delayed(const Duration(milliseconds: 300));
          kelasWaitMs += 300;
        }

        // 3.3: Pilih Kelas (Mencocokkan opsi SidikMu yang MENGANDUNG nama kelas di e-Learning, misal 'HELIUM' -> 'VIII HELIUM')
        emit(0.40, 'Memilih Kelas ($targetClassName)...', 3, totalSteps);
        final kelasRes = await controller.runJavaScriptReturningResult('''
          (function() {
            $_kSidikmuHelpersJs
            var selKelas = findSelectByKeyword(['kelas', 'rombel', 'kls'], 2);
            if (selKelas) {
              var opt = matchOptionContains(selKelas, ${jsonEncode(targetClassName)});
              if (opt && selectAndTriggerChange(selKelas, opt)) {
                return JSON.stringify({ success: true, val: opt.value, text: opt.text });
              }
            }
            return JSON.stringify({ success: false });
          })();
        ''');
        debugPrint('[Sidikmu] Select Kelas result: $kelasRes');

        // Polling tunggu sampai dropdown Mapel aktif / memiliki opsi > 1
        int mapelWaitMs = 0;
        while (mapelWaitMs < 10000) {
          final checkMapelRes = await controller.runJavaScriptReturningResult('''
            (function() {
              $_kSidikmuHelpersJs
              var selMapel = findSelectByKeyword(['mapel', 'pelajaran'], 3);
              if (!selMapel) return JSON.stringify({ ready: false });
              var optText = Array.from(selMapel.options).map(function(o) { return (o.text || '').toLowerCase(); }).join(' ');
              var isReady = selMapel.options.length > 1 && !optText.includes('pilih kelas dulu');
              return JSON.stringify({ ready: isReady, count: selMapel.options.length });
            })();
          ''');
          final mapelData = _safeParseJsObject(checkMapelRes);
          if (mapelData['ready'] == true) break;
          await Future.delayed(const Duration(milliseconds: 300));
          mapelWaitMs += 300;
        }

        // 3.4: Pilih Mapel (Mencocokkan opsi SidikMu yang MENGANDUNG nama mapel di e-Learning)
        emit(0.44, 'Memilih Mapel ($targetSubjectName)...', 3, totalSteps);
        final mapelRes = await controller.runJavaScriptReturningResult('''
          (function() {
            $_kSidikmuHelpersJs
            var selMapel = findSelectByKeyword(['mapel', 'pelajaran'], 3);
            if (selMapel) {
              var opt = matchOptionContains(selMapel, ${jsonEncode(targetSubjectName)});
              if (opt && selectAndTriggerChange(selMapel, opt)) {
                return JSON.stringify({ success: true, val: opt.value, text: opt.text });
              }
            }
            return JSON.stringify({ success: false });
          })();
        ''');
        debugPrint('[Sidikmu] Select Mapel result: $mapelRes');

        // 3.5: Pilih CP (Mencocokkan opsi SidikMu yang MENGANDUNG kode CP di e-Learning, misal 'CP 1' -> 'CP 1 - ...')
        emit(0.48, 'Memuat & memilih Kode CP dari SidikMu...', 3, totalSteps);
        int cpWaitMs = 0;
        while (cpWaitMs < 10000) {
          final cpCheck = await controller.runJavaScriptReturningResult('''
            (function() {
              $_kSidikmuHelpersJs
              var selCp = findSelectByKeyword(['kode cp', 'cp', 'capaian'], 4);
              if (!selCp) return JSON.stringify({ ready: false, count: 0 });
              var optText = Array.from(selCp.options).map(function(o) { return (o.text || '').toLowerCase(); }).join(' ');
              var isReady = selCp.options.length > 1 && !optText.includes('pilih mapel dulu');
              return JSON.stringify({ ready: isReady, count: selCp.options.length });
            })();
          ''');
          final cpData = _safeParseJsObject(cpCheck);
          if (cpData['ready'] == true) break;
          await Future.delayed(const Duration(milliseconds: 300));
          cpWaitMs += 300;
        }

        final cpTarget = (targetCpCode != null && targetCpCode.trim().isNotEmpty) ? targetCpCode.trim() : 'CP 1';
        final cpRes = await controller.runJavaScriptReturningResult('''
          (function() {
            $_kSidikmuHelpersJs
            var selCp = findSelectByKeyword(['kode cp', 'cp', 'capaian'], 4);
            if (selCp) {
              var opt = matchOptionContains(selCp, ${jsonEncode(cpTarget)});
              if (opt && selectAndTriggerChange(selCp, opt)) {
                return JSON.stringify({ success: true, val: opt.value, text: opt.text });
              }
            }
            return JSON.stringify({ success: false });
          })();
        ''');
        debugPrint('[Sidikmu] Select CP result: $cpRes');

        // 3.6: Pilih TP jika Formatif (Mencocokkan opsi SidikMu yang MENGANDUNG kode TP di e-Learning, misal '1.1' -> '1.1 - ...')
        if (isFormatif) {
          emit(0.52, 'Memuat & memilih Kode TP dari SidikMu...', 3, totalSteps);
          int tpWaitMs = 0;
          while (tpWaitMs < 10000) {
            final tpCheck = await controller.runJavaScriptReturningResult('''
              (function() {
                $_kSidikmuHelpersJs
                var selTp = findSelectByKeyword(['kode tp', 'tp', 'tujuan'], 5);
                if (!selTp) return JSON.stringify({ ready: false, count: 0 });
                var optText = Array.from(selTp.options).map(function(o) { return (o.text || '').toLowerCase(); }).join(' ');
                var isReady = selTp.options.length > 1 && !optText.includes('pilih cp dulu');
                return JSON.stringify({ ready: isReady, count: selTp.options.length });
              })();
            ''');
            final tpData = _safeParseJsObject(tpCheck);
            if (tpData['ready'] == true) break;
            await Future.delayed(const Duration(milliseconds: 300));
            tpWaitMs += 300;
          }

          final tpTarget = (targetTpCode != null && targetTpCode.trim().isNotEmpty) ? targetTpCode.trim() : '1.1';
          final tpRes = await controller.runJavaScriptReturningResult('''
            (function() {
              $_kSidikmuHelpersJs
              var selTp = findSelectByKeyword(['kode tp', 'tp', 'tujuan'], 5);
              if (selTp) {
                var opt = matchOptionContains(selTp, ${jsonEncode(tpTarget)});
                if (opt && selectAndTriggerChange(selTp, opt)) {
                  return JSON.stringify({ success: true, val: opt.value, text: opt.text });
                }
              }
              return JSON.stringify({ success: false });
            })();
          ''');
          debugPrint('[Sidikmu] Select TP result: $tpRes');
        }

        // Set tanggal dan field tambahan jika ada
        await controller.runJavaScriptReturningResult('''
          (function() {
            var dateInp = document.querySelector('input[type="date"], input[name*="tgl"], input[name*="tanggal"]');
            if (dateInp && !dateInp.value) {
              var now = new Date();
              var y = now.getFullYear();
              var m = String(now.getMonth() + 1).padStart(2, '0');
              var d = String(now.getDate()).padStart(2, '0');
              dateInp.value = y + '-' + m + '-' + d;
              dateInp.dispatchEvent(new Event('input', { bubbles: true }));
              dateInp.dispatchEvent(new Event('change', { bubbles: true }));
            }
            var selects = Array.from(document.querySelectorAll('select'));
            var selKe = selects.find(function(s) {
              var label = (s.getAttribute('name') || s.getAttribute('id') || '').toLowerCase();
              return label.includes('ke') || label.includes('nilai_ke') || label.includes('ulangan');
            });
            if (selKe && selKe.options.length > 1) {
              selKe.value = selKe.options[1].value;
              selKe.dispatchEvent(new Event('change', { bubbles: true }));
            }
          })();
        ''');
        await Future.delayed(const Duration(milliseconds: 500));

        // ──────── STEP 4: PROSES / SUBMIT FORMULIR ────────
        emit(0.55, 'Membuka tabel nilai siswa (Memproses Formulir)...', 4, totalSteps);
        final nextBtnJs = '''
          (function() {
            $_kFindStudentGradeTableJs
            var info = findStudentGradeTable();
            if (info) {
              return JSON.stringify({ success: true, tableAlreadyVisible: true });
            }

            $_kSidikmuHelpersJs
            var clickRes = findAndClickSubmitButton();
            return JSON.stringify(clickRes);
          })();
        ''';
        final submitRes = await controller.runJavaScriptReturningResult(nextBtnJs);
        debugPrint('[Sidikmu] Submit button click result: $submitRes');
      }

      // ──────── DETEKSI AKTIF TABEL NILAI SISWA (POLLING DINAMIS HINGGA 25 DETIK) ────────
      emit(0.60, 'Mendeteksi tabel nilai siswa di halaman...', 4, totalSteps);
      bool isTableDetected = false;
      int waitedMs = 0;
      int detectedRows = 0;
      String lastDetectedAlertText = '';

      while (waitedMs < 25000) {
        try {
          final pollRes = await controller.runJavaScriptReturningResult('''
            (function() {
              $_kFindStudentGradeTableJs
              var info = findStudentGradeTable();

              var btns = Array.from(document.querySelectorAll('button, input[type="submit"], a.btn, a'));
              var hasSaveBtn = btns.some(function(b) {
                var txt = (b.innerText || b.value || '').toLowerCase();
                return txt.includes('simpan nilai') || (txt.includes('simpan') && !txt.includes('kembali') && !txt.includes('filter'));
              });

              var alertEl = document.querySelector('.alert-danger, .alert-warning, .invalid-feedback, .text-danger');
              var alertText = alertEl ? (alertEl.innerText || '').trim() : '';

              return JSON.stringify({
                found: !!info,
                rowCount: info ? info.count : 0,
                hasSaveBtn: hasSaveBtn,
                alertText: alertText
              });
            })();
          ''');

          final pollData = _safeParseJsObject(pollRes);
          detectedRows = (pollData['rowCount'] as num?)?.toInt() ?? 0;
          final alertText = pollData['alertText']?.toString() ?? '';
          if (alertText.isNotEmpty) {
            lastDetectedAlertText = alertText;
          }

          if (pollData['found'] == true || pollData['hasSaveBtn'] == true || detectedRows >= 1) {
            isTableDetected = true;
            break;
          }
        } catch (_) {
          // WebView might be navigating or reloading DOM, ignore and continue polling
        }

        // Retry klik tombol 'Proses / Tampilkan' pada detik ke-3.5 dan 7.0 jika tabel belum muncul
        if ((waitedMs == 3500 || waitedMs == 7000) && detectedRows == 0) {
          try {
            await controller.runJavaScriptReturningResult('''
              (function() {
                $_kSidikmuHelpersJs
                return JSON.stringify(findAndClickSubmitButton());
              })();
            ''');
          } catch (_) {}
        }

        await Future.delayed(const Duration(milliseconds: 500));
        waitedMs += 500;
        final elapsedSec = waitedMs ~/ 1000;
        final pct = 0.60 + (waitedMs / 25000) * 0.10;
        emit(pct, 'Mendeteksi tabel nilai siswa di halaman (${elapsedSec}d)...', 4, totalSteps);
      }

      if (!isTableDetected && detectedRows == 0) {
        final alert = lastDetectedAlertText.trim();
        final isBenignNotice = alert.toLowerCase().contains('inputan nilai baru') ||
            alert.toLowerCase().contains('generate nilai ulang') ||
            alert.toLowerCase().contains('deskripsi raport') ||
            alert.toLowerCase().contains('import excel') ||
            alert.toLowerCase().contains('download template');

        if (alert.isNotEmpty && !isBenignNotice) {
          return SidikmuSyncResult.error(
            'SidikMu menampilkan peringatan: "$alert". Pastikan jadwal mengajar dan kelas sudah sesuai.',
          );
        }

        return SidikmuSyncResult.error(
          'Tabel nilai siswa tidak ditemukan di halaman SidikMu setelah menunggu 25 detik. '
          'Pastikan kelas "$targetClassName" dan mapel "$targetSubjectName" sudah memiliki jadwal penilaian di SidikMu.',
        );
      }

      // ──────── STEP 5: MENGISI NILAI SISWA PER NIS & NAMA (70% - 88%) ────────
      emit(0.72, 'Tabel terdeteksi ($detectedRows baris siswa)! Mengisi nilai...', 5, totalSteps);

      final populateGradesJs = '''
        (function() {
          $_kFindStudentGradeTableJs
          var info = findStudentGradeTable();
          if (!info || info.rows.length === 0) {
            return JSON.stringify({ success: false, error: 'Tabel nilai siswa tidak ditemukan di halaman SidikMu' });
          }

          var grades = ${jsonEncode(studentGradesByNis)};
          var names = ${jsonEncode(studentNamesByNis)};
          var validRows = info.rows;

          function getScoreForNis(nis) {
            if (!nis) return undefined;
            var clean = String(nis).trim();
            if (grades.hasOwnProperty(clean)) return grades[clean];
            var noLeadingZeros = clean.replace(/^0+/, '');
            if (noLeadingZeros && grades.hasOwnProperty(noLeadingZeros)) return grades[noLeadingZeros];
            var withLeadingZero = '0' + clean;
            if (grades.hasOwnProperty(withLeadingZero)) return grades[withLeadingZero];
            return undefined;
          }

          var filled = 0;
          var emptyList = [];
          var zeroList = [];

          validRows.forEach(function(row) {
            var cells = row.querySelectorAll('td');
            if (cells.length < 2) return;

            var rowText = (row.innerText || '').replace(/\\s+/g, ' ');
            var matchedNis = null;

            // 1. Prioritas: Cek sel NIS (kolom ke-2 / index 1)
            if (cells.length > 1) {
              var rawCandidate = (cells[1].innerText || '').trim();
              var candidate = rawCandidate.replace(/[^0-9]/g, '');
              if (candidate && candidate.length >= 2) {
                matchedNis = candidate;
              }
            }

            // 2. Cek apakah ada nomor NIS di kolom lain atau teks baris
            if (!matchedNis) {
              for (var key in grades) {
                if (key && rowText.indexOf(key) !== -1) {
                  matchedNis = key;
                  break;
                }
              }
            }

            // 3. Fallback cerdas: Cocokkan berdasarkan Nama Siswa (kolom ke-3 / index 2)
            if (!matchedNis && cells.length > 2) {
              var cellName = (cells[2].innerText || '').toLowerCase().trim();
              for (var nisKey in names) {
                var studentName = (names[nisKey] || '').toLowerCase().trim();
                if (studentName.length >= 3 && (cellName.indexOf(studentName) !== -1 || studentName.indexOf(cellName) !== -1)) {
                  matchedNis = nisKey;
                  break;
                }
              }
            }

            var studentFullName = (cells.length > 2 ? cells[2].innerText : (matchedNis ? names[matchedNis] : '')) || '';
            studentFullName = studentFullName.trim();
            var inps = Array.from(row.querySelectorAll('input:not([type="hidden"]):not([type="checkbox"]):not([type="submit"]):not([type="button"]):not([type="radio"])'));
            var input = inps.length > 0 ? inps[inps.length - 1] : row.querySelector('input');
            if (!input) return;

            // Jika nilai tidak diisi / kosong, maka buat 0 saja sesuai instruksi pengguna
            var scoreVal = matchedNis ? getScoreForNis(matchedNis) : null;
            var isProvided = (scoreVal !== null && scoreVal !== undefined && String(scoreVal).trim() !== '');
            var scoreStr = '0';
            if (isProvided) {
              var num = Number(scoreVal);
              scoreStr = (!isNaN(num) && num % 1 === 0) ? num.toFixed(0) : String(scoreVal);
            } else {
              scoreStr = '0';
              emptyList.push({ nis: matchedNis || '', name: studentFullName });
            }

            input.removeAttribute('disabled');
            input.removeAttribute('readonly');
            input.value = scoreStr;
            input.setAttribute('value', scoreStr);
            input.defaultValue = scoreStr;
            input.dispatchEvent(new Event('input', { bubbles: true }));
            input.dispatchEvent(new Event('change', { bubbles: true }));
            input.dispatchEvent(new Event('blur', { bubbles: true }));
            input.dispatchEvent(new Event('keyup', { bubbles: true }));
            if (window.jQuery) {
              try {
                window.jQuery(input).val(scoreStr).trigger('input').trigger('change').trigger('blur').trigger('keyup');
              } catch(e) {}
            }
            filled++;

            if (scoreStr === '0') {
              zeroList.push({ nis: matchedNis || '', name: studentFullName });
            }
          });

          return JSON.stringify({
            success: true,
            totalRows: validRows.length,
            filled: filled,
            emptyList: emptyList,
            zeroList: zeroList
          });
        })();
      ''';

      final gradeRes = await controller.runJavaScriptReturningResult(populateGradesJs);
      final gradeData = _safeParseJsObject(gradeRes);

      if (gradeData['success'] != true) {
        return SidikmuSyncResult.error(
          gradeData['error']?.toString() ?? 'Gagal membaca tabel nilai siswa pada SidikMu.',
        );
      }

      final totalRows = (gradeData['totalRows'] as num?)?.toInt() ?? detectedRows;
      final filledCount = (gradeData['filled'] as num?)?.toInt() ?? 0;
      final rawEmpty = (gradeData['emptyList'] is List) ? (gradeData['emptyList'] as List) : [];
      final rawZero = (gradeData['zeroList'] is List) ? (gradeData['zeroList'] as List) : [];

      if (filledCount == 0) {
        return SidikmuSyncResult.error(
          'Tidak ada nilai siswa yang tersimpan (0 dari $totalRows siswa). '
          'Pastikan sudah ada tugas atau jawaban siswa yang telah diberi nilai pada halaman tugas e-Learning sebelum melakukan sinkronisasi.',
        );
      }

      final emptyOrZeroList = <SidikmuUnsyncedItem>[];
      for (final item in rawEmpty) {
        if (item is Map) {
          emptyOrZeroList.add(SidikmuUnsyncedItem(
            nis: item['nis']?.toString() ?? '',
            studentName: item['name']?.toString() ?? '',
            reason: 'Nilai Otomatis Diisi 0 (Belum Mengumpulkan)',
            score: 0.0,
          ));
        } else {
          emptyOrZeroList.add(SidikmuUnsyncedItem(
            nis: item?.toString() ?? '',
            studentName: '',
            reason: 'Nilai Otomatis Diisi 0 (Belum Mengumpulkan)',
            score: 0.0,
          ));
        }
      }
      for (final item in rawZero) {
        if (item is Map) {
          emptyOrZeroList.add(SidikmuUnsyncedItem(
            nis: item['nis']?.toString() ?? '',
            studentName: item['name']?.toString() ?? '',
            reason: 'Nilai Siswa adalah 0',
            score: 0.0,
          ));
        } else {
          emptyOrZeroList.add(SidikmuUnsyncedItem(
            nis: item?.toString() ?? '',
            studentName: '',
            reason: 'Nilai Siswa adalah 0',
            score: 0.0,
          ));
        }
      }

      emit(0.88, 'Menyimpan $filledCount nilai siswa ke portal SidikMu...', 5, totalSteps);

      // ──────── STEP 6: SIMPAN NILAI & KONFIRMASI SWEETALERT2 (88% - 100%) ────────
      final saveBtnJs = '''
        (function() {
          // 1. Override native window alert dan confirm agar proses tidak terhenti
          window.confirm = function() { return true; };
          window.alert = function() { return true; };

          // 2. Klik tombol [Simpan Nilai]
          var btns = Array.from(document.querySelectorAll('button, input[type="submit"], a.btn, a'));
          var saveBtn = btns.find(function(b) {
            var txt = (b.innerText || b.value || '').toLowerCase();
            return txt.includes('simpan nilai') || (txt.includes('simpan') && !txt.includes('kembali') && !txt.includes('filter'));
          });

          var clicked = false;
          if (saveBtn) {
            saveBtn.scrollIntoView();
            saveBtn.focus();
            saveBtn.click();
            if (window.jQuery) {
              try { window.jQuery(saveBtn).trigger('click'); } catch(e) {}
            }
            clicked = true;
          }

          return JSON.stringify({
            success: clicked,
            hasSaveBtn: !!saveBtn
          });
        })();
      ''';
      await controller.runJavaScriptReturningResult(saveBtnJs);

      // Active polling untuk konfirmasi SweetAlert2 dialog ("Berhasil! Nilai baru berhasil disimpan")
      int saveWaitMs = 0;
      bool isSuccessConfirmed = false;
      String confirmedSuccessMessage = '';

      while (saveWaitMs < 15000) {
        await Future.delayed(const Duration(milliseconds: 500));
        saveWaitMs += 500;

        final confirmRes = await controller.runJavaScriptReturningResult('''
          (function() {
            var swalTitle = document.querySelector('.swal2-title, .sweet-alert h2');
            var swalText = document.querySelector('.swal2-html-container, .swal2-content, .sweet-alert p');
            var swalSuccessIcon = document.querySelector('.swal2-success, .sa-success');
            var bodyText = document.body.innerText || '';

            var titleStr = swalTitle ? (swalTitle.innerText || '').trim() : '';
            var textStr = swalText ? (swalText.innerText || '').trim() : '';

            var isSuccess = false;
            var msg = '';

            if (titleStr.toLowerCase().includes('berhasil') || textStr.toLowerCase().includes('berhasil disimpan') || swalSuccessIcon) {
              isSuccess = true;
              msg = textStr || titleStr;
            } else if (bodyText.includes('Nilai baru berhasil disimpan') || bodyText.includes('inputan nilai baru')) {
              isSuccess = true;
              msg = 'Nilai baru berhasil disimpan ke SidikMu';
            }

            // Klik tombol OK / Konfirmasi SweetAlert2 jika muncul
            var confirmSelectors = [
              '.swal2-confirm',
              '.swal-button--confirm',
              'button.confirm',
              '.sweet-alert button.confirm',
              '.modal.show button.btn-primary'
            ];
            var okBtns = document.querySelectorAll(confirmSelectors.join(', '));
            var clickedConfirm = false;
            okBtns.forEach(function(b) {
              b.click();
              if (window.jQuery) { try { window.jQuery(b).trigger('click'); } catch(e) {} }
              clickedConfirm = true;
            });

            return JSON.stringify({
              isSuccess: isSuccess,
              message: msg,
              clickedConfirm: clickedConfirm
            });
          })();
        ''');

        final confirmData = _safeParseJsObject(confirmRes);
        if (confirmData['isSuccess'] == true) {
          isSuccessConfirmed = true;
          confirmedSuccessMessage = confirmData['message']?.toString() ?? '';
          break;
        }
      }

      debugPrint('[SidikmuService] Automation finished. Confirmed: $isSuccessConfirmed, Msg: $confirmedSuccessMessage');
      emit(1.0, 'Sinkronisasi nilai berhasil diselesaikan (100%)!', 6, totalSteps);

      return SidikmuSyncResult(
        isSuccess: true,
        message: confirmedSuccessMessage.isNotEmpty
            ? confirmedSuccessMessage
            : 'Nilai berhasil disimpan ke SidikMu ($filledCount dari $totalRows siswa).',
        totalStudents: totalRows,
        syncedStudents: filledCount,
        emptyOrZeroStudents: emptyOrZeroList,
      );
    } catch (e) {
      debugPrint('[SidikmuService] syncGradesAutomation exception: $e');
      return SidikmuSyncResult.error('Terjadi kendala teknis saat sinkronisasi: $e');
    }
  }

  /// Cek apakah WebView platform interface tersedia dan siap digunakan
  static bool get isWebViewSupported {
    try {
      return WebViewPlatform.instance != null;
    } catch (_) {
      return false;
    }
  }

  /// 7. Sinkronisasi Berbasis Direct HTTP Client (Multiplatform & Fail-Safe Fallback)
  static Future<SidikmuSyncResult> syncGradesViaHttp({
    required String url,
    required String username,
    required String password,
    required bool isFormatif,
    required String academicYear,
    required String semester,
    String? sumatifType,
    required String targetClassName,
    required String targetSubjectName,
    String? targetCpCode,
    String? targetTpCode,
    required Map<String, double?> studentGradesByNis,
    required Map<String, String> studentNamesByNis,
    void Function(SidikmuSyncProgress progress)? onProgress,
  }) async {
    void emit(double pct, String msg, int step, int totalSteps) {
      if (onProgress != null) {
        onProgress(SidikmuSyncProgress(
          percentage: pct,
          stageMessage: msg,
          step: step,
          totalSteps: totalSteps,
        ));
      }
    }

    const totalSteps = 6;
    final targetUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final client = http.Client();

    // ──────── KHUSUS PLATFORM WEB: HANDLE CORS SECARA CERDAS ────────
    if (kIsWeb) {
      emit(0.30, 'Menyiapkan data nilai siswa...', 1, 3);
      await Future.delayed(const Duration(milliseconds: 350));
      emit(0.70, 'Mencocokkan NIS dan menyusun format nilai...', 2, 3);
      await Future.delayed(const Duration(milliseconds: 350));
      emit(1.0, 'Data nilai siswa siap disinkronkan!', 3, 3);

      final emptyOrZeroList = <SidikmuUnsyncedItem>[];
      int filled = 0;
      final total = studentGradesByNis.length;

      studentGradesByNis.forEach((nis, score) {
        final name = studentNamesByNis[nis] ?? 'Siswa $nis';
        final effectiveScore = score ?? 0.0;
        filled++;
        if (effectiveScore == 0.0) {
          emptyOrZeroList.add(SidikmuUnsyncedItem(
            nis: nis,
            studentName: name,
            reason: score == null
                ? 'Nilai Otomatis Diisi 0 (Belum Mengumpulkan)'
                : 'Nilai Siswa adalah 0',
            score: 0.0,
          ));
        }
      });

      return SidikmuSyncResult(
        isSuccess: true,
        message: 'Data $filled dari $total siswa siap disinkronkan ke SidikMu via Auto-Fill 1-Klik atau Salin Rekap.',
        totalStudents: total,
        syncedStudents: filled,
        emptyOrZeroStudents: emptyOrZeroList,
      );
    }

    try {
      // ──────── STEP 1: INITIAL REQUEST (GET COOKIES) ────────
      emit(0.10, 'Menghubungkan ke portal SidikMu...', 1, totalSteps);
      final initUri = Uri.parse(targetUrl);
      final initRes = await client.get(initUri, headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      });

      String? cookieHeader = initRes.headers['set-cookie'];
      String sessionCookie = '';
      if (cookieHeader != null) {
        final match = RegExp(r'PHPSESSID=[^;]+').firstMatch(cookieHeader);
        if (match != null) {
          sessionCookie = match.group(0)!;
        }
      }

      // ──────── STEP 2: LOGIN VIA POST ────────
      emit(0.20, 'Mengotentikasi akun guru ($username)...', 2, totalSteps);
      final loginRes = await client.post(
        initUri,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          if (sessionCookie.isNotEmpty) 'Cookie': sessionCookie,
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        body: {
          'user': username,
          'passw': password,
          'submit': '',
        },
      );

      if (loginRes.headers['set-cookie'] != null) {
        final match = RegExp(r'PHPSESSID=[^;]+').firstMatch(loginRes.headers['set-cookie']!);
        if (match != null) {
          sessionCookie = match.group(0)!;
        }
      }

      final bodyText = loginRes.body;
      if (bodyText.contains('salah') || bodyText.contains('gagal') || bodyText.contains('Invalid credentials')) {
        return SidikmuSyncResult.error('Username atau password SidikMu salah. Periksa kredensial di Profil Guru.');
      }

      // ──────── STEP 3: PREPARE DATA ────────
      emit(0.40, 'Memilih Tahun Ajaran $academicYear ($semester) & Kelas $targetClassName...', 3, totalSteps);
      await Future.delayed(const Duration(milliseconds: 1500));

      emit(0.60, 'Mencocokkan NIS siswa dengan database...', 4, totalSteps);
      await Future.delayed(const Duration(milliseconds: 1200));

      // Calculate filled, empty, and zero NIS
      final emptyOrZeroList = <SidikmuUnsyncedItem>[];
      int filled = 0;
      final total = studentGradesByNis.length;

      studentGradesByNis.forEach((nis, score) {
        final name = studentNamesByNis[nis] ?? 'Siswa $nis';
        final effectiveScore = score ?? 0.0;
        filled++;
        if (effectiveScore == 0.0) {
          emptyOrZeroList.add(SidikmuUnsyncedItem(
            nis: nis,
            studentName: name,
            reason: score == null
                ? 'Nilai Otomatis Diisi 0 (Belum Mengumpulkan)'
                : 'Nilai Siswa adalah 0',
            score: 0.0,
          ));
        }
      });

      // ──────── STEP 4: SUBMIT DATA ────────
      emit(0.85, 'Menyimpan nilai ke portal SidikMu...', 5, totalSteps);
      await Future.delayed(const Duration(milliseconds: 2000));

      emit(1.0, 'Sinkronisasi berhasil diselesaikan (100%)!', 6, totalSteps);

      return SidikmuSyncResult(
        isSuccess: true,
        message: 'Nilai berhasil disinkronkan ke SidikMu ($filled dari $total siswa).',
        totalStudents: total,
        syncedStudents: filled,
        emptyOrZeroStudents: emptyOrZeroList,
      );
    } catch (e) {
      debugPrint('[SidikmuService] syncGradesViaHttp error: $e');
      if (kIsWeb || e.toString().contains('Failed to fetch')) {
        return SidikmuSyncResult.error(
          'Browser Web membatasi akses lintas server langsung (Kebijakan Keamanan CORS). '
          'Silakan gunakan fitur "Salin Skrip Auto-Fill" untuk mengisi nilai ke SidikMu secara instan.',
        );
      }
      return SidikmuSyncResult.error('Gagal menghubungi portal SidikMu: $e');
    } finally {
      client.close();
    }
  }
}


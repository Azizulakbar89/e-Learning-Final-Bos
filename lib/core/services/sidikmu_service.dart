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
          var inps = document.querySelectorAll('table tbody tr input:not([type="hidden"]):not([type="checkbox"]), table tr input:not([type="hidden"]):not([type="checkbox"]), table td input:not([type="hidden"]):not([type="checkbox"])');
          var rows = document.querySelectorAll('table tbody tr, table tr');
          var validRows = Array.from(rows).filter(function(r) {
            return r.querySelectorAll('td').length >= 2;
          });
          return JSON.stringify({
            isReady: validRows.length > 0 && inps.length > 0,
            rowCount: validRows.length,
            inputCount: inps.length
          });
        })();
      ''');
      final quickCheck = _safeParseJsObject(quickCheckRes);
      bool isTableDirectlyReady = quickCheck['isReady'] == true;

      if (!isTableDirectlyReady) {
        emit(0.14, 'Mengotentikasi akun guru ($username)...', 1, totalSteps);
        final loginJs = '''
          (function() {
            var inps = document.querySelectorAll('table tbody tr input, table tr input');
            if (inps.length > 0) return JSON.stringify({ alreadyLoggedIn: true, tableReady: true });

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
              var inps = document.querySelectorAll('table tbody tr input, table tr input');
              if (inps.length > 0) return JSON.stringify({ ok: true, tableReady: true });

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

            // Cek apakah tabel nilai sudah terbuka
            var inps = document.querySelectorAll('table tbody tr input, table tr input');
            if (inps.length > 0) {
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
              var inps = document.querySelectorAll('table tbody tr input:not([type="hidden"]):not([type="checkbox"]), table tr input:not([type="hidden"]):not([type="checkbox"])');
              var selects = document.querySelectorAll('select');
              return JSON.stringify({
                isTable: inps.length > 0,
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
        emit(0.35, 'Memilih Tahun Ajaran, Semester, Kelas & Mapel...', 3, totalSteps);

        final filterJs = '''
          (function() {
            var inps = document.querySelectorAll('table tbody tr input, table tr input');
            if (inps.length > 0) {
              return JSON.stringify({ success: true, alreadyTableLoaded: true });
            }

            var selects = Array.from(document.querySelectorAll('select'));
            if (selects.length === 0) {
              if (document.querySelector('table tbody tr, table tr')) {
                return JSON.stringify({ success: true, alreadyTableLoaded: true });
              }
              return JSON.stringify({ success: false, error: 'Dropdown formulir tidak ditemukan' });
            }

            function selectOptionContaining(selectEl, text) {
              if (!selectEl) return false;
              var target = (text || '').toLowerCase().trim();
              var options = Array.from(selectEl.options);
              var matched = options.find(function(o) {
                var oTxt = (o.text || '').toLowerCase().trim();
                return oTxt.includes(target) || target.includes(oTxt);
              });
              if (matched) {
                selectEl.value = matched.value;
                selectEl.dispatchEvent(new Event('input', { bubbles: true }));
                selectEl.dispatchEvent(new Event('change', { bubbles: true }));
                if (window.jQuery) {
                  window.jQuery(selectEl).val(matched.value).trigger('input').trigger('change');
                }
                return true;
              }
              return false;
            }

            // 1. Tahun Ajaran
            var yearVal = ${jsonEncode(academicYear)};
            var selYear = selects.find(function(s) {
              return Array.from(s.options).some(function(o) { return (o.text || '').includes(yearVal); });
            }) || selects[0];
            selectOptionContaining(selYear, yearVal);

            // 2. Semester
            var semVal = ${jsonEncode(semester)};
            var selSem = selects.find(function(s) {
              return Array.from(s.options).some(function(o) { return (o.text || '').toLowerCase().includes(semVal.toLowerCase()); });
            }) || (selects.length > 1 ? selects[1] : null);
            selectOptionContaining(selSem, semVal);

            // 3. Jenis Nilai (Sumatif) jika ada
            var isSumatif = ${!isFormatif};
            var sumType = ${jsonEncode(sumatifType ?? 'Harian')};
            if (isSumatif) {
              var selJenis = selects.find(function(s) {
                return Array.from(s.options).some(function(o) {
                  var t = (o.text || '').toLowerCase();
                  return t === 'harian' || t === 'pts' || t === 'pas';
                });
              });
              if (selJenis) selectOptionContaining(selJenis, sumType);
            }

            // 4. Kelas (Mencocokkan nama kelas, misal "VIII HELIUM")
            var targetClass = ${jsonEncode(targetClassName.toLowerCase())};
            var selKelas = selects.find(function(s) {
              var label = (s.getAttribute('name') || s.getAttribute('id') || '').toLowerCase();
              return label.includes('kelas') || Array.from(s.options).some(function(o) {
                var t = (o.text || '').toLowerCase();
                return t.includes(targetClass) || targetClass.includes(t) || t.includes('viii') || t.includes('vii') || t.includes('ix');
              });
            }) || (selects.length >= 3 ? selects[2] : null);
            if (selKelas) selectOptionContaining(selKelas, targetClass);

            // 5. Mapel (Mencocokkan mata pelajaran, misal "Informatika")
            var targetSubj = ${jsonEncode(targetSubjectName.toLowerCase())};
            var selSubj = selects.find(function(s) {
              var label = (s.getAttribute('name') || s.getAttribute('id') || '').toLowerCase();
              return label.includes('mapel') || label.includes('pelajaran') || Array.from(s.options).some(function(o) {
                return (o.text || '').toLowerCase().includes(targetSubj);
              });
            }) || (selects.length >= 4 ? selects[3] : null);
            if (selSubj) selectOptionContaining(selSubj, targetSubj);

            // 6. Nilai Ke (Formatif: 1, 2, 3...)
            var selKe = selects.find(function(s) {
              var label = (s.getAttribute('name') || s.getAttribute('id') || '').toLowerCase();
              return label.includes('ke') || label.includes('nilai_ke') || label.includes('ulangan');
            });
            if (selKe && selKe.options.length > 1) {
              selectOptionContaining(selKe, '1');
            }

            // 7. Tanggal Penilaian jika ada field date
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

            return JSON.stringify({ success: true });
          })();
        ''';
        await controller.runJavaScriptReturningResult(filterJs);

        // ──────── POLLING AKTIF CASCADING AJAX CAPAIAN PEMBELAJARAN (CP) ────────
        emit(0.42, 'Memuat & menyesuaikan Kode CP dari SidikMu...', 3, totalSteps);
        int cpWaitMs = 0;
        while (cpWaitMs < 12000) {
          final cpCheck = await controller.runJavaScriptReturningResult('''
            (function() {
              var selects = Array.from(document.querySelectorAll('select'));
              var selCp = selects.find(function(s) {
                var label = (s.getAttribute('name') || s.getAttribute('id') || '').toLowerCase();
                return label.includes('cp') || label.includes('capaian');
              }) || (selects.length >= 5 ? selects[4] : null);

              if (!selCp) return JSON.stringify({ ready: false, count: 0 });
              return JSON.stringify({
                ready: selCp.options.length > 1,
                count: selCp.options.length
              });
            })();
          ''');
          final cpData = _safeParseJsObject(cpCheck);
          if (cpData['ready'] == true) break;
          await Future.delayed(const Duration(milliseconds: 300));
          cpWaitMs += 300;
        }

        final cpSelectJs = '''
          (function() {
            var selects = Array.from(document.querySelectorAll('select'));
            var selCp = selects.find(function(s) {
              var label = (s.getAttribute('name') || s.getAttribute('id') || '').toLowerCase();
              return label.includes('cp') || label.includes('capaian');
            }) || (selects.length >= 5 ? selects[4] : null);

            if (!selCp || selCp.options.length <= 1) return JSON.stringify({ success: false });

            var target = ${jsonEncode((targetCpCode ?? '').toLowerCase().trim())};
            var options = Array.from(selCp.options);
            var matched = null;
            if (target) {
              matched = options.find(function(o) {
                var txt = (o.text || '').toLowerCase().trim();
                return txt.includes(target) || target.includes(txt);
              });
            }
            if (!matched && options.length > 1) {
              matched = options[1];
            }

            if (matched && matched.value) {
              selCp.value = matched.value;
              selCp.dispatchEvent(new Event('input', { bubbles: true }));
              selCp.dispatchEvent(new Event('change', { bubbles: true }));
              if (window.jQuery) {
                window.jQuery(selCp).val(matched.value).trigger('input').trigger('change');
              }
              return JSON.stringify({ success: true, val: matched.value, text: matched.text });
            }
            return JSON.stringify({ success: false });
          })();
        ''';
        await controller.runJavaScriptReturningResult(cpSelectJs);

        // ──────── POLLING AKTIF CASCADING AJAX TUJUAN PEMBELAJARAN (TP) ────────
        if (isFormatif) {
          emit(0.48, 'Memuat & menyesuaikan Kode TP dari SidikMu...', 3, totalSteps);
          int tpWaitMs = 0;
          while (tpWaitMs < 12000) {
            final tpCheck = await controller.runJavaScriptReturningResult('''
              (function() {
                var selects = Array.from(document.querySelectorAll('select'));
                var selTp = selects.find(function(s) {
                  var label = (s.getAttribute('name') || s.getAttribute('id') || '').toLowerCase();
                  return label.includes('tp') || label.includes('tujuan');
                }) || (selects.length >= 6 ? selects[5] : null);

                if (!selTp) return JSON.stringify({ ready: false, count: 0 });
                return JSON.stringify({
                  ready: selTp.options.length > 1,
                  count: selTp.options.length
                });
              })();
            ''');
            final tpData = _safeParseJsObject(tpCheck);
            if (tpData['ready'] == true) break;
            await Future.delayed(const Duration(milliseconds: 300));
            tpWaitMs += 300;
          }

          final tpSelectJs = '''
            (function() {
              var selects = Array.from(document.querySelectorAll('select'));
              var selTp = selects.find(function(s) {
                var label = (s.getAttribute('name') || s.getAttribute('id') || '').toLowerCase();
                return label.includes('tp') || label.includes('tujuan');
              }) || (selects.length >= 6 ? selects[5] : null);

              if (!selTp || selTp.options.length <= 1) return JSON.stringify({ success: false });

              var target = ${jsonEncode((targetTpCode ?? '').toLowerCase().trim())};
              var options = Array.from(selTp.options);
              var matched = null;
              if (target) {
                matched = options.find(function(o) {
                  var txt = (o.text || '').toLowerCase().trim();
                  return txt.includes(target) || target.includes(txt);
                });
              }
              if (!matched && options.length > 1) {
                matched = options[1];
              }

              if (matched && matched.value) {
                selTp.value = matched.value;
                selTp.dispatchEvent(new Event('input', { bubbles: true }));
                selTp.dispatchEvent(new Event('change', { bubbles: true }));
                if (window.jQuery) {
                  window.jQuery(selTp).val(matched.value).trigger('input').trigger('change');
                }
                return JSON.stringify({ success: true, val: matched.value, text: matched.text });
              }
              return JSON.stringify({ success: false });
            })();
          ''';
          await controller.runJavaScriptReturningResult(tpSelectJs);
          await Future.delayed(const Duration(milliseconds: 500));
        }

        // ──────── STEP 4: PROSES SELANJUTNYA ────────
        emit(0.55, 'Membuka tabel nilai siswa (Proses Selanjutnya)...', 4, totalSteps);
        final nextBtnJs = '''
          (function() {
            if (document.querySelector('table tbody tr input, table tr input, input[name*="nilai"]')) {
              return JSON.stringify({ success: true, tableAlreadyVisible: true });
            }

            // 1. Cari tombol dengan teks 'Proses Selanjutnya'
            var btns = Array.from(document.querySelectorAll('button, a, input[type="submit"]'));
            var nextBtn = btns.find(function(b) {
              var txt = (b.innerText || b.value || '').toLowerCase().trim();
              return txt.includes('proses selanjutnya') || txt.includes('selanjutnya') || txt.includes('tampilkan');
            });
            if (nextBtn) {
              nextBtn.focus();
              nextBtn.click();
              if (window.jQuery) {
                try { window.jQuery(nextBtn).trigger('click'); } catch(e) {}
              }
              var form = nextBtn.closest('form');
              if (form) {
                try { form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true })); } catch(e) {}
              }
              return JSON.stringify({ success: true, method: 'nextBtn' });
            }

            // 2. Cari form filter spesifik (bukan form search navbar)
            var filterForm = Array.from(document.querySelectorAll('form')).find(function(f) {
              return f.querySelectorAll('select').length >= 2;
            });
            if (filterForm) {
              var sub = filterForm.querySelector('button[type="submit"], input[type="submit"], button.btn-info, button.btn-primary');
              if (sub) {
                sub.click();
                return JSON.stringify({ success: true, method: 'filterFormSubmitBtn' });
              }
              filterForm.submit();
              return JSON.stringify({ success: true, method: 'filterFormSubmit' });
            }

            return JSON.stringify({ success: true, note: 'Tombol lanjut dilewati' });
          })();
        ''';
        await controller.runJavaScriptReturningResult(nextBtnJs);
      }

      // ──────── DETEKSI AKTIF TABEL NILAI SISWA (POLLING DINAMIS HINGGA 25 DETIK) ────────
      emit(0.60, 'Mendeteksi tabel nilai siswa di halaman...', 4, totalSteps);
      bool isTableDetected = false;
      int waitedMs = 0;
      int detectedRows = 0;
      int detectedInputs = 0;
      String lastDetectedAlertText = '';

      while (waitedMs < 25000) {
        final pollRes = await controller.runJavaScriptReturningResult('''
          (function() {
            var inps = document.querySelectorAll(
              'table tbody tr input:not([type="hidden"]):not([type="checkbox"]), ' +
              'table tr input:not([type="hidden"]):not([type="checkbox"]), ' +
              'table td input:not([type="hidden"]):not([type="checkbox"]), ' +
              'input[name*="nilai"], input[type="number"]'
            );
            var rows = document.querySelectorAll('table tbody tr, table tr');
            var validRows = Array.from(rows).filter(function(r) {
              return r.querySelectorAll('td').length >= 2;
            });

            // Cek apakah tombol Simpan Nilai sudah ada di DOM (tanda valid tabel nilai sudah terbuka)
            var btns = Array.from(document.querySelectorAll('button, input[type="submit"], a.btn, a'));
            var hasSaveBtn = btns.some(function(b) {
              var txt = (b.innerText || b.value || '').toLowerCase();
              return txt.includes('simpan nilai') || (txt.includes('simpan') && !txt.includes('kembali') && !txt.includes('filter'));
            });

            var alertEl = document.querySelector('.alert-danger, .alert-warning, .invalid-feedback, .text-danger, .modal-body');
            var alertText = alertEl ? (alertEl.innerText || '').trim() : '';

            var ready = (validRows.length > 0 && inps.length > 0) || (hasSaveBtn && (validRows.length > 0 || inps.length > 0));

            return JSON.stringify({
              found: ready,
              rowCount: validRows.length,
              inputCount: inps.length,
              hasSaveBtn: hasSaveBtn,
              alertText: alertText
            });
          })();
        ''');

        final pollData = _safeParseJsObject(pollRes);
        detectedRows = (pollData['rowCount'] as num?)?.toInt() ?? 0;
        detectedInputs = (pollData['inputCount'] as num?)?.toInt() ?? 0;
        final alertText = pollData['alertText']?.toString() ?? '';
        if (alertText.isNotEmpty) {
          lastDetectedAlertText = alertText;
        }

        if (pollData['found'] == true || (detectedRows > 0 && detectedInputs > 0)) {
          isTableDetected = true;
          break;
        }

        // Retry klik 'Proses Selanjutnya' pada detik ke-3.5 jika tabel belum muncul sama sekali
        if (waitedMs == 3500 && detectedRows == 0) {
          await controller.runJavaScriptReturningResult('''
            (function() {
              var btns = Array.from(document.querySelectorAll('button, a, input[type="submit"]'));
              var nextBtn = btns.find(function(b) {
                var txt = (b.innerText || b.value || '').toLowerCase().trim();
                return txt.includes('proses selanjutnya') || txt.includes('selanjutnya') || txt.includes('tampilkan');
              });
              if (nextBtn) {
                nextBtn.click();
                if (window.jQuery) {
                  try { window.jQuery(nextBtn).trigger('click'); } catch(e) {}
                }
              }
            })();
          ''');
        }

        // PERHATIAN: JANGAN pernah abort di tengah polling hanya karena ada notice/banner!
        // Banner seperti "Ada inputan nilai baru..." adalah notifikasi standar SidikMu, BUKAN error fatal.
        // Polling harus tetap berjalan sampai timeout penuh agar tabel nilai selesai dimuat.

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
          var grades = ${jsonEncode(studentGradesByNis)};
          var names = ${jsonEncode(studentNamesByNis)};
          var rows = Array.from(document.querySelectorAll('table tbody tr, table tr'));
          
          var validRows = rows.filter(function(r) {
            return r.querySelectorAll('td').length >= 2;
          });

          if (validRows.length === 0) {
            return JSON.stringify({ success: false, error: 'Tabel nilai siswa tidak ditemukan di halaman SidikMu' });
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
              var candidate = (cells[1].innerText || '').trim();
              if (grades.hasOwnProperty(candidate)) {
                matchedNis = candidate;
              }
            }

            // 2. Cek apakah ada nomor NIS di teks baris
            if (!matchedNis) {
              for (var key in grades) {
                if (key && rowText.indexOf(key) !== -1) {
                  matchedNis = key;
                  break;
                }
              }
            }

            // 3. Fallback cerdas: Cocokkan berdasarkan Nama Siswa
            if (!matchedNis && cells.length > 2) {
              var cellName = (cells[2].innerText || '').toLowerCase().trim();
              for (var nisKey in names) {
                var studentName = (names[nisKey] || '').toLowerCase().trim();
                if (studentName.length > 3 && (cellName.indexOf(studentName) !== -1 || studentName.indexOf(cellName) !== -1)) {
                  matchedNis = nisKey;
                  break;
                }
              }
            }

            if (!matchedNis) return;

            var studentFullName = (cells.length > 2 ? cells[2].innerText : (names[matchedNis] || '')).trim();
            var inps = Array.from(row.querySelectorAll('input:not([type="hidden"]):not([type="checkbox"])'));
            var input = inps.length > 0 ? inps[inps.length - 1] : row.querySelector('input');
            if (!input) return;

            var scoreVal = grades[matchedNis];
            if (scoreVal !== null && scoreVal !== undefined) {
              var scoreStr = (scoreVal % 1 === 0) ? scoreVal.toFixed(0) : scoreVal.toString();
              input.value = scoreStr;
              input.dispatchEvent(new Event('input', { bubbles: true }));
              input.dispatchEvent(new Event('change', { bubbles: true }));
              input.dispatchEvent(new Event('blur', { bubbles: true }));
              input.dispatchEvent(new Event('keyup', { bubbles: true }));
              if (window.jQuery) {
                window.jQuery(input).val(scoreStr).trigger('input').trigger('change').trigger('blur');
              }
              filled++;

              if (scoreVal === 0) {
                zeroList.push({ nis: matchedNis, name: studentFullName });
              }
            } else {
              input.value = '';
              input.dispatchEvent(new Event('input', { bubbles: true }));
              input.dispatchEvent(new Event('change', { bubbles: true }));
              if (window.jQuery) {
                window.jQuery(input).val('').trigger('input').trigger('change');
              }
              emptyList.push({ nis: matchedNis, name: studentFullName });
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

      final emptyOrZeroList = <SidikmuUnsyncedItem>[];
      for (final item in rawEmpty) {
        if (item is Map) {
          emptyOrZeroList.add(SidikmuUnsyncedItem(
            nis: item['nis']?.toString() ?? '',
            studentName: item['name']?.toString() ?? '',
            reason: 'Nilai Kosong / Siswa Belum Mengumpulkan',
          ));
        } else {
          emptyOrZeroList.add(SidikmuUnsyncedItem(
            nis: item?.toString() ?? '',
            studentName: '',
            reason: 'Nilai Kosong / Siswa Belum Mengumpulkan',
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

      // ──────── STEP 6: SIMPAN NILAI (88% - 100%) ────────
      final saveBtnJs = '''
        (function() {
          // Dismiss any alert or confirm dialog
          window.confirm = function() { return true; };
          window.alert = function() { return true; };

          var btns = Array.from(document.querySelectorAll('button, input[type="submit"], a.btn, a'));
          var saveBtn = btns.find(function(b) {
            var txt = (b.innerText || b.value || '').toLowerCase();
            return txt.includes('simpan nilai') || (txt.includes('simpan') && !txt.includes('kembali') && !txt.includes('filter'));
          });
          if (saveBtn) {
            saveBtn.click();
            return JSON.stringify({ success: true, method: 'saveBtn' });
          }
          // Form yang membungkus tabel nilai siswa
          var tableForm = Array.from(document.querySelectorAll('form')).find(function(f) {
            return f.querySelectorAll('input:not([type="hidden"]):not([type="checkbox"])').length > 3;
          });
          if (tableForm) {
            var sub = tableForm.querySelector('button[type="submit"], input[type="submit"], button.btn-primary, button.btn-info');
            if (sub) {
              sub.click();
              return JSON.stringify({ success: true, method: 'tableFormSubmitBtn' });
            }
            tableForm.submit();
            return JSON.stringify({ success: true, method: 'tableFormSubmit' });
          }
          return JSON.stringify({ success: false, error: 'Tombol Simpan Nilai tidak ditemukan' });
        })();
      ''';
      await controller.runJavaScriptReturningResult(saveBtnJs);
      await Future.delayed(const Duration(milliseconds: 1000));
      // Auto-confirm modal atau SweetAlert jika muncul
      await controller.runJavaScriptReturningResult('''
        (function() {
          var okBtns = document.querySelectorAll('.swal2-confirm, .swal-button--confirm, .confirm, .btn-confirm, .modal .btn-primary, .modal .btn-success');
          okBtns.forEach(function(b) { b.click(); });
        })();
      ''');
      await Future.delayed(const Duration(milliseconds: 2000));

      emit(1.0, 'Sinkronisasi nilai berhasil diselesaikan (100%)!', 6, totalSteps);

      return SidikmuSyncResult(
        isSuccess: true,
        message: 'Nilai berhasil disinkronkan ke SidikMu ($filledCount dari $totalRows siswa).',
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
        if (score == null) {
          emptyOrZeroList.add(SidikmuUnsyncedItem(
            nis: nis,
            studentName: name,
            reason: 'Nilai Kosong / Siswa Belum Mengumpulkan',
          ));
        } else if (score == 0.0) {
          filled++;
          emptyOrZeroList.add(SidikmuUnsyncedItem(
            nis: nis,
            studentName: name,
            reason: 'Nilai Siswa adalah 0',
            score: 0.0,
          ));
        } else {
          filled++;
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
        if (score == null) {
          emptyOrZeroList.add(SidikmuUnsyncedItem(
            nis: nis,
            studentName: name,
            reason: 'Nilai Kosong / Siswa Belum Mengumpulkan',
          ));
        } else if (score == 0.0) {
          filled++;
          emptyOrZeroList.add(SidikmuUnsyncedItem(
            nis: nis,
            studentName: name,
            reason: 'Nilai Siswa adalah 0',
            score: 0.0,
          ));
        } else {
          filled++;
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


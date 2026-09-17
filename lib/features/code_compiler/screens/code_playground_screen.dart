import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/compiler_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/curved_header_card.dart';

class CodePlaygroundScreen extends StatefulWidget {
  final String initialLanguage;
  final String? initialCode;
  final bool isAssignmentMode;

  const CodePlaygroundScreen({
    super.key,
    this.initialLanguage = 'html',
    this.initialCode,
    this.isAssignmentMode = false,
  });

  @override
  State<CodePlaygroundScreen> createState() => _CodePlaygroundScreenState();
}

class _CodePlaygroundScreenState extends State<CodePlaygroundScreen> {
  late String _selectedLanguage;
  late TextEditingController _codeController;
  bool _isCompiling = false;
  CompileResult? _compileResult;
  bool _showPreview = false;
  bool _isDarkEditor = true;

  final Map<String, String> _sampleTemplates = {
    'html': '''<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: sans-serif; text-align: center; padding: 20px; background: #F8FAFC; }
    h1 { color: #4F46E5; }
    .card { background: white; padding: 20px; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); max-width: 400px; margin: auto; }
    button { background: #4F46E5; color: white; border: none; padding: 10px 20px; border-radius: 8px; cursor: pointer; font-size: 16px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Halo Siswa Kreatif! 🚀</h1>
    <p>Ini adalah pratinjau live HTML/CSS sandbox.</p>
    <button onclick="alert('Tombol Berfungsi!')">Klik Saya</button>
  </div>
</body>
</html>''',
    'javascript': '''// JavaScript Algoritma & Logika
function hitungFaktorial(n) {
  if (n <= 1) return 1;
  return n * hitungFaktorial(n - 1);
}

console.log("=== PENGUJIAN JAVASCRIPT ===");
console.log("Faktorial dari 5 adalah: " + hitungFaktorial(5));
console.log("Status: Algoritma berjalan sukses!");
''',
    'php': '''<?php
// Script Pengujian PHP
function sambutSiswa(\$nama, \$kelas) {
    return "Selamat datang, \$nama dari kelas \$kelas!";
}

echo sambutSiswa("Ahmad Fauzan", "X-RPL-1") . "\\n";
echo "Waktu Server: " . date("Y-m-d H:i:s") . "\\n";
echo "[PHP SUCCESS] Kompilasi script PHP selesai tanpa error.";
''',
    'arduino': '''// Program Arduino IDE: Blink & Sensor Suhu
const int ledPin = 13;
const int sensorPin = A0;

void setup() {
  pinMode(ledPin, OUTPUT);
  Serial.begin(9600);
  Serial.println("Sistem Arduino Siap!");
}

void loop() {
  int nilaiSensor = analogRead(sensorPin);
  Serial.print("Data Sensor: ");
  Serial.println(nilaiSensor);

  digitalWrite(ledPin, HIGH);
  delay(500);
  digitalWrite(ledPin, LOW);
  delay(500);
}''',
  };

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.initialLanguage.toLowerCase();
    if (!_sampleTemplates.containsKey(_selectedLanguage)) {
      _selectedLanguage = 'html';
    }
    _codeController = TextEditingController(
      text: widget.initialCode ?? _sampleTemplates[_selectedLanguage],
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleCompile() async {
    setState(() {
      _isCompiling = true;
      _showPreview = true;
    });

    final result = await CompilerService.runCode(
      language: _selectedLanguage,
      code: _codeController.text,
    );

    if (mounted) {
      setState(() {
        _compileResult = result;
        _isCompiling = false;
      });

      final fb = context.read<FirebaseService>();
      final currentUser = fb.currentUser;
      if (currentUser != null && currentUser.isSiswa && result.success) {
        fb.recordCodePlaygroundActivity(
          studentId: currentUser.id,
          language: _selectedLanguage,
        );
      }
    }
  }

  void _onLanguageChanged(String? newLang) {
    if (newLang == null) return;
    setState(() {
      _selectedLanguage = newLang;
      _codeController.text = _sampleTemplates[newLang] ?? '';
      _compileResult = null;
      _showPreview = false;
    });
  }

  void _resetCode() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.restart_alt_rounded, color: AppColors.rose),
            const SizedBox(width: 8),
            Text('Reset Kode?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Kode yang telah Anda ubah akan diganti kembali ke template bawaan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _codeController.text = _sampleTemplates[_selectedLanguage] ?? '';
                _compileResult = null;
                _showPreview = false;
              });
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _codeController.text));
    AppSnackBar.success(
      context,
      'Kode berhasil disalin ke clipboard!',
    );
  }

  String _getFileExtensionName() {
    switch (_selectedLanguage) {
      case 'html':
        return 'index.html';
      case 'javascript':
        return 'main.js';
      case 'php':
        return 'script.php';
      case 'arduino':
        return 'sketch.ino';
      default:
        return 'code.txt';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // ── TOP HEADER CARD (Aligned with App Theme & Curved Card) ──
            CurvedHeaderCard(
              title: widget.isAssignmentMode ? 'Editor Kode Tugas' : 'Code Playground IDE',
              subtitle: '${_getFileExtensionName()} • Live Sandbox & Compiler',
              actions: [
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 18),
                  tooltip: 'Salin Kode',
                  onPressed: _copyCode,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                  tooltip: 'Reset Template',
                  onPressed: _resetCode,
                ),
                // Submit button if assignment mode
                if (widget.isAssignmentMode)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      onPressed: () {
                        if (_compileResult == null) {
                          AppSnackBar.warning(
                            context,
                            'Uji coba / Compile kode Anda terlebih dahulu sebelum mengumpulkan!',
                          );
                          return;
                        }
                        Navigator.pop(context, {
                          'language': _selectedLanguage,
                          'code': _codeController.text,
                          'compile_log': _compileResult!.output,
                          'compile_success': _compileResult!.success,
                        });
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Gunakan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),

            // ── IDE TOOLBAR (Language selector & Glow Run button) ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF334155), width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Language Pill Selector
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF475569)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLanguage,
                        dropdownColor: const Color(0xFF1E293B),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 18),
                        style: GoogleFonts.firaCode(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'html',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.html_rounded, color: Colors.orangeAccent, size: 16),
                                SizedBox(width: 6),
                                Text('HTML / CSS Sandbox'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'javascript',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.javascript_rounded, color: Colors.amberAccent, size: 16),
                                SizedBox(width: 6),
                                Text('JavaScript (Node.js)'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'php',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.php_rounded, color: Colors.lightBlueAccent, size: 16),
                                SizedBox(width: 6),
                                Text('PHP 8.2 Script'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'arduino',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.memory_rounded, color: Colors.tealAccent, size: 16),
                                SizedBox(width: 6),
                                Text('Arduino C++ Sketch'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: _onLanguageChanged,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Glowing Emerald Run / Compile Button
                  GestureDetector(
                    onTap: _isCompiling ? null : _handleCompile,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withAlpha(100),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isCompiling)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          else
                            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            _isCompiling ? 'Menjalankan...' : 'Jalankan / Run',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── CODE WINDOW (Mac-style Header & Monospaced Editor) ──
            Expanded(
              flex: _showPreview ? 3 : 5,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                decoration: BoxDecoration(
                  color: _isDarkEditor ? const Color(0xFF0D1117) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isDarkEditor ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Mac-style Window Header Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isDarkEditor ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                        border: Border(
                          bottom: BorderSide(
                            color: _isDarkEditor ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // 3 Window Dots
                          Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFFF5F56), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFFFBD2E), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF27C93F), shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          // File tab pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _isDarkEditor ? const Color(0xFF0D1117) : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _isDarkEditor ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.insert_drive_file_outlined, color: Colors.blueAccent, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  _getFileExtensionName(),
                                  style: GoogleFonts.firaCode(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _isDarkEditor ? Colors.white70 : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Theme Switch Button
                          IconButton(
                            icon: Icon(
                              _isDarkEditor ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              color: _isDarkEditor ? Colors.amberAccent : AppColors.primaryLight,
                              size: 16,
                            ),
                            tooltip: _isDarkEditor ? 'Beralih ke Mode Terang' : 'Beralih ke Mode Gelap',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => setState(() => _isDarkEditor = !_isDarkEditor),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'UTF-8',
                            style: GoogleFonts.firaCode(
                              fontSize: 10,
                              color: _isDarkEditor ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Code Editor Text Area (High-Contrast, Guaranteed Visible Text)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isDarkEditor ? const Color(0xFF0D1117) : Colors.white,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
                        ),
                        child: Theme(
                          data: ThemeData(
                            brightness: _isDarkEditor ? Brightness.dark : Brightness.light,
                            inputDecorationTheme: InputDecorationTheme(
                              filled: true,
                              fillColor: _isDarkEditor ? const Color(0xFF0D1117) : Colors.white,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: TextField(
                              controller: _codeController,
                              maxLines: null,
                              expands: true,
                              cursorColor: _isDarkEditor ? const Color(0xFF58A6FF) : const Color(0xFF2563EB),
                              style: GoogleFonts.firaCode(
                                fontSize: 13.5,
                                color: _isDarkEditor ? const Color(0xFF58A6FF) : const Color(0xFF0F172A),
                                fontWeight: FontWeight.w600,
                                height: 1.55,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: true,
                                fillColor: _isDarkEditor ? const Color(0xFF0D1117) : Colors.white,
                                contentPadding: EdgeInsets.zero,
                                hintText: 'Ketik kode program Anda di sini...',
                                hintStyle: TextStyle(
                                  color: _isDarkEditor ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── TERMINAL / CONSOLE PREVIEW PANEL ──
            if (_showPreview)
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF080C14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _compileResult?.success == true
                          ? const Color(0xFF10B981).withAlpha(120)
                          : const Color(0xFFEF4444).withAlpha(120),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Terminal Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2A),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                          border: Border(
                            bottom: BorderSide(
                              color: _compileResult?.success == true
                                  ? const Color(0xFF10B981).withAlpha(80)
                                  : const Color(0xFFEF4444).withAlpha(80),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _compileResult?.success == true
                                  ? Icons.check_circle_rounded
                                  : Icons.error_rounded,
                              size: 16,
                              color: _compileResult?.success == true
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedLanguage == 'html'
                                  ? 'Hasil Pratinjau Sandbox'
                                  : 'Konsol Terminal Kompilasi',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (_compileResult?.executionTimeMs != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${_compileResult!.executionTimeMs} ms',
                                  style: GoogleFonts.firaCode(fontSize: 10, color: Colors.white70),
                                ),
                              ),
                            ],
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _showPreview = false),
                            ),
                          ],
                        ),
                      ),
                      // Output Body
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            _compileResult != null
                                ? (_compileResult!.error != null
                                    ? '❌ KESALAHAN EKSEKUSI:\n${_compileResult!.error}\n\n📄 OUTPUT:\n${_compileResult!.output}'
                                    : _compileResult!.output)
                                : 'Menunggu eksekusi kode...',
                            style: GoogleFonts.firaCode(
                              fontSize: 12,
                              color: _compileResult?.success == true
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFFF87171),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

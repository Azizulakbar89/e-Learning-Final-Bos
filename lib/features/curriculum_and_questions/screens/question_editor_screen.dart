import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/question_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/app_loading_overlay.dart';
import '../../../core/widgets/responsive_layout.dart';

class QuestionEditorScreen extends StatefulWidget {
  final String subjectId;
  final QuestionModel? existingQuestion;
  final String? initialCpId;
  final String? initialTpId;

  const QuestionEditorScreen({
    super.key,
    required this.subjectId,
    this.existingQuestion,
    this.initialCpId,
    this.initialTpId,
  });

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  final _uuid = const Uuid();
  late QuestionType _selectedType;
  final _contentController = TextEditingController();
  final _equationController = TextEditingController();
  String? _selectedCpId;
  String? _selectedTpId;

  // Multiple choice options
  final List<TextEditingController> _optionControllers = [
    TextEditingController(text: 'Pilihan A'),
    TextEditingController(text: 'Pilihan B'),
    TextEditingController(text: 'Pilihan C'),
    TextEditingController(text: 'Pilihan D'),
  ];
  String _correctSingleChoice = 'A';
  final Set<String> _correctMultiChoice = {'A'};
  bool _correctTrueFalse = true;

  // Matching pairs
  final List<Map<String, TextEditingController>> _matchingControllers = [
    {'left': TextEditingController(text: 'Premis 1'), 'right': TextEditingController(text: 'Pasangan 1')},
    {'left': TextEditingController(text: 'Premis 2'), 'right': TextEditingController(text: 'Pasangan 2')},
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.existingQuestion?.type ?? QuestionType.single;
    if (widget.existingQuestion != null) {
      _contentController.text = widget.existingQuestion!.content;
      _equationController.text = widget.existingQuestion!.equationLatex ?? '';
      _selectedCpId = widget.existingQuestion!.cpId;
      _selectedTpId = widget.existingQuestion!.tpId;
    } else {
      _selectedCpId = widget.initialCpId;
      _selectedTpId = widget.initialTpId;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _equationController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    for (final m in _matchingControllers) {
      m['left']?.dispose();
      m['right']?.dispose();
    }
    super.dispose();
  }

  void _insertEquationSymbol(String symbol) {
    final text = _equationController.text;
    final selection = _equationController.selection;
    final newText = text.replaceRange(
      selection.start >= 0 ? selection.start : text.length,
      selection.end >= 0 ? selection.end : text.length,
      symbol,
    );
    _equationController.text = newText;
    _equationController.selection = TextSelection.collapsed(
      offset: (selection.start >= 0 ? selection.start : text.length) + symbol.length,
    );
  }

  /// Chip with rendered LaTeX math label
  Widget _mathChip(String insertLatex, String displayLatex) {
    return InkWell(
      onTap: () {
        _insertEquationSymbol(insertLatex);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withAlpha(80)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(15),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Math.tex(
          displayLatex,
          textStyle: const TextStyle(fontSize: 14, color: Colors.black87),
          onErrorFallback: (err) => Text(
            insertLatex,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
      ),
    );
  }

  Future<void> _saveQuestion() async {
    if (_contentController.text.trim().isEmpty) {
      AppSnackBar.warning(context, 'Isi butir soal tidak boleh kosong!');
      return;
    }

    final fb = context.read<FirebaseService>();

    List<QuestionOption> options = [];
    dynamic correctAnswers;

    if (_selectedType == QuestionType.single || _selectedType == QuestionType.multi) {
      const keys = ['A', 'B', 'C', 'D', 'E'];
      for (int i = 0; i < _optionControllers.length; i++) {
        options.add(
          QuestionOption(
            id: keys[i],
            text: _optionControllers[i].text.trim(),
          ),
        );
      }
      correctAnswers = _selectedType == QuestionType.single
          ? _correctSingleChoice
          : _correctMultiChoice.toList();
    } else if (_selectedType == QuestionType.trueFalse) {
      correctAnswers = _correctTrueFalse;
    } else if (_selectedType == QuestionType.matching) {
      final matchMap = <String, String>{};
      for (int i = 0; i < _matchingControllers.length; i++) {
        final left = _matchingControllers[i]['left']!.text.trim();
        final right = _matchingControllers[i]['right']!.text.trim();
        options.add(QuestionOption(id: '$i', text: left, matchingKey: right));
        matchMap[left] = right;
      }
      correctAnswers = matchMap;
    } else if (_selectedType == QuestionType.essay) {
      correctAnswers = null;
    }

    final question = QuestionModel(
      id: widget.existingQuestion?.id ?? _uuid.v4(),
      subjectId: widget.subjectId,
      cpId: _selectedCpId,
      tpId: _selectedTpId,
      teacherId: widget.existingQuestion?.teacherId ?? fb.currentUser?.id,
      creatorName: widget.existingQuestion?.creatorName ?? fb.currentUser?.fullName,
      type: _selectedType,
      content: _contentController.text.trim(),
      equationLatex: _equationController.text.trim().isNotEmpty ? _equationController.text.trim() : null,
      options: options,
      correctAnswers: correctAnswers,
      maxEssayScore: 5,
    );

    final success = await showLoadingDialog(
      context,
      message: widget.existingQuestion != null
          ? 'Memperbarui butir soal...'
          : 'Menyimpan butir soal ke Bank Soal...',
      action: () async {
        if (widget.existingQuestion != null) {
          await fb.updateQuestion(question);
        } else {
          await fb.addQuestion(question);
        }
      },
      successMessage: widget.existingQuestion != null
          ? 'Butir soal berhasil diperbarui!'
          : 'Butir soal berhasil disimpan ke Bank Soal!',
      errorMessage: 'Gagal menyimpan butir soal. Silakan coba lagi.',
    );

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fb = context.watch<FirebaseService>();
    final cps = fb.cps.where((c) => c.subjectId == widget.subjectId).toList();
    final tps = fb.tps.where((t) => t.cpId == _selectedCpId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat & Edit Butir Soal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.emerald),
            onPressed: _saveQuestion,
          ),
        ],
      ),
      body: ResponsiveFormWrapper(
        maxWidth: 800,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CP & TP selectors
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Pilih Capaian (CP)'),
                    initialValue: _selectedCpId,
                    items: cps.map((c) => DropdownMenuItem(value: c.id, child: Text(c.code))).toList(),
                    onChanged: (val) => setState(() {
                      _selectedCpId = val;
                      _selectedTpId = null;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Pilih Tujuan (TP)'),
                    initialValue: _selectedTpId,
                    items: tps.map((t) => DropdownMenuItem(value: t.id, child: Text(t.code))).toList(),
                    onChanged: (val) => setState(() => _selectedTpId = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Question Type Picker
            const Text('Tipe Butir Soal:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: QuestionType.values.map((type) {
                return ChoiceChip(
                  label: Text(type.label),
                  selected: _selectedType == type,
                  onSelected: (sel) {
                    if (sel) setState(() => _selectedType = type);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Question Content (Word-like WYSIWYG Form)
            const Text('Isi Teks Soal:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Ketikkan butir soal Anda disini...',
              ),
            ),
            const SizedBox(height: 16),

            // Math Equation Editor (LaTeX)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withAlpha(60)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.functions, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Formula Matematika (LaTeX)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      Tooltip(
                        message: 'Gunakan sintaks LaTeX. Contoh: \\frac{a}{b}, \\sqrt{x}, x^2',
                        child: Icon(Icons.help_outline, size: 16, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Quick-insert chips — show rendered math, not raw LaTeX
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _mathChip(r'\frac{a}{b}', r'\frac{a}{b}'),
                      _mathChip(r'\sqrt{x}', r'\sqrt{x}'),
                      _mathChip(r'x^2', r'x^2'),
                      _mathChip(r'\sum_{i=1}^{n}', r'\sum_{i=1}^{n}'),
                      _mathChip(r'\int f(x)dx', r'\int'),
                      _mathChip(r'\alpha', r'\alpha'),
                      _mathChip(r'\pi', r'\pi'),
                      _mathChip(r'\leq', r'\leq'),
                      _mathChip(r'\geq', r'\geq'),
                      _mathChip(r'\neq', r'\neq'),
                      _mathChip(r'\infty', r'\infty'),
                      _mathChip(r'x^{n}', r'x^n'),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // LaTeX text input
                  TextField(
                    controller: _equationController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: r'Contoh: f(x) = \frac{3x^2 + 5}{\sqrt{2x - 1}}',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  ),
                  const SizedBox(height: 12),

                  // Live rendered preview — MS Word style
                  if (_equationController.text.trim().isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(10),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.visibility, size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                'Pratinjau',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: Math.tex(
                              _equationController.text.trim(),
                              textStyle: const TextStyle(
                                fontSize: 22,
                                color: Colors.black87,
                              ),
                              onErrorFallback: (err) => Text(
                                _equationController.text.trim(),
                                style: const TextStyle(color: Colors.red, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Dynamic Option Controls according to type
            if (_selectedType == QuestionType.single) ...[
              const Text('Opsi Pilihan Ganda & Kunci Jawaban:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: _correctSingleChoice,
                onChanged: (val) {
                  if (val != null) setState(() => _correctSingleChoice = val);
                },
                child: Column(
                  children: List.generate(4, (i) {
                    final key = ['A', 'B', 'C', 'D'][i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: key,
                          ),
                          Text('$key. ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: TextField(
                              controller: _optionControllers[i],
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ] else if (_selectedType == QuestionType.multi) ...[
              const Text('Opsi Pilihan Ganda Kompleks (Pilih Kunci > 1):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...List.generate(4, (i) {
                final key = ['A', 'B', 'C', 'D'][i];
                final isChecked = _correctMultiChoice.contains(key);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isChecked,
                        onChanged: (val) => setState(() {
                          if (val == true) {
                            _correctMultiChoice.add(key);
                          } else {
                            _correctMultiChoice.remove(key);
                          }
                        }),
                      ),
                      Text('$key. ', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: TextField(
                          controller: _optionControllers[i],
                          decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ] else if (_selectedType == QuestionType.trueFalse) ...[
              const Text('Kunci Jawaban Benar / Salah:', style: TextStyle(fontWeight: FontWeight.bold)),
              RadioGroup<bool>(
                groupValue: _correctTrueFalse,
                onChanged: (val) {
                  if (val != null) setState(() => _correctTrueFalse = val);
                },
                child: const Row(
                  children: [
                    Radio<bool>(
                      value: true,
                    ),
                    Text('BENAR'),
                    SizedBox(width: 24),
                    Radio<bool>(
                      value: false,
                    ),
                    Text('SALAH'),
                  ],
                ),
              ),
            ] else if (_selectedType == QuestionType.matching) ...[
              const Text('Pasangan Menjodohkan (Kiri -> Kanan):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...List.generate(_matchingControllers.length, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _matchingControllers[i]['left'],
                          decoration: InputDecoration(labelText: 'Premis ${i + 1}'),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, size: 16),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _matchingControllers[i]['right'],
                          decoration: InputDecoration(labelText: 'Respon ${i + 1}'),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ] else if (_selectedType == QuestionType.essay) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.purple),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Soal Esai dinilai manual oleh Guru dengan skala nilai 1 sampai 5 per butir soal setelah ujian diselesaikan siswa.',
                        style: TextStyle(fontSize: 13, color: Colors.purple),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _saveQuestion,
                icon: const Icon(Icons.save),
                label: const Text('Simpan Butir Soal ke Bank Soal'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

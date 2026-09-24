import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// An intelligent Rich Text widget that parses and renders standard math symbols,
/// LaTeX equations (inline `$math$` or standalone `\sqrt{...}`), and mixed text seamlessly.
class SmartMathText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow overflow;

  const SmartMathText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  /// Cleans LaTeX into human-readable Unicode symbols if LaTeX fails or is simple
  static String latexToUnicode(String latex) {
    var s = latex.replaceAll(r'\$', '').trim();
    // Common LaTeX math symbols
    s = s.replaceAll(r'\times', '×');
    s = s.replaceAll(r'\cdot', '·');
    s = s.replaceAll(r'\div', '÷');
    s = s.replaceAll(r'\pm', '±');
    s = s.replaceAll(r'\mp', '∓');
    s = s.replaceAll(r'\le', '≤');
    s = s.replaceAll(r'\leq', '≤');
    s = s.replaceAll(r'\ge', '≥');
    s = s.replaceAll(r'\geq', '≥');
    s = s.replaceAll(r'\neq', '≠');
    s = s.replaceAll(r'\approx', '≈');
    s = s.replaceAll(r'\infty', '∞');
    s = s.replaceAll(r'\degree', '°');
    s = s.replaceAll(r'\circ', '°');
    s = s.replaceAll(r'\pi', 'π');
    s = s.replaceAll(r'\theta', 'θ');
    s = s.replaceAll(r'\alpha', 'α');
    s = s.replaceAll(r'\beta', 'β');
    s = s.replaceAll(r'\gamma', 'γ');
    s = s.replaceAll(r'\Delta', 'Δ');
    s = s.replaceAll(r'\sum', '∑');
    s = s.replaceAll(r'\int', '∫');

    // Simple sqrt replacement: \sqrt{8} -> √8, \sqrt[3]{8} -> ∛8
    s = s.replaceAllMapped(RegExp(r'\\sqrt\[(\d+)\]\{([^{}]+)\}'), (m) => '${_rootSymbol(m[1])}${m[2]}');
    s = s.replaceAllMapped(RegExp(r'\\sqrt\{([^{}]+)\}'), (m) => '√${m[1]}');

    // Simple frac replacement: \frac{a}{b} -> (a/b)
    s = s.replaceAllMapped(RegExp(r'\\frac\{([^{}]+)\}\{([^{}]+)\}'), (m) => '(${m[1]}/${m[2]})');

    // Superscripts
    s = s.replaceAll('^0', '⁰');
    s = s.replaceAll('^1', '¹');
    s = s.replaceAll('^2', '²');
    s = s.replaceAll('^3', '³');
    s = s.replaceAll('^4', '⁴');
    s = s.replaceAll('^5', '⁵');
    s = s.replaceAll('^6', '⁶');
    s = s.replaceAll('^7', '⁷');
    s = s.replaceAll('^8', '⁸');
    s = s.replaceAll('^9', '⁹');
    s = s.replaceAllMapped(RegExp(r'\^\{([0-9]+)\}'), (m) => _toSuperscript(m[1] ?? ''));

    // Remove stray braces/backslashes
    s = s.replaceAll('{', '').replaceAll('}', '');
    s = s.replaceAll(r'\', '');

    return s;
  }

  static String _rootSymbol(String? degree) {
    if (degree == '3') return '∛';
    if (degree == '4') return '∜';
    return '√';
  }

  static String _toSuperscript(String digits) {
    const map = {'0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹'};
    return digits.split('').map((c) => map[c] ?? c).join();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final rawText = text.trim();

    // 1. If text is empty, return empty widget
    if (rawText.isEmpty) {
      return const SizedBox.shrink();
    }

    // 2. Check if entire text is a single LaTeX expression (e.g. "$2\sqrt{6}$" or "2\sqrt{6}")
    final isPureMath = (rawText.startsWith(r'$') && rawText.endsWith(r'$')) ||
        (!rawText.contains(' ') && (rawText.contains(r'\') || rawText.contains('^') || rawText.contains('_')));

    if (isPureMath) {
      final cleanLatex = rawText.replaceAll(r'$$', '').replaceAll(r'$', '').trim();
      return Math.tex(
        cleanLatex,
        textStyle: effectiveStyle,
        mathStyle: MathStyle.text,
        onErrorFallback: (_) => Text(
          latexToUnicode(cleanLatex),
          style: effectiveStyle,
          textAlign: textAlign,
          textDirection: textDirection,
        ),
      );
    }

    // 3. Mixed Text with inline math (e.g. "Hasil dari $\sqrt{8} \times \sqrt{3}$ adalah ....")
    final List<InlineSpan> spans = [];
    final mathRegex = RegExp(r'(\$\$[\s\S]*?\$\$|\$[^\$]+?\$|\\[a-zA-Z]+\{[^\}]*\}|\\[a-zA-Z]+)');
    int lastEnd = 0;

    for (final match in mathRegex.allMatches(rawText)) {
      if (match.start > lastEnd) {
        final plain = rawText.substring(lastEnd, match.start);
        spans.add(TextSpan(text: plain, style: effectiveStyle));
      }

      final mathMatch = match.group(0)!;
      final cleanMath = mathMatch.replaceAll(r'$$', '').replaceAll(r'$', '').trim();

      if (cleanMath.isNotEmpty) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            baseline: TextBaseline.alphabetic,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Math.tex(
                cleanMath,
                textStyle: effectiveStyle,
                mathStyle: MathStyle.text,
                onErrorFallback: (_) => Text(
                  latexToUnicode(cleanMath),
                  style: effectiveStyle,
                ),
              ),
            ),
          ),
        );
      }

      lastEnd = match.end;
    }

    if (lastEnd < rawText.length) {
      spans.add(TextSpan(text: rawText.substring(lastEnd), style: effectiveStyle));
    }

    // If no math spans were found, render standard Text
    if (spans.isEmpty) {
      return Text(
        rawText,
        style: effectiveStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

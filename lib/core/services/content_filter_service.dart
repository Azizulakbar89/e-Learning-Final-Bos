/// Content Filter Service
/// ========================
/// Menyensor kata-kata tidak pantas, penghinaan, cyberbullying, dan pelecehan
/// secara kontekstual dalam Bahasa Indonesia.
class ContentFilterService {
  ContentFilterService._();
  static final ContentFilterService instance = ContentFilterService._();

  // 1. Kata-kata Kotor / Jorok (selalu disensor)
  static const List<String> _hardProfanity = [
    'anjing', 'anjir', 'anjay', 'bangsat', 'brengsek', 'bajingan',
    'keparat', 'jahanam', 'laknat', 'sialan', 'bedebah',
    'babi', 'monyet', 'kampret', 'goblok', 'tolol', 'idiot', 'dungu', 'bloon',
    'tai', 'tahi', 'jancok', 'jancuk', 'jangkrik',
    'asu', 'kontol', 'memek', 'pepek',
    'ngentot', 'entot', 'ngewe',
    'pelacur', 'lonte', 'jablay', 'sundal', 'bejat',
    'fuck', 'shit', 'bastard', 'bitch',
    'cok', 'cuk', 'taek', 'fck', 'wtf', 'stfu',
    'mampus', 'geblek', 'pekok', 'bongak', 'gendheng', 'edan', 'gelo', 'gilak',
    'matamu', 'matane',
  ];

  // 2. Kata sensitif: [kata] -> [konteks aman] 
  // Jika ada konteks aman di teks, TIDAK disensor
  static const Map<String, List<String>> _contextualWords = {
    'gemuk': ['nilai', 'makanan', 'berlemak', 'sehat', 'gizi', 'porsi', 'resep'],
    'kurus': ['nilai', 'diet', 'sehat', 'gizi', 'makanan', 'porsi'],
    'jelek': ['nilai', 'hasil', 'cuaca', 'sinyal', 'gambar', 'foto', 'kualitas', 'produk', 'barang', 'tulisan', 'jawaban'],
    'buruk': ['nilai', 'hasil', 'cuaca', 'sinyal', 'kualitas', 'kondisi', 'keadaan', 'perilaku', 'karakter'],
    'pendek': ['nilai', 'cerita', 'tulisan', 'waktu', 'jarak', 'kabel', 'akal'],
    'bau': ['nilai', 'kimia', 'reaksi', 'masakan', 'masak', 'aroma'],
    'lemah': ['nilai', 'sinyal', 'baterai', 'ekonomi', 'argumen', 'bukti'],
    'lambat': ['nilai', 'internet', 'sinyal', 'komputer', 'proses', 'koneksi'],
    'malas': ['nilai', 'karakter', 'sifat', 'kebiasaan'],
    'bodoh': ['jangan', 'bukan', 'tidak', 'nilai', 'sikap', 'perilaku', 'bodo amat'],
    'gila': ['nilai', 'kecepatan', 'harga', 'diskon', 'promo', 'keren', 'banget'],
  };

  // 3. Kata-kata yang bersifat penghinaan personal (diperlukan subjek personal di dekatnya)
  static const List<String> _insultTriggers = [
    'gemuk', 'gendut', 'tembem', 'kurus', 'kerempeng', 'ceking',
    'jelek', 'ugly', 'ancur', 'pendek', 'cebol', 'kerdil',
    'bau', 'bau badan', 'hitam legam',
    'bodoh', 'tolol', 'goblok', 'idiot', 'dungu', 'bloon',
    'lemah', 'payah', 'pengecut', 'pecundang', 'loser',
    'miskin', 'bokek', 'melarat',
    'sampah', 'hina', 'rendah',
    'tidak berguna', 'ga berguna', 'gak berguna', 'nggak berguna',
    'tidak ada gunanya', 'ga ada gunanya', 'gak ada gunanya',
  ];

  // 4. Frasa lengkap yang SELALU disensor
  static const List<String> _bannedPhrases = [
    'mati saja', 'mati lo', 'mati kamu', 'mati aja', 'mati deh',
    'bunuh diri', 'bunuh aja', 'bunuhin',
    'ga usah hidup', 'gak usah hidup', 'nggak usah hidup', 'tidak usah hidup',
    'ga ada gunanya', 'gak ada gunanya', 'tidak ada gunanya', 'nggak ada gunanya',
    'ga berguna', 'gak berguna', 'tidak berguna', 'nggak berguna',
    'go kill yourself', 'kys',
  ];

  // 5. Kata subjek personal (untuk deteksi konteks penghinaan)
  static const List<String> _personalSubjects = [
    'kamu', 'km', 'lo', 'elo', 'lu', 'elu', 'kalian',
    'dia', 'mereka', 'si ', 'you', 'u ',
    'mukamu', 'mukalo', 'wajahmu', 'badanmu', 'tubuhmu',
    'orangnya', 'orangmu',
  ];

  // ─── PUBLIC API ─────────────────────────────────────────────────────────────

  /// Filter teks dan kembalikan versi yang sudah disensor
  String filter(String text) {
    if (text.trim().isEmpty) return text;
    String result = text;
    result = _censorBannedPhrases(result);
    result = _censorHardProfanity(result);
    result = _censorContextualInsults(result);
    return result;
  }

  /// Cek apakah teks mengandung konten tidak pantas
  bool containsInappropriateContent(String text) {
    return filter(text) != text;
  }

  // ─── PRIVATE METHODS ────────────────────────────────────────────────────────

  String _censorBannedPhrases(String text) {
    String result = text;
    for (final phrase in _bannedPhrases) {
      final pattern = RegExp(
        RegExp.escape(phrase),
        caseSensitive: false,
      );
      result = result.replaceAllMapped(
          pattern, (m) => _maskWord(m.group(0)!));
    }
    return result;
  }

  String _censorHardProfanity(String text) {
    String result = text;
    for (final word in _hardProfanity) {
      final pattern = RegExp(
        r'(?<![a-zA-Z])' + RegExp.escape(word) + r'(?![a-zA-Z])',
        caseSensitive: false,
      );
      result = result.replaceAllMapped(
          pattern, (m) => _maskWord(m.group(0)!));
    }
    return result;
  }

  String _censorContextualInsults(String text) {
    String result = text;
    final textLower = text.toLowerCase();

    for (final insult in _insultTriggers) {
      // Skip jika konteks aman ditemukan (contoh: "nilai jelek")
      if (_isInSafeContext(insult, textLower)) continue;

      // Cek apakah ada subjek personal di dekatnya
      if (_hasNearbySubject(insult, textLower)) {
        final pattern = RegExp(
          RegExp.escape(insult),
          caseSensitive: false,
        );
        result =
            result.replaceAllMapped(pattern, (m) => _maskWord(m.group(0)!));
      }
    }

    // Juga sensor kata dalam _contextualWords jika dekat subjek personal dan bukan konteks aman
    for (final entry in _contextualWords.entries) {
      final word = entry.key;
      if (!_isInSafeContext(word, textLower) &&
          _hasNearbySubject(word, textLower)) {
        final pattern = RegExp(
          r'(?<![a-zA-Z])' + RegExp.escape(word) + r'(?![a-zA-Z])',
          caseSensitive: false,
        );
        result =
            result.replaceAllMapped(pattern, (m) => _maskWord(m.group(0)!));
      }
    }

    return result;
  }

  bool _isInSafeContext(String word, String textLower) {
    final safeContexts = _contextualWords[word] ?? [];
    if (safeContexts.isEmpty) return false;
    for (final ctx in safeContexts) {
      if (textLower.contains(ctx)) return true;
    }
    return false;
  }

  bool _hasNearbySubject(String word, String textLower) {
    final wordIdx = textLower.indexOf(word);
    if (wordIdx == -1) return false;
    // Ambil teks dalam radius 40 karakter di sekitar kata
    final start = (wordIdx - 40).clamp(0, textLower.length);
    final end = (wordIdx + word.length + 40).clamp(0, textLower.length);
    final nearby = textLower.substring(start, end);
    for (final subject in _personalSubjects) {
      if (nearby.contains(subject)) return true;
    }
    return false;
  }

  String _maskWord(String word) {
    if (word.length <= 1) return '*';
    if (word.length == 2) return '**';
    if (word.length == 3) return '${word[0]}*${word[word.length - 1]}';
    final stars = '*' * (word.length - 2);
    return '${word[0]}$stars${word[word.length - 1]}';
  }
}

/// Extension helper
extension StringFilter on String {
  String get filtered => ContentFilterService.instance.filter(this);
  bool get hasInappropriateContent =>
      ContentFilterService.instance.containsInappropriateContent(this);
}

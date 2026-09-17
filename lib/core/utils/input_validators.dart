/// Centralized secure input validators for E-Learning SuperApp
class InputValidators {
  /// Validasi NIS (Hanya digit angka, 3-15 digit)
  static String? validateNis(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'NIS wajib diisi';
    }
    final clean = value.trim();
    if (!RegExp(r'^[0-9]{3,15}$').hasMatch(clean)) {
      return 'NIS harus berupa angka (3 - 15 digit)';
    }
    return null;
  }

  /// Validasi Nama Lengkap (Huruf, spasi, tanda baca standar nama, 3-70 karakter)
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nama lengkap wajib diisi';
    }
    final clean = value.trim();
    if (clean.length < 3) {
      return 'Nama terlalu pendek (minimal 3 karakter)';
    }
    if (clean.length > 70) {
      return 'Nama maksimal 70 karakter';
    }
    if (!RegExp(r"^[a-zA-Z\s\.,'’\-]+$").hasMatch(clean)) {
      return 'Nama hanya boleh mengandung huruf, spasi, dan tanda baca nama';
    }
    return null;
  }

  /// Validasi Password (minimal 6 karakter, maksimal 60)
  static String? validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password wajib diisi';
    }
    if (value.length < 6) {
      return 'Password minimal 6 karakter';
    }
    if (value.length > 60) {
      return 'Password maksimal 60 karakter';
    }
    return null;
  }

  /// Validasi URL Media Materi (hanya HTTP/HTTPS dan domain terpercaya)
  static String? validateMediaUrl(String? value, String contentType) {
    if (value == null || value.trim().isEmpty) {
      return 'URL media wajib diisi';
    }
    final clean = value.trim();
    final uri = Uri.tryParse(clean);
    if (uri == null || !uri.hasScheme || (!uri.scheme.startsWith('http'))) {
      return 'Format URL tidak valid (harus diawali http:// atau https://)';
    }

    final host = uri.host.toLowerCase();
    if (contentType == 'youtube') {
      if (!host.contains('youtube.com') && !host.contains('youtu.be')) {
        return 'Tautan harus berasal dari domain youtube.com atau youtu.be';
      }
    } else if (contentType == 'canva') {
      if (!host.contains('canva.com')) {
        return 'Tautan harus berasal dari domain canva.com';
      }
    }
    return null;
  }

  /// Validasi teks umum tidak boleh kosong
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName wajib diisi';
    }
    return null;
  }
}

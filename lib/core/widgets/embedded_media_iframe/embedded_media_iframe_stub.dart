import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/url_helper.dart';

void focusIframe(String viewKey) {}

Widget buildEmbeddedMediaIframe({
  required String url,
  required String viewKey,
  double? height,
}) {
  return Container(
    width: double.infinity,
    height: height ?? 320,
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF334155)),
    ),
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.open_in_browser_rounded, color: Colors.cyanAccent, size: 48),
          const SizedBox(height: 12),
          Text(
            'Konten Interaktif Tersedia',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Buka konten materi pembelajaran langsung di peramban:',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => openExternalUrl(url),
            icon: const Icon(Icons.launch_rounded, size: 16),
            label: const Text('Buka Konten'),
          ),
        ],
      ),
    ),
  );
}

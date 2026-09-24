import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  // Get token using git credential fill
  final credProcess = await Process.start('git', ['credential', 'fill']);
  credProcess.stdin.writeln('protocol=https\nhost=github.com\n');
  await credProcess.stdin.flush();
  await credProcess.stdin.close();

  final credOutput = await credProcess.stdout.transform(utf8.decoder).join();
  String? token;
  for (final line in credOutput.split('\n')) {
    if (line.startsWith('password=')) {
      token = line.substring('password='.length).trim();
    }
  }

  if (token == null || token.isEmpty) {
    print('Error: GitHub token not found.');
    exit(1);
  }

  final owner = 'Azizulakbar89';
  final repo = 'e-Learning-Final-Bos';
  final tag = 'v1.5.1';
  final apkPath = 'build/app/outputs/flutter-apk/app-release.apk';

  final apkFile = File(apkPath);
  if (!apkFile.existsSync()) {
    print('Error: APK file not found at $apkPath');
    exit(1);
  }

  print('1. Checking existing release for tag $tag...');
  final getReleaseUri = Uri.parse('https://api.github.com/repos/$owner/$repo/releases/tags/$tag');
  var releaseRes = await http.get(getReleaseUri, headers: {
    'Authorization': 'token $token',
    'Accept': 'application/vnd.github.v3+json',
  });

  Map<String, dynamic>? releaseData;
  if (releaseRes.statusCode == 200) {
    releaseData = jsonDecode(releaseRes.body);
    print('Release $tag already exists (ID: ${releaseData!['id']}).');
  } else {
    print('2. Creating release $tag...');
    final createReleaseUri = Uri.parse('https://api.github.com/repos/$owner/$repo/releases');
    final createRes = await http.post(
      createReleaseUri,
      headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'tag_name': tag,
        'name': 'Release $tag - Bank Soal Guru, Chat Admin, & UI Bento Taste',
        'body': '''### 🚀 Release Notes v1.5.1
- **Bank Soal Khusus Guru**: Filter otomatis berdasarkan kepemilikan soal (`creatorId`), edit teks soal & opsi, serta hapus soal.
- **Monitoring Chat Lengkap untuk Admin**: Tab terstruktur 4 pilar percakapan (Diskusi Materi, Chat Siswa-Guru, Chat Antar Siswa, Grup Kelas) dan identitas lawan bicara rapi.
- **Isolasi Notifikasi Siswa & Guru**: Notifikasi chat hanya ditujukan untuk partisipan langsung atau anggota grup yang terdaftar.
- **Live Search & PDF Importer**: Pencarian instan teks soal dan formula matematika/Arab.
- **Bento Card UI Design**: Penyegaran estetika antarmuka dengan micro-animations & standard design taste.''',
        'draft': false,
        'prerelease': false,
      }),
    );

    if (createRes.statusCode != 201) {
      print('Failed to create release: ${createRes.statusCode} - ${createRes.body}');
      exit(1);
    }
    releaseData = jsonDecode(createRes.body);
    print('Release created successfully (ID: ${releaseData!['id']}).');
  }

  final releaseId = releaseData!['id'];

  // Check if asset already exists in release
  final List<dynamic> assets = releaseData['assets'] ?? [];
  for (final asset in assets) {
    if (asset['name'] == 'app-release.apk') {
      print('Deleting existing asset ${asset['id']}...');
      final deleteUri = Uri.parse('https://api.github.com/repos/$owner/$repo/releases/assets/${asset['id']}');
      await http.delete(deleteUri, headers: {
        'Authorization': 'token $token',
        'Accept': 'application/vnd.github.v3+json',
      });
    }
  }

  print('3. Uploading APK to GitHub Release (${apkFile.lengthSync()} bytes)...');
  final uploadUrlTemplate = releaseData['upload_url'] as String;
  final uploadUrl = Uri.parse(uploadUrlTemplate.replaceAll('{?name,label}', '?name=app-release.apk'));

  final apkBytes = await apkFile.readAsBytes();
  final uploadRes = await http.post(
    uploadUrl,
    headers: {
      'Authorization': 'token $token',
      'Content-Type': 'application/vnd.android.package-archive',
      'Content-Length': apkBytes.length.toString(),
    },
    body: apkBytes,
  );

  if (uploadRes.statusCode == 201) {
    print('🎉 APK successfully uploaded to GitHub Release $tag!');
    print('Download URL: https://github.com/$owner/$repo/releases/download/$tag/app-release.apk');
  } else {
    print('Failed to upload asset: ${uploadRes.statusCode} - ${uploadRes.body}');
    exit(1);
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:googleapis_auth/auth_io.dart';

void main() async {
  final saFile = File('assets/service-account.json');
  if (!saFile.existsSync()) {
    print('Error: assets/service-account.json not found!');
    exit(1);
  }

  final saJson = jsonDecode(await saFile.readAsString()) as Map<String, dynamic>;
  final credentials = ServiceAccountCredentials.fromJson(saJson);
  final scopes = ['https://www.googleapis.com/auth/datastore'];

  final client = await clientViaServiceAccount(credentials, scopes);
  final projectId = saJson['project_id'];

  final docUrl = Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/system_info/app_version',
  );

  final payload = {
    'fields': {
      'latest_version': {'stringValue': '1.0.3'},
      'version_code': {'integerValue': '4'},
      'min_supported_version_code': {'integerValue': '1'},
      'apk_url': {
        'stringValue':
            'https://github.com/Azizulakbar89/e-Learning-Final-Bos/releases/download/v1.0.3/app-release.apk'
      },
      'release_notes': {
        'stringValue':
            '1. Optimasi kuota Firestore: mendukung 500+ siswa ujian/kuis serentak tanpa error kuota habis\n2. Optimasi pemuatan butir soal ujian (on-demand & memory cache)\n3. Scoped streams per-siswa untuk hemat kuota read 99.8%\n4. Peningkatan stabilitas dan performa aplikasi'
      },
      'force_update': {'booleanValue': false}
    }
  };

  final response = await client.patch(
    docUrl,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  );

  print('Firestore Response: ${response.statusCode}');
  print(response.body);

  client.close();
}

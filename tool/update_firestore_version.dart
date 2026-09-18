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
      'latest_version': {'stringValue': '1.0.7'},
      'version_code': {'integerValue': '8'},
      'min_supported_version_code': {'integerValue': '1'},
      'apk_url': {
        'stringValue':
            'https://github.com/Azizulakbar89/e-Learning-Final-Bos/releases/download/v1.0.7/app-release.apk'
      },
      'release_notes': {
        'stringValue':
            '1. Perbaikan Notifikasi Chat: Menghentikan notifikasi dan pop-up banner ke pengirim pesan sendiri saat mengirim chat.\n2. In-App Media Viewer Interaktif: Materi pembelajaran berupa slide PPT/Google Slides, presentasi Canva, dan video YouTube kini langsung tampil dan dapat diinteraksikan di dalam aplikasi tanpa harus dialihkan ke peramban atau browser luar.\n3. Peningkatan performa dan kestabilan WebView materi pembelajaran.'
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

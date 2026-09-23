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

  String version = '1.1.0';
  int versionCode = 11;
  final pubspecFile = File('pubspec.yaml');
  if (pubspecFile.existsSync()) {
    final lines = await pubspecFile.readAsLines();
    for (final line in lines) {
      if (line.startsWith('version:')) {
        final raw = line.replaceFirst('version:', '').trim();
        final parts = raw.split('+');
        version = parts[0].trim();
        if (parts.length > 1) {
          versionCode = int.tryParse(parts[1].trim()) ?? versionCode;
        }
        break;
      }
    }
  }

  final payload = {
    'fields': {
      'latest_version': {'stringValue': version},
      'version_code': {'integerValue': '$versionCode'},
      'min_supported_version_code': {'integerValue': '1'},
      'apk_url': {
        'stringValue':
            'https://github.com/Azizulakbar89/e-Learning-Final-Bos/releases/download/v$version/app-release.apk'
      },
      'release_notes': {
        'stringValue':
            '✨ Versi $version: Fitur pilihan bagikan postingan langsung ke Instagram (Story/Feed) & WhatsApp (Status/Chat), serta eksekusi compiler IDE multi-bahasa terintegrasi (Python 3, JavaScript, PHP, C++, Arduino & Live HTML Preview).'
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

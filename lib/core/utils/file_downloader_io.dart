import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<void> saveAndDownloadFile({
  required Uint8List bytes,
  required String fileName,
}) async {
  Directory? dir;
  try {
    dir = await getDownloadsDirectory();
  } catch (_) {
    dir = null;
  }
  dir ??= await getApplicationDocumentsDirectory();

  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
}

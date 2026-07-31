import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Mantém a fotografia fora da pasta temporária da câmara/galeria.
abstract final class ExpenseDocumentCapture {
  static Future<String?> captureFromCamera() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
    );
    return image == null ? null : _persist(image.path, image.name);
  }

  static Future<String?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final file = result?.files.single;
    return file?.path == null ? null : _persist(file!.path!, file.name);
  }

  static Future<String> _persist(String path, String filename) async {
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory(
      '${root.path}${Platform.pathSeparator}expense_documents',
    );
    await folder.create(recursive: true);
    final ext = filename.contains('.') ? filename.split('.').last : 'jpg';
    final target = File(
      '${folder.path}${Platform.pathSeparator}expense_${DateTime.now().microsecondsSinceEpoch}.$ext',
    );
    return (await File(path).copy(target.path)).path;
  }
}

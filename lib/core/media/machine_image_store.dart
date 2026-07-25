import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

abstract final class MachineImageStore {
  static Future<String?> pickFromCamera() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (image == null) return null;
    return _storeFile(path: image.path, filename: image.name);
  }

  static Future<String?> pickFromGallery() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (image == null) return null;
    return _storeFile(path: image.path, filename: image.name);
  }

  static Future<String?> pickFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return null;
    return _storeFile(path: file.path, bytes: file.bytes, filename: file.name);
  }

  static Future<String> _storeFile({
    String? path,
    List<int>? bytes,
    required String filename,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final images = Directory(
      '${directory.path}${Platform.pathSeparator}machine_images',
    );
    await images.create(recursive: true);
    final extension =
        RegExp(
          r'\.([a-zA-Z0-9]{2,5})$',
        ).firstMatch(filename)?.group(1)?.toLowerCase() ??
        'jpg';
    final destination = File(
      '${images.path}${Platform.pathSeparator}machine_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    if (path != null) {
      await File(path).copy(destination.path);
    } else if (bytes != null) {
      await destination.writeAsBytes(bytes, flush: true);
    } else {
      throw StateError('Não foi possível ler a imagem escolhida.');
    }
    return destination.path;
  }
}

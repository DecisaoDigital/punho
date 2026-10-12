// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

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

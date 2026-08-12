import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

abstract final class MachineImageStore {
  static const _remotePrefix = 'remote://';

  static bool isRemotePath(String path) => path.startsWith(_remotePrefix);

  static Future<String?> signedUrl(String path) async {
    if (!isRemotePath(path) || !SupabaseConfig.enabled) return null;
    return Supabase.instance.client.storage
        .from('punho-documentos')
        .createSignedUrl(path.substring(_remotePrefix.length), 3600);
  }

  /// Apaga do arquivo as fotografias que deixaram de ser usadas.
  ///
  /// Recebe o antes e o depois, e apaga o que saiu — não o que entrou. Chamar
  /// isto no momento em que se toca no X seria apagar a fotografia de quem
  /// depois carrega em Cancelar, portanto só se chama depois de gravar.
  ///
  /// Falha em silêncio de propósito. Uma fotografia que ficou por apagar é lixo
  /// no balde; um erro aqui a rebentar era o utilizador a não conseguir gravar
  /// a máquina por causa da limpeza. A ordem de importância é essa.
  /// Quais os objectos do arquivo que deixaram de ser precisos.
  ///
  /// Separada e pública para se poder testar sem Supabase nenhum: é aqui que
  /// mora o risco todo desta funcionalidade — apagar de menos deixa lixo, e
  /// apagar de mais apaga a fotografia de uma máquina que ainda a usa.
  ///
  /// Devolve caminhos do arquivo, já sem o prefixo `remote://`. Ignora os
  /// caminhos locais: esses não estão no arquivo e apagá-los aqui não faz
  /// sentido nenhum.
  static List<String> caminhosARemover({
    required List<String> antes,
    required List<String> depois,
  }) {
    final ficaram = depois.toSet();
    return antes
        .where((p) => isRemotePath(p) && !ficaram.contains(p))
        .map((p) => p.substring(_remotePrefix.length))
        .toSet() // a mesma fotografia repetida na lista não se apaga duas vezes
        .toList(growable: false);
  }

  static Future<int> apagarAsQueSairam({
    required List<String> antes,
    required List<String> depois,
  }) async {
    if (!SupabaseConfig.enabled) return 0;
    final aRemover = caminhosARemover(antes: antes, depois: depois);
    if (aRemover.isEmpty) return 0;
    try {
      await Supabase.instance.client.storage
          .from('punho-documentos')
          .remove(aRemover);
      return aRemover.length;
    } catch (erro) {
      // Sem `debugPrint` mudo: isto tem de deixar rasto, senão o balde enche-se
      // e não há por onde perceber porquê.
      // ignore: avoid_print
      print('[MachineImageStore] não apagou ${aRemover.length}: $erro');
      return 0;
    }
  }

  static Future<String?> pickFromCamera() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (image == null) return null;
    return _publish(await _storeFile(path: image.path, filename: image.name));
  }

  static Future<String?> pickFromGallery() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (image == null) return null;
    return _publish(await _storeFile(path: image.path, filename: image.name));
  }

  static Future<String?> pickFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return null;
    return _publish(
      await _storeFile(path: file.path, bytes: file.bytes, filename: file.name),
    );
  }

  /// Envia para o arquivo privado da empresa. O caminho remoto é guardado na
  /// máquina, permitindo que qualquer membro da empresa veja a fotografia.
  static Future<String> _publish(String localPath) async {
    if (!SupabaseConfig.enabled) return localPath;
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('Inicie sessão para enviar a fotografia da máquina.');
    }
    final empresaId = await client.rpc('punho_empresa_atual') as String?;
    if (empresaId == null || empresaId.isEmpty) {
      throw StateError('Não foi encontrada uma empresa para esta conta.');
    }
    final extension = localPath.contains('.')
        ? localPath.split('.').last
        : 'jpg';
    final objectPath =
        '$empresaId/machines/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await client.storage
        .from('punho-documentos')
        .upload(
          objectPath,
          File(localPath),
          fileOptions: const FileOptions(
            cacheControl: '31536000',
            upsert: false,
          ),
        );
    return '$_remotePrefix$objectPath';
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

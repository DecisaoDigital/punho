import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Arquivo privado da empresa. O ficheiro pertence ao Punho/empresa, não ao
/// dispositivo nem à conta que o capturou; a autoria fica nos metadados.
abstract final class ExpenseDocumentStorage {
  static Future<String?> upload({required String localPath, required String expenseId}) async {
    if (!SupabaseConfig.enabled) return null;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return null;
    final empresaId = await client.rpc('punho_empresa_atual') as String?;
    if (empresaId == null || empresaId.isEmpty) return null;
    final extension = localPath.contains('.') ? localPath.split('.').last : 'jpg';
    final objectPath = '$empresaId/$expenseId.$extension';
    // Regista primeiro a propriedade e a autoria. As regras do bucket usam
    // este registo para permitir leitura ao autor e aos gestores da empresa.
    final document = await client.from('punho_documentos').insert({
      'empresa_id': empresaId,
      'created_by': user.id,
      'dados': {
        'tipo': 'fatura_despesa',
        'expense_id': expenseId,
        'storage_path': objectPath,
      },
    }).select('id').single();
    try {
      await client.storage.from('punho-documentos').upload(
        objectPath,
        File(localPath),
        fileOptions: const FileOptions(cacheControl: '31536000', upsert: false),
      );
    } catch (_) {
      // Evita metadados sem ficheiro quando a rede ou o arquivo remoto falha.
      await client.from('punho_documentos').delete().eq('id', document['id']);
      rethrow;
    }
    return objectPath;
  }
}

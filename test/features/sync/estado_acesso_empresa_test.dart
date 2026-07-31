import 'package:flutter_test/flutter_test.dart';
import 'package:punho/features/auth/domain/estado_acesso.dart';

/// A empresa é a chave da sincronização: as operações são por empresa, e sem
/// ela não há onde as ler nem escrever.
void main() {
  test('a empresa vem do mesmo sítio que diz se a adesão está activa', () {
    final acesso = EstadoAcesso.fromJson({
      'membro_ativo': true,
      'perfil': 'gestor',
      'estado': 'aprovado',
      'empresa_id': '37b847eb-de1c-4f29-820d-814e069806ee',
    });

    expect(acesso.empresaId, '37b847eb-de1c-4f29-820d-814e069806ee');
    expect(acesso.membroAtivo, isTrue);
  });

  test('servidor antigo sem a coluna não rebenta a app', () {
    // A app pode chegar ao terreno antes da migração. Falta de empresa é
    // "não sincronizo", não é erro.
    final acesso = EstadoAcesso.fromJson({
      'membro_ativo': true,
      'perfil': 'gestor',
      'estado': 'aprovado',
    });

    expect(acesso.empresaId, isNull);
    expect(acesso.membroAtivo, isTrue);
  });

  test('sem adesão activa não há empresa para sincronizar', () {
    final acesso = EstadoAcesso.fromJson({
      'membro_ativo': false,
      'estado': 'pendente',
    });

    expect(acesso.empresaId, isNull);
    expect(acesso.membroAtivo, isFalse);
  });
}

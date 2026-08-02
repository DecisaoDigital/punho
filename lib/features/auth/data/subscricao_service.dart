import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fala com `punho_subscricoes` para saber quantas vagas de colaboradores
/// activos a empresa tem contratadas — decisão de 2026-08-02: é o servidor, e
/// não o número que o gestor declarou no onboarding, quem manda neste limite.
///
/// `null` significa "não foi possível saber": sem Supabase configurado, sem
/// sessão, sem rede, ou a linha ainda não existe para a empresa. Nunca
/// significa "zero vagas" — quem chama trata `null` como "usa o valor local",
/// nunca como recusa. Ver `limiteColaboradoresServidorProvider`.
///
/// Interface fina de propósito, tal como o [AcessoService] em
/// `acesso_service.dart`: os testes implementam-na directamente, sem package
/// de mocking.
abstract class SubscricaoService {
  Future<int?> limiteColaboradoresAtivos(String empresaId);
}

class SupabaseSubscricaoService implements SubscricaoService {
  SupabaseSubscricaoService(this._client);
  final SupabaseClient _client;

  @override
  Future<int?> limiteColaboradoresAtivos(String empresaId) async {
    try {
      // Não é preciso migração nem RPC nova: o RLS de `punho_subscricoes` já
      // deixa o gestor ler a linha da própria empresa
      // (`empresa_id = punho_empresa_atual() AND punho_e_gestor()`).
      final linha = await _client
          .from('punho_subscricoes')
          .select('limite_colaboradores_ativos')
          .eq('empresa_id', empresaId)
          .maybeSingle();
      final valor = linha?['limite_colaboradores_ativos'];
      if (valor is int) return valor;
      if (valor is num) return valor.toInt();
      return null;
    } catch (erro) {
      // Falha de rede não pode travar a criação de colaboradores — quem
      // chama fica com o valor local. Ver a mesma regra em
      // `PunhoLicencaService.validar`.
      debugPrint('limiteColaboradoresAtivos falhou: $erro');
      return null;
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uma ficha onde há dados de uma pessoa — cliente, empregado ou contacto.
///
/// Não é «o cliente»: é **uma** das fichas onde essa pessoa aparece. A mesma
/// pessoa pode estar lá três vezes, e é isso que obriga a procurar antes de
/// apagar.
class FichaDeTitular {
  const FichaDeTitular({
    required this.entidade,
    required this.entidadeId,
    required this.revisoes,
    required this.jaApagado,
    this.nome,
    this.contacto,
  });

  factory FichaDeTitular.fromJson(Map<String, dynamic> json) => FichaDeTitular(
    entidade: (json['entidade'] as String?) ?? '',
    entidadeId: (json['entidade_id'] as String?) ?? '',
    revisoes: (json['revisoes'] as num?)?.toInt() ?? 0,
    jaApagado: (json['ja_apagado'] as bool?) ?? false,
    nome: json['nome'] as String?,
    contacto: json['contacto'] as String?,
  );

  final String entidade, entidadeId;
  final int revisoes;
  final bool jaApagado;
  final String? nome, contacto;

  String get comoSeChama => nome?.trim().isNotEmpty == true
      ? nome!.trim()
      : 'Ficha sem nome ($entidadeId)';

  String get oQueE => switch (entidade) {
    'customer' => 'Cliente',
    'collaborator' => 'Empregado',
    'lead' => 'Contacto',
    _ => entidade,
  };
}

/// Um apagamento que já foi feito. É a prova que se mostra a quem o pediu.
class ApagamentoFeito {
  const ApagamentoFeito({
    required this.entidade,
    required this.entidadeId,
    required this.linhas,
    required this.feitoEm,
    this.motivo,
  });

  factory ApagamentoFeito.fromJson(Map<String, dynamic> json) =>
      ApagamentoFeito(
        entidade: (json['entidade'] as String?) ?? '',
        entidadeId: (json['entidade_id'] as String?) ?? '',
        linhas:
            ((json['operacoes_redigidas'] as num?)?.toInt() ?? 0) +
            ((json['reservas_redigidas'] as num?)?.toInt() ?? 0),
        feitoEm:
            DateTime.tryParse((json['feito_em'] as String?) ?? '') ??
            DateTime.now(),
        motivo: json['motivo'] as String?,
      );

  final String entidade, entidadeId;
  final int linhas;
  final DateTime feitoEm;
  final String? motivo;
}

/// O direito ao apagamento, do lado da app.
///
/// Tudo isto passa por funções do servidor — `punho_procurar_titular` e
/// `punho_apagar_titular` — e nenhuma delas aceita a empresa como parâmetro: a
/// empresa sai da sessão. O cliente diz **quem**, nunca **de onde**.
class DadosPessoaisService {
  const DadosPessoaisService(this._cliente);
  final SupabaseClient _cliente;

  /// Todas as fichas que batem certo com o termo — nome, NIF, telefone ou
  /// email. Devolve mais do que uma de propósito.
  Future<List<FichaDeTitular>> procurar(String termo) async {
    final linhas =
        await _cliente.rpc(
              'punho_procurar_titular',
              params: {'p_termo': termo},
            )
            as List<dynamic>;
    return linhas
        .map((l) => FichaDeTitular.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  /// Apaga uma ficha. O nome passa a «Titular apagado» e o resto sai — no
  /// registo, nas reservas onde o nome tinha sido copiado, e na projecção.
  Future<int> apagar({
    required String entidade,
    required String entidadeId,
    String? motivo,
  }) async {
    final resposta =
        await _cliente.rpc(
              'punho_apagar_titular',
              params: {
                'p_entidade': entidade,
                'p_entidade_id': entidadeId,
                'p_motivo': motivo,
              },
            )
            as Map<String, dynamic>;
    return ((resposta['operacoes_redigidas'] as num?)?.toInt() ?? 0) +
        ((resposta['reservas_projectadas_redigidas'] as num?)?.toInt() ?? 0);
  }

  /// O que já foi apagado nesta empresa. Limite explícito: isto é um histórico
  /// que só cresce, e um ecrã não precisa dele todo.
  Future<List<ApagamentoFeito>> feitos() async {
    final linhas = await _cliente
        .from('punho_apagamentos')
        .select('entidade, entidade_id, motivo, operacoes_redigidas, '
            'reservas_redigidas, feito_em')
        .order('feito_em', ascending: false)
        .limit(50);
    return linhas.map(ApagamentoFeito.fromJson).toList();
  }
}

final dadosPessoaisServiceProvider = Provider<DadosPessoaisService>(
  (ref) => DadosPessoaisService(Supabase.instance.client),
);

/// O termo procurado. Vazio quer dizer «ainda não procurou nada» — e um ecrã
/// que não procurou não mostra lista nenhuma, mostra o que fazer.
final termoDeProcuraProvider = StateProvider<String>((ref) => '');

final fichasEncontradasProvider = FutureProvider<List<FichaDeTitular>>((
  ref,
) async {
  final termo = ref.watch(termoDeProcuraProvider).trim();
  if (termo.isEmpty) return const [];
  return ref.watch(dadosPessoaisServiceProvider).procurar(termo);
});

final apagamentosFeitosProvider = FutureProvider<List<ApagamentoFeito>>(
  (ref) => ref.watch(dadosPessoaisServiceProvider).feitos(),
);

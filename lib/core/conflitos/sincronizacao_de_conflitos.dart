import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/conflito_pendente.dart';
import 'registo_de_conflitos.dart';

class ResultadoDaSincronizacaoDeConflitos {
  const ResultadoDaSincronizacaoDeConflitos({
    required this.enviados,
    required this.recebidos,
    this.erro,
  });

  const ResultadoDaSincronizacaoDeConflitos.falhou(String this.erro)
    : enviados = 0,
      recebidos = 0;

  final int enviados, recebidos;
  final String? erro;

  bool get correu => erro == null;
}

/// Sincronização do `ConflitoPendente` — mesma família da
/// `SincronizacaoEntreDispositivos`, mas sem cursor: a tabela é pequena por
/// natureza (o número de disputas reais por máquina, não um log de eventos),
/// por isso cada sincronização traz a tabela inteira da empresa.
///
/// Só o Gestor grava (`ehGestor`): tanto criar como resolver um conflito são
/// decisões do Gestor na RLS (`punho_e_gestor()`), reflectindo que "o
/// árbitro é quem tem app Gestor" — um colaborador nunca tenta o pedido, para
/// não gastar rede num pedido que a base de dados vai sempre recusar.
class SincronizacaoDeConflitos {
  SincronizacaoDeConflitos({
    required this.registo,
    required SupabaseClient cliente,
    required this.empresaId,
    required this.ehGestor,
  }) : _cliente = cliente;

  final RegistoDeConflitos registo;
  final SupabaseClient _cliente;
  final String empresaId;
  final bool ehGestor;

  static const _tabela = 'punho_conflitos_pendentes';

  bool _aCorrer = false;

  Future<ResultadoDaSincronizacaoDeConflitos> sincronizar() async {
    if (_aCorrer) {
      return const ResultadoDaSincronizacaoDeConflitos(
        enviados: 0,
        recebidos: 0,
      );
    }
    _aCorrer = true;
    try {
      await registo.esperarEscritas();
      final recebidos = await _receber();
      final enviados = await _enviar();
      return ResultadoDaSincronizacaoDeConflitos(
        enviados: enviados,
        recebidos: recebidos,
      );
    } catch (erro) {
      debugPrint('[Conflitos] sync falhou: $erro');
      return ResultadoDaSincronizacaoDeConflitos.falhou('$erro');
    } finally {
      _aCorrer = false;
    }
  }

  Future<int> _receber() async {
    final linhas =
        await _cliente.from(_tabela).select().eq('empresa_id', empresaId)
            as List;
    for (final linha in linhas) {
      await registo.aplicarRemoto(_daSupabase(Map<String, dynamic>.from(linha as Map)));
    }
    return linhas.length;
  }

  Future<int> _enviar() async {
    // Ver o comentário na classe: um colaborador nunca chega aqui com nada
    // para enviar (a detecção, quando existir, só marca para envio no
    // aparelho do Gestor), mas a guarda fica explícita — não implícita no
    // "nunca terá nada em `porEnviar`" — para não depender de outra parte do
    // código se comportar bem.
    if (!ehGestor) return 0;
    final porEnviar = registo.porEnviar;
    if (porEnviar.isEmpty) return 0;
    final linhas = [for (final c in porEnviar) _paraSupabase(c)];
    // `upsert` e não `insert`: reenviar depois de a rede cair a meio não pode
    // duplicar nem falhar por já existir.
    await _cliente.from(_tabela).upsert(linhas, onConflict: 'id');
    await registo.marcarEnviados(porEnviar.map((c) => c.id).toSet());
    return porEnviar.length;
  }

  // `criado_em` fica de fora de propósito: o `default now()` da tabela
  // resolve-o na primeira inserção, e num upsert seguinte (ex.: o Gestor a
  // resolver um conflito já existente) não faz parte do `SET` gerado pelo
  // PostgREST, portanto mantém-se o valor original — exactamente o que se
  // quer, sem ter de o reenviar.
  Map<String, Object?> _paraSupabase(ConflitoPendente c) => {
    'id': c.id,
    'empresa_id': empresaId,
    'tipo': c.tipo.name,
    'entidade_a_id': c.entidadeAId,
    'entidade_b_id': c.entidadeBId,
    'machine_ids': c.machineIdsPartilhados,
    'envolvidos': c.envolvidos,
    'estado': c.estado.name,
    'resolvido_em': c.resolvidoEm?.toUtc().toIso8601String(),
    'resolvido_por': c.resolvidoPor,
    'fica_com_entidade_id': c.ficaComEntidadeId,
  };

  ConflitoPendente _daSupabase(Map<String, dynamic> json) => ConflitoPendente(
    id: json['id'] as String,
    tipo: TipoConflito.values.byName(json['tipo'] as String),
    entidadeAId: json['entidade_a_id'] as String,
    entidadeBId: json['entidade_b_id'] as String,
    machineIdsPartilhados: List<String>.from(
      json['machine_ids'] as List? ?? const [],
    ),
    envolvidos: List<String>.from(json['envolvidos'] as List? ?? const []),
    criadoEm:
        DateTime.tryParse(json['criado_em'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    estado: EstadoConflito.values.byName(
      json['estado'] as String? ?? 'pendente',
    ),
    resolvidoEm: json['resolvido_em'] == null
        ? null
        : DateTime.tryParse(json['resolvido_em'] as String)?.toLocal(),
    resolvidoPor: json['resolvido_por'] as String?,
    ficaComEntidadeId: json['fica_com_entidade_id'] as String?,
  );
}

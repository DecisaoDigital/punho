import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/contabilista.dart';

/// Onde vive a página que o contabilista abre.
///
/// Já apontou directamente à Edge Function, para o token passar por menos
/// mãos — mas essa página nunca chegou a ver-se: o Supabase reescreve
/// `text/html` para `text/plain` com `nosniff` em `*.supabase.co`, defesa
/// contra phishing alojado em funções, e o contabilista recebia o código-fonte
/// em bruto. Verificado com uma função descartável: só o HTML é degradado, o
/// JSON passa intacto.
///
/// Agora a página é estática, servida pelo i9 por Tailscale Funnel, e é ela
/// que vai buscar o HTML à função dentro de JSON. O token continua a não
/// passar por serviço nenhum a mais: sai daqui e entra na função.
///
/// Mudar isto **parte todos os convites já enviados** — o link é gravado no
/// momento em que se cria o convite, não é resolvido depois.
const portalContabilista =
    'https://decisaodigital.tailb66396.ts.net/portal/';

/// Link que o contabilista abre.
String linkContabilista(String token) => '$portalContabilista?t=$token';

/// Mensagem pronta a enviar ao contabilista.
///
/// Função de topo para os testes a poderem verificar sem montar diálogo nenhum.
/// Diz o período à frente porque é a primeira pergunta que ele vai fazer, e diz
/// que pode voltar porque senão ele tenta responder a tudo de uma sentada e
/// desiste a meio.
String mensagemContabilista(ConviteCriado convite, {String? empresa}) {
  final de = _mesPorExtenso(convite.mesInicial);
  final ate = _mesPorExtenso(convite.mesFinal);
  final nomeEmpresa = (empresa == null || empresa.trim().isEmpty)
      ? 'a empresa'
      : empresa.trim();
  return 'Olá! Preciso da sua ajuda para pôr o histórico de $nomeEmpresa '
      'no Punho.\n\n'
      'Abra este link no computador:\n'
      '${linkContabilista(convite.token)}\n\n'
      'É uma grelha de meses, de $de a $ate. O que não souber, deixe em '
      'branco — em branco não é zero, e o Punho sabe a diferença.\n'
      'Se só tiver o total de um ano, escreva-o na última linha desse ano.\n\n'
      'Não precisa de conta nem de instalar nada, e pode voltar ao mesmo link '
      'para corrigir o que já escreveu. O link é pessoal: quem o tiver escreve '
      'na contabilidade desta empresa.\n'
      'Válido até ${convite.expiraEm.day.toString().padLeft(2, '0')}/'
      '${convite.expiraEm.month.toString().padLeft(2, '0')}/'
      '${convite.expiraEm.year}.';
}

const _meses = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

String _mesPorExtenso(DateTime d) => '${_meses[d.month - 1]} de ${d.year}';

/// Tudo o que a área do contabilista precisa do servidor.
///
/// Interface fina pela mesma razão que [AcessoService]: `SupabaseClient` é uma
/// classe concreta com API encadeada, impossível de fakear a sério. Os testes
/// implementam isto.
abstract class ContabilistaService {
  /// O catálogo de perguntas. Vem da base para não haver duas cópias.
  Future<List<RubricaContabilista>> catalogo();

  /// Convites emitidos por esta empresa, do mais recente para trás.
  Future<List<ConviteContabilista>> convites();

  /// Emite um convite. O token volta **uma vez só** — ver [ConviteCriado].
  Future<ConviteCriado> criarConvite({
    String? nome,
    String? email,
    int anos = 5,
  });

  /// Fecha o link. O que já foi escrito fica: as respostas são da empresa.
  Future<void> revogarConvite(String conviteId);

  /// O que ficou por responder, agregado por rubrica.
  Future<List<LacunaContabilista>> lacunas();

  /// As respostas de uma rubrica — as que estão guardadas, não a série
  /// repartida. Para editar é preciso ver o que lá está mesmo.
  Future<List<RespostaContabilista>> respostasDe(String rubrica);

  /// Escreve como gestor. Valor nulo apaga, que é como se volta a "não sei".
  Future<void> guardar({
    required String rubrica,
    DateTime? mes,
    int? ano,
    int? valorCentavos,
    String? valorTexto,
  });

  /// O que o contabilista deixou escrito, do mais recente para trás.
  Future<List<MensagemContabilista>> mensagens();

  /// Marca por lidas as que ainda não estão. Só tira o realce — o texto fica.
  Future<void> marcarMensagensLidas(List<String> ids);
}

class SupabaseContabilistaService implements ContabilistaService {
  const SupabaseContabilistaService(this._client);
  final SupabaseClient _client;

  @override
  Future<List<RubricaContabilista>> catalogo() async {
    final linhas = await _client
        .from('punho_rubricas_contabilista')
        .select(
          'chave, rotulo, ajuda, periodicidade, tipo, opcoes, essencial, '
          'aceita_anual',
        )
        .eq('activa', true)
        // `ascending: true` explícito: o postgrest-dart ordena ao contrário por
        // omissão. A coluna chama-se `ordem` e servia para nada — o catálogo
        // saía do fim para o princípio.
        .order('ordem', ascending: true);
    return linhas
        .map((l) => RubricaContabilista.fromJson(l))
        .toList(growable: false);
  }

  @override
  Future<List<ConviteContabilista>> convites() async {
    // As colunas vão à mão de propósito: `select('*')` trazia o `token_hash`
    // para dentro da app, e não há nada que a app faça com ele.
    final linhas = await _client
        .from('punho_convites_contabilista')
        .select(
          'id, nome, email, mes_inicial, mes_inicial_efectivo, mes_final, '
          'criado_em, expira_em, '
          'aberto_em, submetido_em, revogado_em',
        )
        .order('criado_em', ascending: false);
    return linhas
        .map((l) => ConviteContabilista.fromJson(l))
        .toList(growable: false);
  }

  @override
  Future<ConviteCriado> criarConvite({
    String? nome,
    String? email,
    int anos = 5,
  }) async {
    final linhas =
        await _client.rpc(
              'punho_criar_convite_contabilista',
              params: {'p_nome': nome, 'p_email': email, 'p_anos': anos},
            )
            as List<dynamic>;
    if (linhas.isEmpty) {
      throw StateError('O servidor não devolveu o convite.');
    }
    return ConviteCriado.fromJson(linhas.first as Map<String, dynamic>);
  }

  @override
  Future<void> revogarConvite(String conviteId) => _client
      .from('punho_convites_contabilista')
      .update({'revogado_em': DateTime.now().toUtc().toIso8601String()})
      .eq('id', conviteId);

  @override
  Future<List<LacunaContabilista>> lacunas() async {
    // `p_empresa: null` de propósito. A função faz
    // `coalesce(p_empresa, punho_empresa_atual())`, portanto a empresa sai da
    // sessão, no servidor. Mandá-la daqui era deixar a app escolher de quem são
    // as lacunas que vê — e a app não tem nada que escolher isso.
    final linhas =
        await _client.rpc(
              'punho_lacunas_contabilista',
              params: {'p_empresa': null},
            )
            as List<dynamic>;
    return linhas
        .map((l) => LacunaContabilista.fromJson(l as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<RespostaContabilista>> respostasDe(String rubrica) async {
    final linhas = await _client
        .from('punho_respostas_contabilista')
        .select('rubrica, mes, ano, valor_centavos, valor_texto, origem')
        .eq('rubrica', rubrica);
    return linhas
        .map((l) => RespostaContabilista.fromJson(l))
        .toList(growable: false);
  }

  @override
  Future<void> guardar({
    required String rubrica,
    DateTime? mes,
    int? ano,
    int? valorCentavos,
    String? valorTexto,
  }) => _client.rpc(
    'punho_guardar_resposta_gestor',
    params: {
      'p_rubrica': rubrica,
      'p_mes': mes == null ? null : _soData(mes),
      'p_ano': ano,
      'p_valor_centavos': valorCentavos,
      'p_valor_texto': valorTexto,
    },
  );

  @override
  Future<List<MensagemContabilista>> mensagens() async {
    // Sem `empresa_id` no filtro: a RLS já limita à empresa da sessão, e
    // mandá-lo daqui era deixar a app escolher de quem lê as mensagens.
    // Isto é uma conversa: nunca encolhe. Sem tecto, ao fim de uns anos o ecrã
    // das mensagens passa a puxar a troca inteira com o contabilista para
    // mostrar as que cabem. 500 é folgado de mais para o que aqui se troca —
    // umas dezenas por ano — e é o que impede o pior caso.
    final linhas = await _client
        .from('punho_mensagens_contabilista')
        .select('id, texto, criado_em, lido_em')
        .order('criado_em', ascending: false)
        .limit(500);
    return linhas
        .map((l) => MensagemContabilista.fromJson(l))
        .toList(growable: false);
  }

  @override
  Future<void> marcarMensagensLidas(List<String> ids) async {
    if (ids.isEmpty) return;
    await _client
        .from('punho_mensagens_contabilista')
        .update({'lido_em': DateTime.now().toUtc().toIso8601String()})
        .inFilter('id', ids)
        // Só as que ainda não estão: reler não muda a data de quando se leu.
        .isFilter('lido_em', null);
  }
}

/// `2025-03-01` — o Postgres quer `date`, e um ISO completo com hora entrava
/// com fuso e podia recuar um dia.
String _soData(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

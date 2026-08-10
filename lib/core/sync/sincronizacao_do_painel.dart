import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/operation_repository.dart';
import '../../domain/models/arranjo_do_painel.dart';

/// O que aconteceu numa passagem pelo canal do painel.
class ResultadoDoPainel {
  const ResultadoDoPainel({
    required this.correu,
    this.subiu = false,
    this.mudouAqui = false,
    this.erro,
  });

  /// Falhou a ligação ou o servidor recusou. Não é caso de intervenção humana:
  /// tenta-se outra vez no ciclo seguinte.
  final bool correu;

  /// A arrumação deste aparelho foi entregue.
  final bool subiu;

  /// O painel deste aparelho mudou — veio outro do servidor, ou a guarda de
  /// ordem barrou o nosso e ficámos com o que lá estava. Quem chama tem de
  /// reconstruir o ecrã.
  final bool mudouAqui;

  final String? erro;
}

/// **O painel do gestor tem canal próprio.**
///
/// Não é o instantâneo (`punho_estado_operacional`) e não é a fila de operações
/// (`punho_operacoes`). É a tabela `punho_painel`, uma linha por empresa, com a
/// função `punho_painel_gravar` à frente dela.
///
/// ## Porque não ficou no instantâneo
///
/// Ficou, até 10 de Agosto de 2026, e cobrava uma renda que não se via. O
/// instantâneo sobe inteiro e tem a regra "o servidor manda": quem chega com
/// uma revisão velha deita fora o que tivesse por subir. Para a ficha da
/// empresa — editada uma vez, num sítio só — é a regra certa. Para o painel
/// não: marca-se uma caixa, e entre o toque e o ciclo de sincronização cabe
/// qualquer coisa que outro telemóvel faça à ficha. A revisão avança, a
/// arrumação desaparece, e não há erro nenhum a dizê-lo.
///
/// Tapava-se isso com uma marca à parte que sobrevivia à importação e subia na
/// mesma passagem — remendo que funcionava e que só existia por causa da boleia.
/// E a boleia custava nos dois sentidos: marcar uma caixa punha a **ficha
/// inteira** por subir e fazia avançar a revisão para toda a gente.
///
/// ## Porque não foi para a fila de operações
///
/// A fila serve o que duas pessoas mexem ao mesmo tempo e precisa da ordem do
/// servidor para não se perder. O painel é arrumação de um gestor. Pô-lo lá
/// obrigava a inventar uma entidade nova e a alargar-lhe a lista no servidor,
/// para resolver uma disputa que não existe.
///
/// ## A guarda de ordem, e porque é o relógio de quem arrumou
///
/// `punho_painel_gravar` só escreve se o `p_updated_at` que recebe for igual ou
/// mais recente do que o que lá está — e devolve **a linha como ficou**, que
/// pode ser a que já lá estava. Quem chama tem de olhar para o que voltou, e
/// não presumir que ganhou.
///
/// O carimbo é o momento em que o gestor arrumou, não o momento em que a rede
/// apareceu. Um telemóvel que esteve a manhã sem sinal não pode chegar às duas
/// da tarde e desfazer o que outra pessoa arrumou ao meio-dia. Isso era a
/// avaria do instantâneo, que carimbava com `now()` do servidor e ganhava
/// sempre.
///
/// ## Sem `empresaId`
///
/// De propósito. A função tira a empresa de `punho_empresa_atual()` e a leitura
/// vai pela RLS, que já só deixa ver a linha da empresa de quem pergunta. Um
/// identificador que o cliente enviasse era mais uma coisa que ele podia enviar
/// errada — e a identidade vem do servidor, nunca de quem chama.
class SincronizacaoDoPainel {
  SincronizacaoDoPainel({required this.repositorio, required this.cliente});

  final PersistentOperationRepository repositorio;
  final SupabaseClient cliente;

  /// Costuras para os testes exercitarem a política sem rede. O caminho a
  /// sério é o de baixo, e há um teste que o percorre para ler o pedido que sai.
  @visibleForTesting
  Future<Map<String, dynamic>?> Function()? lerDoServidor;

  @visibleForTesting
  Future<Map<String, dynamic>?> Function(ArranjoDoPainel, DateTime)?
  gravarNoServidor;

  Future<ResultadoDoPainel> sincronizar() async {
    try {
      final remoto = await (lerDoServidor?.call() ?? _ler());

      if (_deveSubir(remoto)) return await _subir();

      // **Ausente não é vazio.** Não haver linha em `punho_painel` não é a
      // empresa a dizer "não escolheu nada" — é ela calada. Ler esse silêncio
      // como painel vazio apagava a arrumação do gestor sem erro à vista.
      // Esvaziar de propósito continua a chegar: aí a linha existe, com as
      // listas vazias lá dentro.
      if (remoto == null) return const ResultadoDoPainel(correu: true);

      final mudou = repositorio.aplicarPainelDoServidor(_arranjoDe(remoto));
      return ResultadoDoPainel(correu: true, mudouAqui: mudou);
    } on PostgrestException catch (erro) {
      return ResultadoDoPainel(correu: false, erro: erro.message);
    } catch (erro) {
      return ResultadoDoPainel(correu: false, erro: '$erro');
    }
  }

  /// Sobe quando este aparelho arrumou alguma coisa — ou quando a tabela ainda
  /// está vazia e o painel local não.
  ///
  /// A segunda metade é a semente. `punho_painel` nasceu vazia a 10 de Agosto e
  /// um gestor que já tivesse o painel arrumado tinha-o só em disco, sem marca
  /// nenhuma por subir (já fora dado por entregue, pelo canal antigo). Sem esta
  /// linha ficava com o painel no telemóvel dele e vazio em todos os outros —
  /// que é exactamente o que a tabela veio resolver.
  bool _deveSubir(Map<String, dynamic>? remoto) =>
      repositorio.painelPorSubir || (remoto == null && !repositorio.painel.estaVazio);

  Future<ResultadoDoPainel> _subir() async {
    final meu = repositorio.painel;
    // Sem carimbo é porque é a semente: nunca foi arrumado nesta instalação, só
    // herdado do disco. Vale a hora de agora — não há disputa a resolver, a
    // linha ainda não existe.
    final quando = repositorio.painelArrumadoEm ?? DateTime.now().toUtc();

    final linha = await (gravarNoServidor?.call(meu, quando) ??
        _gravar(meu, quando));

    // Entregue ou barrado, deixou de estar à espera: barrado quer dizer que lá
    // está coisa mais recente, e insistir com a nossa era voltar a tentar
    // perder. O que fica é o que o servidor devolveu.
    repositorio.marcarPainelSincronizado();

    if (linha == null) return const ResultadoDoPainel(correu: true, subiu: true);

    final ficou = _arranjoDe(linha);
    final mudou = repositorio.aplicarPainelDoServidor(ficou);
    return ResultadoDoPainel(
      correu: true,
      // Se o que ficou lá não é o nosso, a guarda barrou-nos.
      subiu: ficou == meu,
      mudouAqui: mudou,
    );
  }

  Future<Map<String, dynamic>?> _ler() async {
    final linha = await cliente
        .from('punho_painel')
        .select('dados, updated_at, revision')
        .maybeSingle();
    return linha == null ? null : Map<String, dynamic>.from(linha);
  }

  Future<Map<String, dynamic>?> _gravar(
    ArranjoDoPainel arranjo,
    DateTime quando,
  ) async {
    final devolvido = await cliente.rpc(
      'punho_painel_gravar',
      params: {
        'p_dados': arranjo.toJson(),
        'p_updated_at': quando.toUtc().toIso8601String(),
      },
    );
    return devolvido is Map ? Map<String, dynamic>.from(devolvido) : null;
  }

  ArranjoDoPainel _arranjoDe(Map<String, dynamic> linha) {
    final dados = linha['dados'];
    return ArranjoDoPainel.fromJson(
      dados is Map ? Map<String, dynamic>.from(dados) : null,
    );
  }
}

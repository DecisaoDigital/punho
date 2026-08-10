import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Para onde vai uma operação que o servidor não aceitou.
///
/// ## Porque é que a lista fechada estava errada
///
/// Até 10 de Agosto de 2026 isto era uma lista de códigos conhecidos —
/// `{23514, 23502, 23503, 22007, 22P02}` — e **tudo o que não estivesse lá era
/// tratado como falha de rede**: `rethrow`, o lote inteiro por enviar, a fila
/// presa, e a app a bater à porta do servidor de 20 em 20 minutos sem ninguém
/// ver nada.
///
/// O desenho tinha a decisão ao contrário. A pergunta certa não é «este código
/// está na minha lista?», é «**o servidor recusou o conteúdo, ou tropeçou no
/// caminho?**». Com a lista fechada, cada validação nova que o servidor ganha
/// tranca as apps que já estão no terreno — e elas não se actualizam sozinhas.
/// Aconteceu duas vezes em três dias: o `42501` das permissões do colaborador,
/// e o `23514` da máquina que não sai duas vezes. Ia acontecer sempre.
///
/// Por isso a classificação é agora **por natureza do erro**, e o que não se
/// conhece cai no balde certo por omissão:
///
/// * [transitorio] — o caminho falhou. Fica na fila, tenta-se outra vez.
/// * [sessao] — a sessão caducou. Renova-se e repete-se; **nunca** quarentena.
/// * [definitivo] — o servidor recusou o **conteúdo**. Sai da fila para a
///   quarentena, com o que ele disse, para uma pessoa poder ver.
///
/// Se acrescentares um código a uma lista para resolver um caso, pára e
/// pergunta em que balde é que ele devia ter caído sozinho.
enum DestinoDaRecusa {
  /// Rede, timeout, 5xx, 429 — e qualquer erro que não traga um SQLSTATE.
  transitorio,

  /// Token expirado ou recusado. Renovar e repetir.
  sessao,

  /// O conteúdo é que está mal. Reenviar nunca vai resultar.
  definitivo,
}

/// SQLSTATE: cinco caracteres, dígitos e maiúsculas. `23514`, `42501`,
/// `P0001`, `23P01`. Serve para separar o que vem do **Postgres** (uma decisão
/// sobre o conteúdo) do que vem do PostgREST (`PGRST301`) ou do fio (`401`).
bool eSqlstate(String? codigo) =>
    codigo != null && RegExp(r'^[0-9A-Z]{5}$').hasMatch(codigo);

/// SQLSTATEs que o Postgres levanta **sem julgar o conteúdo**: a ligação caiu a
/// meio, houve deadlock, o servidor está a reiniciar, acabaram as ligações.
///
/// Estes são a excepção à regra «SQLSTATE = definitivo», e são-no por uma razão
/// só: mandar um deadlock para a quarentena era perder trabalho que o servidor
/// nunca chegou a recusar. Repetir resolve-os.
bool eSqlstateDeInfraestrutura(String codigo) {
  final classe = codigo.substring(0, 2);
  // 08 ligação, 53 sem recursos, 57 intervenção do operador (shutdown, cancel),
  // 58 erro do sistema, XX erro interno do próprio Postgres.
  if (const {'08', '53', '57', '58', 'XX'}.contains(classe)) return true;
  // Serialização e deadlock: a transacção seguinte passa.
  return const {'40001', '40P01', '55P03'}.contains(codigo);
}

/// Códigos de autenticação: a sessão caducou ou foi recusada.
///
/// **É aqui que a inversão se pode virar contra nós.** Um token expirado
/// classificado como definitivo mandava a fila inteira do utilizador para a
/// quarentena de uma assentada — o trabalho de um dia numa obra sem rede,
/// perdido de uma vez e em silêncio. Por isso este balde é o **primeiro** a ser
/// perguntado, antes de qualquer outra coisa.
bool eFalhaDeSessao(String? codigo) {
  if (codigo == null) return false;
  // O PostgREST devolve PGRST301 (JWT expirado) e vizinhos na classe 3xx.
  if (RegExp(r'^PGRST3\d\d$').hasMatch(codigo)) return true;
  // O postgrest-dart põe aqui o estado HTTP quando a resposta não traz corpo.
  return codigo == '401' || codigo == '403';
}

/// Em que balde cai este erro.
///
/// Recebe a excepção tal como veio — `PostgrestException`, `SocketException`,
/// `TimeoutException`, o que for. Não há lista de códigos aceitáveis: há uma
/// pergunta de cada vez, pela ordem em que doem se forem respondidas mal.
DestinoDaRecusa classificarFalha(Object erro) {
  if (erro is PostgrestException) {
    // 1º a sessão, sempre. Ver [eFalhaDeSessao].
    if (eFalhaDeSessao(erro.code)) return DestinoDaRecusa.sessao;

    final codigo = erro.code;

    // Sem código não há decisão do Postgres: só se sabe que não chegou lá.
    if (codigo == null || codigo.isEmpty) return DestinoDaRecusa.transitorio;

    // **O SQLSTATE vem primeiro, e não é detalhe.** `23514` e `53300` também
    // passam num `int.tryParse` — tratá-los como estado HTTP mandava metade
    // das recusas de conteúdo para o balde errado, silenciosamente. O que os
    // separa é o comprimento: SQLSTATE tem cinco caracteres, o estado tem três.
    if (eSqlstate(codigo)) {
      return eSqlstateDeInfraestrutura(codigo)
          ? DestinoDaRecusa.transitorio
          : DestinoDaRecusa.definitivo;
    }

    // Estado HTTP em vez de SQLSTATE: 5xx e 429 são o servidor a ceder.
    final estado = int.tryParse(codigo);
    if (estado != null) {
      if (estado >= 500 || estado == 429) return DestinoDaRecusa.transitorio;
      // 4xx que não seja de sessão: o pedido é que está mal formado.
      return DestinoDaRecusa.definitivo;
    }

    // `PGRST202` (função que não existe), `PGRST204` (coluna que não existe):
    // é o PostgREST a falar do **esquema**, não o Postgres a falar da linha.
    // Costuma ser um deploy a meio ou a cache de esquema por refrescar, e nesse
    // caso passa sozinho. Fica na fila: perder a operação seria pior do que
    // esperar.
    return DestinoDaRecusa.transitorio;
  }

  if (erro is AuthException) return DestinoDaRecusa.sessao;

  // Rede: nada disto chegou ao servidor. Estão aqui nomeados por documentarem
  // a intenção, não por serem precisos — caem todos no ramo por omissão, que é
  // este mesmo.
  if (erro is SocketException ||
      erro is TimeoutException ||
      erro is HandshakeException) {
    return DestinoDaRecusa.transitorio;
  }

  // `ClientException` do package:http entra aqui: é dependência de teste, não
  // de produção, e não se importa `http` em `lib/` só para lhe dizer o nome.
  //
  // Desconhecido é transitório de propósito: o que não se percebe não se deita
  // fora. Fica na fila e alguém vê a fila a crescer.
  return DestinoDaRecusa.transitorio;
}

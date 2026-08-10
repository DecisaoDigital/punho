import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:punho/core/sync/classificacao_de_recusas.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A regra das recusas, um balde de cada vez.
///
/// O que estes testes protegem não é a lista de códigos — é o **desenho**. A
/// lista fechada («só isto é definitivo, o resto é rede») trancou as apps do
/// terreno duas vezes em três dias, porque toda a validação nova do servidor
/// caía do lado errado. Ver o teste do fim: ele falha se alguém a repuser.
void main() {
  PostgrestException erro(String? codigo, [String mensagem = 'recusado']) =>
      PostgrestException(message: mensagem, code: codigo);

  group('A — transitório: fica na fila', () {
    test('rede que não chegou a lado nenhum', () {
      for (final falha in <Object>[
        const SocketException('sem rota para o servidor'),
        TimeoutException('demorou de mais'),
        const HandshakeException('certificado recusado'),
        http.ClientException('ligação fechada a meio'),
      ]) {
        expect(
          classificarFalha(falha),
          DestinoDaRecusa.transitorio,
          reason: '${falha.runtimeType} é o caminho, não o conteúdo',
        );
      }
    });

    test('5xx e 429 são o servidor a ceder', () {
      for (final codigo in ['500', '502', '503', '504', '429']) {
        expect(classificarFalha(erro(codigo)), DestinoDaRecusa.transitorio);
      }
    });

    test('sem código não há decisão do Postgres', () {
      expect(classificarFalha(erro(null)), DestinoDaRecusa.transitorio);
      expect(classificarFalha(erro('')), DestinoDaRecusa.transitorio);
    });

    test('SQLSTATE de infraestrutura não é recusa de conteúdo', () {
      // Mandar um deadlock para a quarentena era perder trabalho que o
      // servidor nunca chegou a recusar.
      for (final codigo in [
        '08006', // ligação partida
        '08003',
        '40001', // falha de serialização
        '40P01', // deadlock
        '53300', // sem ligações livres
        '57014', // consulta cancelada
        '57P03', // servidor a arrancar
        '55P03', // lock indisponível
        'XX000', // erro interno do Postgres
      ]) {
        expect(
          classificarFalha(erro(codigo)),
          DestinoDaRecusa.transitorio,
          reason: '$codigo passa se se tentar outra vez',
        );
      }
    });

    test('PGRST de esquema fica na fila — é deploy a meio, não a linha', () {
      // `PGRST202` função inexistente, `PGRST204` coluna inexistente: o
      // PostgREST está a falar do esquema. Costuma passar sozinho, e perder a
      // operação era pior do que esperar.
      for (final codigo in ['PGRST202', 'PGRST204', 'PGRST100']) {
        expect(classificarFalha(erro(codigo)), DestinoDaRecusa.transitorio);
      }
    });
  });

  group('B — sessão: renova e repete, nunca quarentena', () {
    test('PGRST3xx é autenticação', () {
      for (final codigo in ['PGRST301', 'PGRST302', 'PGRST303']) {
        expect(classificarFalha(erro(codigo)), DestinoDaRecusa.sessao);
      }
    });

    test('401 e 403 sem corpo', () {
      expect(classificarFalha(erro('401')), DestinoDaRecusa.sessao);
      expect(classificarFalha(erro('403')), DestinoDaRecusa.sessao);
    });

    test('AuthException do próprio cliente', () {
      expect(
        classificarFalha(const AuthException('sessão terminada')),
        DestinoDaRecusa.sessao,
      );
    });
  });

  group('C — definitivo: quarentena com o que o servidor disse', () {
    test('os códigos que já se conheciam', () {
      for (final codigo in ['23514', '23502', '23503', '22007', '22P02',
        '42501', '23P01', 'P0001']) {
        expect(classificarFalha(erro(codigo)), DestinoDaRecusa.definitivo);
      }
    });

    test('4xx que não é de sessão: o pedido é que está mal', () {
      expect(classificarFalha(erro('400')), DestinoDaRecusa.definitivo);
      expect(classificarFalha(erro('404')), DestinoDaRecusa.definitivo);
    });
  });

  group('a regra é por natureza, não por lista', () {
    test(
      'REGRESSÃO: um SQLSTATE que ainda não existe é definitivo à mesma',
      () {
        // **Este teste é a fechadura.** Se alguém voltar a pôr uma lista
        // fechada de códigos «aceitáveis», estes inventados caem fora dela e
        // passam a transitórios — e a fila do terreno volta a trancar na
        // primeira validação nova que o servidor ganhar. Se este teste falhar,
        // não o mudes: olha para o que voltou a ser uma lista.
        for (final inventado in [
          'Z9Z99', // não existe, e nunca vai existir
          '23Z01', // uma restrição nova da classe 23
          '42Z99', // uma regra de acesso nova
          'P0009', // um raise novo de uma função PL/pgSQL
          '99999',
        ]) {
          expect(
            classificarFalha(erro(inventado)),
            DestinoDaRecusa.definitivo,
            reason:
                '$inventado traz decisão do servidor sobre a linha: reenviar '
                'nunca vai resultar, e prender a fila é o pior dos dois males',
          );
        }
      },
    );

    test('REGRESSÃO: um erro que ninguém previu fica na fila', () {
      // O outro lado da mesma moeda: o que não se percebe não se deita fora.
      expect(
        classificarFalha(StateError('coisa nunca vista')),
        DestinoDaRecusa.transitorio,
      );
    });

    test('o que separa SQLSTATE de estado HTTP é o comprimento', () {
      // `23514` passa num `int.tryParse` e não é estado nenhum. Confundi-los
      // mandava metade das recusas de conteúdo para o balde errado.
      expect(eSqlstate('23514'), isTrue);
      expect(eSqlstate('42501'), isTrue);
      expect(eSqlstate('P0001'), isTrue);
      expect(eSqlstate('401'), isFalse);
      expect(eSqlstate('PGRST301'), isFalse);
      expect(eSqlstate(null), isFalse);
    });
  });
}

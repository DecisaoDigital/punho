import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/sync/registo_de_operacoes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:punho/core/sync/sincronizacao_entre_dispositivos.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O que estes testes protegem: **uma operação que o servidor nunca vai
/// aceitar não pode prender as que ele aceitaria**.
///
/// Foi o que aconteceu na Faixa D da campanha de testes: a ficha da empresa
/// tinha o NIF por preencher, a Edge Function recusava-a com `nif_invalido`, e
/// o motor reenviava a mesma ficha de 20 em 20 minutos — indefinidamente, sem
/// nada chegar ao Control e sem ninguém ver o erro.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RegistoDeOperacoes registo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    registo = RegistoDeOperacoes(await SharedPreferences.getInstance());
  });

  OperacaoPendente op(String id) => OperacaoPendente(
    id: id,
    entidade: 'booking',
    entidadeId: 'res1',
    payload: const {'id': 'res1', 'expectedValueCents': -1},
    feitoEm: DateTime(2026, 8, 3, 10),
  );

  group('classificação da recusa', () {
    // A classificação por natureza vive em `classificacao_de_recusas.dart` e
    // tem testes próprios em `classificacao_de_recusas_test.dart`. Aqui fica
    // só o que o motor promete a quem o usa.
    PostgrestException erro(String? codigo) =>
        PostgrestException(message: 'recusado', code: codigo);

    test('o que o servidor recusa pelo conteúdo é definitivo', () {
      for (final codigo in [
        '23514',
        '23502',
        '23503',
        '22007',
        '22P02',
        '42501',
        'P0001',
      ]) {
        expect(
          SincronizacaoEntreDispositivos.ehRecusaDefinitiva(erro(codigo)),
          isTrue,
          reason: '$codigo é uma decisão sobre a linha, não sobre o caminho',
        );
      }
    });

    test('o que pode melhorar com a rede fica na fila', () {
      // Este é o lado que não pode partir: numa obra sem sinal, a fila é a
      // razão de a app ser utilizável. Nada disto pode ir para quarentena.
      for (final codigo in ['08006', '57014', '53300', null]) {
        expect(
          SincronizacaoEntreDispositivos.ehRecusaDefinitiva(erro(codigo)),
          isFalse,
          reason: '$codigo tem de continuar a ser tentado',
        );
      }
    });

    test('sessão expirada não é recusa de conteúdo nenhuma', () {
      // Ver `sessao_expirada_nao_e_quarentena_test.dart` para o caminho todo.
      expect(
        SincronizacaoEntreDispositivos.ehRecusaDefinitiva(erro('PGRST301')),
        isFalse,
      );
      expect(
        SincronizacaoEntreDispositivos.eFalhaDeSessaoNoEnvio(erro('PGRST301')),
        isTrue,
      );
    });

    test('conflito de reserva tem balde próprio', () {
      // Não é quarentena (payload inválido) mas também não pode ficar a
      // trancar a fila: sai dela para um balde visível à parte. Hoje fica
      // vazio de propósito — o servidor trava a sobreposição com 23514.
      expect(
        SincronizacaoEntreDispositivos.eConflitoDeReserva('23P01'),
        isTrue,
      );
      expect(
        SincronizacaoEntreDispositivos.ehRecusaDefinitiva(erro('23P01')),
        isTrue,
        reason: 'sai da fila na mesma; o que muda é o balde',
      );
    });
  });

  group('quarentena', () {
    test('guarda a operação e o motivo', () async {
      await registo.porEmQuarentena(op('a'), '23514: valor negativo');

      final presas = registo.quarentena;

      expect(presas, hasLength(1));
      expect(presas.single.operacao.id, 'a');
      expect(presas.single.operacao.entidade, 'booking');
      expect(presas.single.motivo, '23514: valor negativo');
    });

    test('sobrevive a fechar a app', () async {
      await registo.porEmQuarentena(op('a'), 'motivo');

      final outro = RegistoDeOperacoes(await SharedPreferences.getInstance());

      expect(outro.quarentena.single.operacao.id, 'a');
    });

    test(
      'a quarentena não é a fila — o que lá está não volta a ser enviado',
      () async {
        await registo.acrescentar(op('a'));
        await registo.porEmQuarentena(op('b'), 'motivo');

        expect(registo.pendentes.map((o) => o.id), ['a']);
        expect(registo.quarentena.map((r) => r.operacao.id), ['b']);
      },
    );

    test('tem tecto próprio', () async {
      for (var i = 0; i < 105; i++) {
        await registo.porEmQuarentena(op('op$i'), 'motivo $i');
      }

      final presas = registo.quarentena;

      expect(presas, hasLength(100));
      expect(presas.last.operacao.id, 'op104');
    });

    test('limpa quando já foi vista', () async {
      await registo.porEmQuarentena(op('a'), 'motivo');

      await registo.limparQuarentena();

      expect(registo.quarentena, isEmpty);
    });
  });

  group('balde de conflitos de reserva', () {
    test('guarda o conflito à parte da quarentena', () async {
      await registo.porEmConflitoDeReserva(op('a'), '23P01: sobreposição');

      expect(registo.conflitosDeReserva, hasLength(1));
      expect(registo.conflitosDeReserva.single.operacao.id, 'a');
      expect(registo.conflitosDeReserva.single.motivo, '23P01: sobreposição');
      // Um conflito de reserva não é lixo de payload: não vai à quarentena.
      expect(registo.quarentena, isEmpty);
    });

    test('sobrevive a fechar a app', () async {
      await registo.porEmConflitoDeReserva(op('a'), 'motivo');

      final outro = RegistoDeOperacoes(await SharedPreferences.getInstance());

      expect(outro.conflitosDeReserva.single.operacao.id, 'a');
    });

    test('limpa quando o gestor já o resolveu', () async {
      await registo.porEmConflitoDeReserva(op('a'), 'motivo');

      await registo.limparConflitosDeReserva();

      expect(registo.conflitosDeReserva, isEmpty);
    });

    /// Desde que o cartão tem «Remarcar» e «Recusar», cada decisão apaga a
    /// linha dela. Sem isto, resolver a primeira fazia desaparecer as outras
    /// por resolver — e ninguém dava por elas terem existido.
    test('resolver um conflito não leva os outros à frente', () async {
      await registo.porEmConflitoDeReserva(op('a'), 'motivo');
      await registo.porEmConflitoDeReserva(op('b'), 'motivo');
      await registo.porEmConflitoDeReserva(op('c'), 'motivo');

      await registo.resolverConflitoDeReserva('b');

      expect(registo.conflitosDeReserva.map((c) => c.operacao.id), ['a', 'c']);
    });

    test('resolver o que já não está lá não mexe em nada', () async {
      await registo.porEmConflitoDeReserva(op('a'), 'motivo');

      await registo.resolverConflitoDeReserva('nao-existe');

      expect(registo.conflitosDeReserva.single.operacao.id, 'a');
    });
  });
}

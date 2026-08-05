import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/sync/registo_de_operacoes.dart';
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
    test('payload incoerente é definitivo — insistir não adianta', () {
      // O que o trigger `punho_operacoes_payload_coerente` levanta.
      expect(
        SincronizacaoEntreDispositivos.ehRecusaDefinitiva('23514'),
        isTrue,
      );
    });

    test('campo em falta e referência inexistente são definitivos', () {
      expect(
        SincronizacaoEntreDispositivos.ehRecusaDefinitiva('23502'),
        isTrue,
      );
      expect(
        SincronizacaoEntreDispositivos.ehRecusaDefinitiva('23503'),
        isTrue,
      );
    });

    test('data e número ilegíveis são definitivos', () {
      expect(
        SincronizacaoEntreDispositivos.ehRecusaDefinitiva('22007'),
        isTrue,
      );
      expect(
        SincronizacaoEntreDispositivos.ehRecusaDefinitiva('22P02'),
        isTrue,
      );
    });

    test('o que pode melhorar com a rede fica na fila', () {
      // Este é o lado que não pode partir: numa obra sem sinal, a fila é a
      // razão de a app ser utilizável. Nada disto pode ir para quarentena.
      for (final codigo in ['08006', '57014', '53300', 'PGRST301', null]) {
        expect(
          SincronizacaoEntreDispositivos.ehRecusaDefinitiva(codigo),
          isFalse,
          reason: '$codigo tem de continuar a ser tentado',
        );
      }
    });

    test('conflito de reserva não é recusa de payload', () {
      // `23P01` é o trigger de sobreposição. É um conflito de negócio, para
      // ser decidido por uma pessoa — não lixo para deitar na quarentena.
      expect(
        SincronizacaoEntreDispositivos.ehRecusaDefinitiva('23P01'),
        isFalse,
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
}

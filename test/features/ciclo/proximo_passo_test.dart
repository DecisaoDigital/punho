import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/ciclo/proximo_passo.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/finance.dart';
import 'package:punho/domain/models/operations.dart';

/// O motor do ciclo: um trabalho, uma data, **um** passo.
///
/// **O que estes testes protegem.** A regra 3 do `docs/PLANO_DO_CICLO.md` — não
/// há trabalho sem próximo passo visível — só é verdade enquanto o `switch` de
/// [proximoPassoDe] responder a todos os estados. O Dart obriga a cobri-los
/// todos; o que ele não obriga é a que a resposta faça sentido para quem a lê
/// às sete da manhã. É disso que isto trata.
///
/// A segunda coisa que aqui se guarda é a **ordem**. Uma lista de tarefas
/// ordenada por data é uma agenda, e uma agenda não diz o que está em falta: a
/// entrega que devia ter sido ontem tem de vir acima do pedido para o mês que
/// vem, sempre.
void main() {
  // Terça-feira, meio da manhã. A hora não é redonda de propósito: nada aqui
  // pode depender dela — o que conta é o dia.
  final hoje = DateTime(2026, 8, 4, 9, 40);

  Booking trabalho({
    String id = 'b1',
    required BookingStatus estado,
    int comecaDaquiA = 1,
    int acabaDaquiA = 3,
    int? valorCents,
  }) => Booking(
    id: id,
    customerId: 'c1',
    customerNameSnapshot: 'Construções Silva',
    machineIds: const ['m1'],
    startsAt: hoje.add(Duration(days: comecaDaquiA)),
    endsAt: hoje.add(Duration(days: acabaDaquiA)),
    status: estado,
    expectedValueCents: valorCents,
  );

  ProximoPasso? passoDe(Booking b, {List<Receipt> recebido = const []}) =>
      proximoPassoDe(b, hoje: hoje, recebimentos: recebido);

  group('cada estado sabe dizer o que falta', () {
    test('um pedido com preço pede que se envie o orçamento', () {
      final passo = passoDe(
        trabalho(estado: BookingStatus.request, valorCents: 40000),
      )!;

      expect(passo.verbo, 'Enviar orçamento');
      expect(passo.accao, AccaoDoPasso.avancarEstado);
      expect(passo.estadoSeguinte, BookingStatus.proposalSent);
      // O valor vai na razão: quem carrega no botão tem de saber o que está a
      // dar por enviado.
      expect(passo.porque, contains('400,00 €'));
    });

    /// **Um orçamento sem preço não é um orçamento.**
    ///
    /// Isto dizia "Enviar orçamento" a um pedido em branco, e o botão avançava
    /// o estado à mesma: a reserva passava a "proposta enviada" sem nunca ter
    /// tido valor. Daí ao trabalho fechado sem valor — o buraco mais caro da
    /// app — é uma linha recta, e por essa altura já ninguém se lembra do
    /// preço. A prova real: a reserva `b1786396745111605` do César, criada a
    /// 10 de Agosto de 2026 com `expectedValueCents: null`.
    test('um pedido sem preço pede o preço, e não o envio', () {
      final passo = passoDe(trabalho(estado: BookingStatus.request))!;

      expect(passo.verbo, 'Pôr preço');
      expect(passo.accao, AccaoDoPasso.declararValor);
      expect(
        passo.estadoSeguinte,
        isNull,
        reason: 'sem valor não se avança para proposta enviada',
      );
    });

    test('um pedido a zero conta como pedido sem preço', () {
      final passo = passoDe(
        trabalho(estado: BookingStatus.request, valorCents: 0),
      )!;

      expect(passo.verbo, 'Pôr preço');
    });

    test('um orçamento enviado pede resposta', () {
      final passo = passoDe(trabalho(estado: BookingStatus.proposalSent))!;

      expect(passo.verbo, 'Confirmar');
      expect(passo.estadoSeguinte, BookingStatus.confirmed);
    });

    // **A entrega e a recolha saíram desta lista a 13/8/2026.** Passaram a ser
    // do relógio: a marcação entrega-se sozinha no dia de início e fecha-se
    // sozinha no fim (`estadoPeloRelogio`). «A minha semana» é o que falta
    // fazer, e nenhuma destas duas falta fazer a ninguém.
    test('um trabalho confirmado não pede nada — o dia dele é que manda', () {
      expect(passoDe(trabalho(estado: BookingStatus.confirmed)), isNull);
    });

    test('um trabalho em curso não pede nada — fecha-se sozinho', () {
      expect(passoDe(trabalho(estado: BookingStatus.rented)), isNull);
    });

    test('um trabalho cancelado não pede nada', () {
      expect(passoDe(trabalho(estado: BookingStatus.cancelled)), isNull);
    });

    test('um trabalho fechado e pago não pede nada', () {
      final passo = passoDe(
        trabalho(
          estado: BookingStatus.completed,
          comecaDaquiA: -5,
          acabaDaquiA: -2,
          valorCents: 90000,
        ),
        recebido: [
          Receipt(
            id: 'r1',
            date: hoje,
            amountCents: 90000,
            customerId: 'c1',
            bookingId: 'b1',
            method: PaymentMethod.transfer,
          ),
        ],
      );

      // Sair da lista é o objectivo. Uma lista que nunca esvazia deixa de se
      // ler, e a partir daí já não protege nada.
      expect(passo, isNull);
    });
  });

  group('o trabalho fechado sem valor', () {
    test('pergunta quanto valeu, antes de falar de dinheiro recebido', () {
      final passo = passoDe(
        trabalho(
          estado: BookingStatus.completed,
          comecaDaquiA: -5,
          acabaDaquiA: -2,
        ),
      )!;

      // É o buraco mais caro da app: um trabalho sem valor não entra na
      // receita nem na margem, e parece arrumado.
      expect(passo.verbo, 'Dizer quanto valeu');
      expect(passo.accao, AccaoDoPasso.declararValor);
      expect(passo.urgencia, Urgencia.hoje);
    });

    test('um valor de zero conta como valor nenhum', () {
      final passo = passoDe(
        trabalho(
          estado: BookingStatus.completed,
          comecaDaquiA: -5,
          acabaDaquiA: -2,
          valorCents: 0,
        ),
      )!;

      expect(passo.accao, AccaoDoPasso.declararValor);
    });
  });

  group('o dinheiro por receber', () {
    Booking fechadoHa(int dias, {int valor = 90000}) => trabalho(
      estado: BookingStatus.completed,
      comecaDaquiA: -dias - 3,
      acabaDaquiA: -dias,
      valorCents: valor,
    );

    test('conta o que falta, não o que foi facturado', () {
      final passo = passoDe(
        fechadoHa(4),
        recebido: [
          Receipt(
            id: 'r1',
            date: hoje,
            amountCents: 40000,
            customerId: 'c1',
            bookingId: 'b1',
            method: PaymentMethod.mbWay,
          ),
        ],
      )!;

      expect(passo.accao, AccaoDoPasso.registarRecebimento);
      expect(passo.valorEmFaltaCents, 50000);
      expect(passo.porque, contains('500,00 €'));
      expect(passo.porque, contains('900,00 €'));
    });

    test('um recebimento de outro trabalho não abate a dívida deste', () {
      final passo = passoDe(
        fechadoHa(4),
        recebido: [
          Receipt(
            id: 'r1',
            date: hoje,
            amountCents: 90000,
            customerId: 'c1',
            bookingId: 'b-outra',
            method: PaymentMethod.transfer,
          ),
        ],
      )!;

      expect(passo.valorEmFaltaCents, 90000);
    });

    test('um dia é um dia, não "1 dias"', () {
      // Um plural mal feito num ecrã que se lê todos os dias desgasta a
      // confiança em tudo o resto que lá está escrito. Visto no Redmi.
      expect(passoDe(fechadoHa(1))!.porque, contains('fechado há 1 dia.'));
      expect(passoDe(fechadoHa(3))!.porque, contains('fechado há 3 dias.'));
    });

    test('até 30 dias é para hoje; a partir daí é atraso', () {
      expect(passoDe(fechadoHa(10))!.urgencia, Urgencia.hoje);
      // Passados 30 dias a probabilidade de cobrar começa a cair depressa —
      // deixa de ser "a receber" e passa a ser um problema.
      expect(passoDe(fechadoHa(45))!.urgencia, Urgencia.atrasado);
    });
  });

  group('a urgência lê-se na data que interessa', () {
    // Desde 13/8/2026 os passos que sobraram medem-se todos pelo início: são
    // os comerciais, que acontecem antes de a máquina sair. A entrega e a
    // recolha deixaram de ser passos — são do relógio.
    test('o orçamento mede-se pelo início', () {
      expect(
        passoDe(trabalho(estado: BookingStatus.request, comecaDaquiA: 0))!
            .urgencia,
        Urgencia.hoje,
      );
      expect(
        passoDe(
          trabalho(
            estado: BookingStatus.proposalSent,
            comecaDaquiA: -1,
            acabaDaquiA: 2,
          ),
        )!.urgencia,
        Urgencia.atrasado,
      );
    });

    test('o recebimento mede-se pelo fim', () {
      // Fechado há dias e ainda por receber: o relógio dele é o do fim.
      final passo = passoDe(
        trabalho(
          estado: BookingStatus.completed,
          comecaDaquiA: -7,
          acabaDaquiA: -1,
          valorCents: 50000,
        ),
      )!;

      expect(passo.verbo, 'Registar recebimento');
      expect(passo.urgencia, Urgencia.hoje);
    });

    test('a hora do dia não muda nada', () {
      final aoFimDoDia = DateTime(2026, 8, 4, 23, 50);
      final passo = proximoPassoDe(
        trabalho(estado: BookingStatus.proposalSent, comecaDaquiA: 0),
        hoje: aoFimDoDia,
        recebimentos: const [],
      )!;

      expect(passo.urgencia, Urgencia.hoje);
    });
  });

  group('a minha semana', () {
    OperationsState estadoCom(List<Booking> trabalhos) =>
        OperationsState(onboarded: true, bookings: trabalhos);

    test('o atrasado vem primeiro, mesmo sendo o mais antigo', () {
      final lista = aMinhaSemana(
        estadoCom([
          trabalho(id: 'daqui-a-dias', estado: BookingStatus.proposalSent),
          trabalho(
            id: 'devia-ter-voltado',
            estado: BookingStatus.proposalSent,
            comecaDaquiA: -6,
            acabaDaquiA: -2,
          ),
        ]),
        hoje,
      );

      expect(lista.map((x) => x.trabalho.id), [
        'devia-ter-voltado',
        'daqui-a-dias',
      ]);
    });

    test('dentro da mesma urgência manda a data', () {
      final lista = aMinhaSemana(
        estadoCom([
          trabalho(
            id: 'quinta',
            estado: BookingStatus.proposalSent,
            comecaDaquiA: 3,
          ),
          trabalho(
            id: 'quarta',
            estado: BookingStatus.proposalSent,
            comecaDaquiA: 2,
          ),
        ]),
        hoje,
      );

      expect(lista.map((x) => x.trabalho.id), ['quarta', 'quinta']);
    });

    test('um trabalho confirmado não enche a lista, perto ou longe', () {
      // Era o «horizonte de uma semana»: um trabalho confirmado para lá de
      // sete dias ficava de fora para a lista não encher. Deixou de ser
      // preciso — confirmado não pede nada, esteja para amanhã ou para o mês
      // que vem, porque quem o entrega é o relógio.
      final lista = aMinhaSemana(
        estadoCom([
          trabalho(
            id: 'para-o-mes-que-vem',
            estado: BookingStatus.confirmed,
            comecaDaquiA: 20,
            acabaDaquiA: 23,
          ),
          trabalho(
            id: 'para-amanha',
            estado: BookingStatus.confirmed,
            comecaDaquiA: 1,
          ),
        ]),
        hoje,
      );

      expect(lista, isEmpty);
    });

    test('um pedido para o mês que vem entra na mesma', () {
      // Aqui o horizonte não se aplica: o orçamento é para fazer agora, seja
      // qual for a data do trabalho. É a diferença entre o que está tratado e
      // o que ainda depende de mim.
      final lista = aMinhaSemana(
        estadoCom([
          trabalho(
            id: 'pedido-longe',
            estado: BookingStatus.request,
            comecaDaquiA: 25,
            acabaDaquiA: 27,
          ),
        ]),
        hoje,
      );

      expect(lista.single.trabalho.id, 'pedido-longe');
    });

    test('o que está em curso não enche a lista — não falta fazer nada', () {
      // Era o contrário até 13/8/2026: uma máquina na rua ficava sempre à
      // vista porque alguém tinha de carregar em «Fechar trabalho». Agora o
      // relógio fecha-o no fim do período, e a lista é só do que falta fazer.
      final lista = aMinhaSemana(
        estadoCom([
          trabalho(
            id: 'aluguer-longo',
            estado: BookingStatus.rented,
            comecaDaquiA: -2,
            acabaDaquiA: 40,
          ),
        ]),
        hoje,
      );

      expect(lista, isEmpty);
    });

    test('o contador de atrasados é o que vai ao emblema', () {
      final estado = estadoCom([
        trabalho(
          id: 'a',
          estado: BookingStatus.request,
          comecaDaquiA: -1,
          valorCents: 30000,
        ),
        trabalho(
          id: 'b',
          estado: BookingStatus.proposalSent,
          comecaDaquiA: -2,
        ),
        trabalho(
          id: 'c',
          estado: BookingStatus.proposalSent,
          comecaDaquiA: 2,
        ),
      ]);

      expect(atrasadosNaSemana(estado, hoje), 2);
    });
  });
}

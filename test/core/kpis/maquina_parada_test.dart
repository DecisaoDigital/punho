import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/kpis/maquina_parada.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/dashboard/presentation/kpi_catalogo.dart';
import 'package:punho/features/dashboard/presentation/widgets/celula_semaforo.dart';

/// **O nome que faltava à percentagem.**
///
/// A «Utilização vs Rentabilidade» diz que a frota está a 38%, e depois o gestor
/// tem de ir à lista das máquinas descobrir sozinho qual delas é que está
/// parada. Uma percentagem não se telefona a ninguém; um nome sim — e o activo
/// é dele, comprado e pago, a ocupar espaço sem render.
void main() {
  final hoje = DateTime(2026, 8, 13, 21);

  Machine maquina(
    String id,
    String nome, {
    MachineStatus status = MachineStatus.available,
    int? precoDia = 18500,
    DateTime? compradaEm,
    bool archived = false,
  }) => Machine(
    id: id,
    name: nome,
    reference: id.toUpperCase(),
    category: 'Escavação',
    status: status,
    dailyRateCents: precoDia,
    acquiredOn: compradaEm,
    archived: archived,
  );

  Booking trabalho(
    String id,
    String maquinaId,
    DateTime inicio,
    DateTime fim, {
    BookingStatus status = BookingStatus.completed,
  }) => Booking(
    id: id,
    customerId: 'c1',
    machineIds: [maquinaId],
    startsAt: inicio,
    endsAt: fim,
    status: status,
    expectedValueCents: 50000,
  );

  group('quem está parada', () {
    test('a que está há mais tempo sem sair, e diz-se o nome dela', () {
      final estado = OperationsState(
        machines: [maquina('m1', 'Mini escavadora'), maquina('m2', 'Martelo')],
        bookings: [
          trabalho('a', 'm1', DateTime(2026, 7, 1), DateTime(2026, 7, 3)),
          trabalho('b', 'm2', DateTime(2026, 8, 8), DateTime(2026, 8, 10)),
        ],
      );
      final p = maquinaMaisParada(estado, hoje)!;

      expect(p.maquina.name, 'Mini escavadora');
      expect(p.dias, 41);
      expect(p.muitoParada, isTrue);
      expect(kpiMaquinaParada(estado, hoje).nivel, NivelSemaforo.vermelho);
    });

    test('a que está alugada hoje está a render, e sai da conta', () {
      // Mesmo que o trabalho anterior tenha acabado há meses: hoje está a dar
      // dinheiro, e é isso que se queria.
      final estado = OperationsState(
        machines: [maquina('m1', 'Mini escavadora')],
        bookings: [
          trabalho('velho', 'm1', DateTime(2026, 3, 1), DateTime(2026, 3, 3)),
          trabalho(
            'agora',
            'm1',
            DateTime(2026, 8, 10),
            DateTime(2026, 8, 20),
            status: BookingStatus.rented,
          ),
        ],
      );

      expect(maquinaMaisParada(estado, hoje), isNull);
      final celula = kpiMaquinaParada(estado, hoje);
      expect(celula.nivel, NivelSemaforo.verde);
      expect(celula.texto, 'Frota toda a trabalhar');
    });

    test('a oficina fica de fora', () {
      // Uma máquina em manutenção também não rende — mas já se sabe porquê e já
      // está em obra. Ocupar com ela o único lugar desta célula era dar ao
      // gestor a notícia que ele menos precisa.
      final estado = OperationsState(
        machines: [
          maquina('m1', 'Na oficina', status: MachineStatus.maintenance),
          maquina('m2', 'Martelo'),
        ],
        bookings: [
          trabalho('a', 'm1', DateTime(2026, 1, 5), DateTime(2026, 1, 7)),
          trabalho('b', 'm2', DateTime(2026, 7, 28), DateTime(2026, 7, 30)),
        ],
      );

      expect(maquinaMaisParada(estado, hoje)!.maquina.name, 'Martelo');
    });

    test('uma reserva cancelada não salva a máquina', () {
      final estado = OperationsState(
        machines: [maquina('m1', 'Mini escavadora')],
        bookings: [
          trabalho('a', 'm1', DateTime(2026, 6, 1), DateTime(2026, 6, 3)),
          trabalho(
            'anulada',
            'm1',
            DateTime(2026, 8, 10),
            DateTime(2026, 8, 12),
            status: BookingStatus.cancelled,
          ),
        ],
      );

      expect(maquinaMaisParada(estado, hoje)!.dias, 71);
    });
  });

  group('a que nunca saiu', () {
    test('conta desde a compra', () {
      final estado = OperationsState(
        machines: [
          maquina('m1', 'Nova', compradaEm: DateTime(2026, 7, 20)),
          maquina('m2', 'Martelo'),
        ],
        bookings: [
          trabalho('b', 'm2', DateTime(2026, 8, 11), DateTime(2026, 8, 12)),
        ],
      );
      final p = maquinaMaisParada(estado, hoje)!;

      expect(p.maquina.name, 'Nova');
      expect(p.dias, 24);
      expect(p.nuncaAlugada, isTrue);
      expect(
        kpiMaquinaParada(estado, hoje).subtexto,
        'Nova · nunca saiu desde a compra',
      );
    });

    test('sem data de compra, não se inventa o dia de onde contar', () {
      // Uma ficha incompleta não é uma máquina parada há 900 dias. Pintar de
      // vermelho o que só está por preencher ensina a desconfiar do painel — e
      // por isso quem ganha aqui é o Martelo, parado há um dia, contra uma
      // máquina que nunca saiu e não sabe dizer desde quando.
      final estado = OperationsState(
        machines: [maquina('m1', 'Sem ficha'), maquina('m2', 'Martelo')],
        bookings: [
          trabalho('b', 'm2', DateTime(2026, 8, 11), DateTime(2026, 8, 12)),
        ],
      );
      final p = maquinaMaisParada(estado, hoje)!;

      expect(p.maquina.name, 'Martelo');
      expect(p.dias, 1);
    });
  });

  group('o que a célula acrescenta ao número', () {
    test('trabalho já marcado muda a leitura', () {
      // 20 dias parada com trabalho marcado para sexta é uma folga; 20 dias
      // parada e a agenda vazia é um activo a pagar-se sozinho.
      final estado = OperationsState(
        machines: [maquina('m1', 'Mini escavadora')],
        bookings: [
          trabalho('a', 'm1', DateTime(2026, 7, 20), DateTime(2026, 7, 24)),
          trabalho(
            'futuro',
            'm1',
            DateTime(2026, 8, 20),
            DateTime(2026, 8, 22),
          ),
        ],
      );

      expect(
        maquinaMaisParada(estado, hoje)!.voltaASair,
        DateTime(2026, 8, 20),
      );
      expect(
        kpiMaquinaParada(estado, hoje).subtexto,
        'Mini escavadora · volta a sair a 20 de Agosto',
      );
    });

    test('sem trabalho à vista, diz-se quanto não facturou', () {
      // Ordem de grandeza assumida — pressupõe procura para todos os dias. Mas
      // «20 dias × 185 €» é uma conta que ele confere de cabeça, e um número
      // aproximado e marcado vale mais do que um espaço em branco.
      final estado = OperationsState(
        machines: [maquina('m1', 'Mini escavadora')],
        bookings: [
          trabalho('a', 'm1', DateTime(2026, 7, 20), DateTime(2026, 7, 24)),
        ],
      );

      expect(maquinaMaisParada(estado, hoje)!.naoFacturadoCents, 20 * 18500);
      expect(
        kpiMaquinaParada(estado, hoje).subtexto,
        'Mini escavadora · 3700 € por facturar, ao preço de tabela',
      );
    });

    test('uma máquina parada é uma máquina; quatro é uma frota a mais', () {
      final estado = OperationsState(
        machines: [
          maquina('m1', 'Mini escavadora'),
          maquina('m2', 'Martelo'),
          maquina('m3', 'Placa'),
        ],
        bookings: [
          trabalho('a', 'm1', DateTime(2026, 6, 1), DateTime(2026, 6, 3)),
          trabalho('b', 'm2', DateTime(2026, 7, 1), DateTime(2026, 7, 3)),
          // Parada há 4 dias: não chega ao limiar e não se conta.
          trabalho('c', 'm3', DateTime(2026, 8, 8), DateTime(2026, 8, 9)),
        ],
      );

      expect(maquinaMaisParada(estado, hoje)!.outrasParadas, 1);
      expect(
        kpiMaquinaParada(estado, hoje).subtexto,
        contains('e mais 1 parada'),
      );
    });

    test('sem reservas nenhumas, a pergunta não se faz', () {
      // Sem uma reserva sequer, a frota inteira está «parada desde sempre» — o
      // número diria alguma coisa sobre a app estar vazia, não sobre o negócio.
      final estado = OperationsState(machines: [maquina('m1', 'Mini')]);

      expect(haFrotaParaVigiar(estado), isFalse);
      expect(kpiMaquinaParada(estado, hoje).nivel, NivelSemaforo.aguarda);
    });
  });
}

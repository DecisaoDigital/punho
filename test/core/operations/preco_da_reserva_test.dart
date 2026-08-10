import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/preco_da_reserva.dart';
import 'package:punho/domain/models/operations.dart';

/// **O valor previsto vem com a conta feita.**
///
/// O preço/dia é perguntado no cadastro da máquina e não servia para nada: o
/// campo "Valor previsto" da reserva nascia em branco. O César, a 10 de Agosto
/// de 2026: «se o valor diário de aluguer foi perguntado e preenchido, porque é
/// que na reserva aparece Valor previsto?? ainda por cima em branco».
///
/// A conta tem uma armadilha: o formulário de reserva trabalha em **meios
/// dias** — a manhã das 00:00 às 12:00, a tarde das 12:00 às 00:00 do dia
/// seguinte — e `Duration.inDays` arredonda doze horas para zero. Meia manhã de
/// escavadora não custa nada nenhum.
void main() {
  Machine maquina({int? precoDia}) => Machine(
    id: 'm1',
    name: 'Mini escavadora',
    reference: 'ME-01',
    category: 'Escavação',
    status: MachineStatus.available,
    dailyRateCents: precoDia,
  );

  final dia = DateTime(2026, 8, 12);

  group('diasDeAluguer', () {
    test('a manhã é meio dia', () {
      expect(diasDeAluguer(dia, DateTime(2026, 8, 12, 12)), 0.5);
    });

    test('a tarde também é meio dia', () {
      expect(
        diasDeAluguer(DateTime(2026, 8, 12, 12), DateTime(2026, 8, 13)),
        0.5,
      );
    });

    test('o dia inteiro é um dia', () {
      expect(diasDeAluguer(dia, DateTime(2026, 8, 13)), 1);
    });

    test('três dias seguidos são três', () {
      expect(diasDeAluguer(dia, DateTime(2026, 8, 15)), 3);
    });

    test('um período invertido não é uma dívida', () {
      expect(diasDeAluguer(DateTime(2026, 8, 15), dia), 0);
    });
  });

  group('valorPrevistoDaTabela', () {
    test('preço/dia × dias', () {
      expect(
        valorPrevistoDaTabela(
          [maquina(precoDia: 25000)],
          dia,
          DateTime(2026, 8, 15),
        ),
        75000,
      );
    });

    test('meio dia custa metade, e não zero', () {
      expect(
        valorPrevistoDaTabela(
          [maquina(precoDia: 25000)],
          dia,
          DateTime(2026, 8, 12, 12),
        ),
        12500,
      );
    });

    test('várias máquinas somam-se', () {
      expect(
        valorPrevistoDaTabela(
          [maquina(precoDia: 25000), maquina(precoDia: 20000)],
          dia,
          DateTime(2026, 8, 13),
        ),
        45000,
      );
    });

    /// **Sem tabela é `null`, nunca zero.** Um zero passaria por um preço
    /// combinado — «este trabalho é de borla» — e ficava gravado como tal.
    test('máquina sem preço/dia devolve null', () {
      expect(
        valorPrevistoDaTabela([maquina()], dia, DateTime(2026, 8, 13)),
        isNull,
      );
    });

    test('basta uma máquina sem preço para o total deixar de valer', () {
      expect(
        valorPrevistoDaTabela(
          [maquina(precoDia: 25000), maquina()],
          dia,
          DateTime(2026, 8, 13),
        ),
        isNull,
        reason: 'somar só as que têm preço diria menos do que a verdade',
      );
    });

    test('sem máquinas não há conta a fazer', () {
      expect(valorPrevistoDaTabela([], dia, DateTime(2026, 8, 13)), isNull);
    });
  });

  group('textoDoValorPrevisto', () {
    test('sai como o campo o quer: ponto decimal', () {
      expect(
        textoDoValorPrevisto(
          [maquina(precoDia: 25000)],
          dia,
          DateTime(2026, 8, 13),
        ),
        '250.00',
      );
    });

    test('sem tabela deixa o campo vazio', () {
      expect(textoDoValorPrevisto([maquina()], dia, DateTime(2026, 8, 13)), '');
    });
  });
}

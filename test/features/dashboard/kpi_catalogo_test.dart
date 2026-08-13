import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/domain/models/operations.dart';
import 'package:punho/features/dashboard/presentation/kpi_catalogo.dart';
import 'package:punho/features/dashboard/presentation/widgets/celula_semaforo.dart';

/// O catálogo é a bancada: uma fonte única para as doze células, cada uma capaz
/// de dizer em que ponto de verdade está. Estes testes guardam três coisas — que
/// estão lá todas, que nenhuma parte a construir a célula, e que o estado de
/// verdade lê o que é suposto ler.
void main() {
  final now = DateTime(2026, 8, 9);

  OperationsState comReserva() => OperationsState(
    onboarded: true,
    companyName: 'Alugueres Norte',
    bookings: [
      Booking(
        id: 'b1',
        customerId: 'c1',
        machineIds: const ['m1'],
        startsAt: DateTime(2026, 8, 12),
        endsAt: DateTime(2026, 8, 14),
        status: BookingStatus.confirmed,
        expectedValueCents: 50000,
      ),
    ],
  );

  const vazio = OperationsState(
    onboarded: true,
    companyName: 'Alugueres Norte',
  );

  group('o catálogo está inteiro', () {
    test('tem os trinta e três KPIs, com ids únicos e títulos', () {
      // Doze do painel antigo + a Caixa e a Tendência do mês (nascidas na
      // bancada) + os onze de 10 de Agosto de 2026: os sete que a auditoria
      // (`docs/AUDITORIA_KPIS_EMPRESA.md`) dava como não cobertos, as duas que
      // se perderam quando o painel deixou de ser slides, e as duas da
      // futurologia. Mais os três mestres da cadeia (13 Ago 2026): as Vendas do
      // mês, o Lucro do mês e a Estrutura, que o diagrama do plano de KPIs põe
      // no topo e que não existiam — havia contas de caixa, não havia vendas
      // nem lucro. E o break even do mês (13 Ago 2026), que é o par do Lucro:
      // a meio do mês a estrutura já entrou toda e o lucro parece mau — o que
      // diz se o mês virou é quanto falta vender para ele se pagar. E o lucro
      // do mês anterior, que é o único mês fechado — a régua com que se lê o
      // mês que está a acontecer.
      //
      // E os três de 13 de Agosto de 2026, a fechar buracos que o catálogo
      // tinha: o dinheiro que já devia ter entrado («Em atraso»), o que ainda
      // tem de sair («Contas a pagar») e o activo que não está a render
      // («Máquina parada»). Os dois primeiros são o espaço entre vender e
      // receber, onde vive a tesouraria de uma casa pequena; o terceiro é o
      // nome que faltava à percentagem de utilização.
      expect(catalogoKpis, hasLength(33));
      expect(kpiPorId('caixa'), isNotNull);
      expect(kpiPorId('tendencia-mes'), isNotNull);

      final ids = catalogoKpis.map((k) => k.id).toSet();
      expect(ids, hasLength(33), reason: 'ids têm de ser únicos');

      for (final k in catalogoKpis) {
        expect(k.id, isNotEmpty);
        expect(k.titulo, isNotEmpty);
        expect(k.desbloqueio, isNotEmpty);
      }
    });

    test('kpiPorId encontra e falha em silêncio', () {
      expect(kpiPorId('ticket-medio-mes'), isNotNull);
      expect(kpiPorId('nao-existe'), isNull);
    });

    test('nenhuma célula parte, com dados ou sem eles', () {
      for (final k in catalogoKpis) {
        expect(
          () => k.celula(vazio, now),
          returnsNormally,
          reason: '${k.id} partiu com estado vazio',
        );
        expect(
          () => k.celula(comReserva(), now),
          returnsNormally,
          reason: '${k.id} partiu com uma reserva',
        );
      }
    });
  });

  group('o estado de verdade', () {
    test('sem fonte cheia é "por definir"', () {
      // Empresa vazia: as entradas não têm de onde vir → a célula aguarda.
      final entradas = kpiPorId('entradas-mes')!;

      expect(entradas.celula(vazio, now).nivel, NivelSemaforo.aguarda);
      expect(entradas.fonteCheia(vazio, now), isFalse);
      expect(entradas.estado(vazio, now), EstadoVerdade.porDefinir);
    });

    test('fonte cheia + conta verificada é "pronto"', () {
      // O ticket médio já passou pelo nosso crivo (contaVerificada: true); com
      // uma reserva com valor no mês, a fonte enche → pode subir ao painel.
      final ticket = kpiPorId('ticket-medio-mes')!;
      expect(ticket.contaVerificada, isTrue);

      expect(ticket.fonteCheia(comReserva(), now), isTrue);
      expect(ticket.estado(comReserva(), now), EstadoVerdade.pronto);
    });

    test('fonte cheia mas conta por verificar é "por verificar"', () {
      // A recomendação do dia não passou pelo crivo, e é a única com fonte que
      // enche que continua por verificar: não é uma conta, é prosa tirada dos
      // sinais dos outros KPIs. Enquanto esses não estiverem todos assinados,
      // esta não pode ser.
      final recomendacao = kpiPorId('recomendacao-dia')!;
      expect(recomendacao.contaVerificada, isFalse);

      expect(recomendacao.fonteCheia(comReserva(), now), isTrue);
      expect(
        recomendacao.estado(comReserva(), now),
        EstadoVerdade.porVerificar,
      );
    });
  });
}

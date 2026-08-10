import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:punho/core/operations/operations_controller.dart';
import 'package:punho/data/repositories/operation_repository.dart';
import 'package:punho/domain/models/historical_month.dart';
import 'package:punho/features/contabilista/contabilista_providers.dart';
import 'package:punho/features/contabilista/data/contabilista_service.dart';
import 'package:punho/features/contabilista/domain/contabilista.dart';
import 'package:punho/features/contabilista/historico_do_contabilista_provider.dart';

/// A ponte que leva os meses de faturação do contabilista ao `historicalMonths`
/// que os KPIs leem — sem ela a tendência do painel fica cega no passado que o
/// contabilista já respondeu.
const _empresa = OnboardingData(
  ownerName: 'Alfredo Nogueira',
  companyName: 'Aluguer Nogueira',
  legalForm: 'Empresário em Nome Individual',
  hasFleet: false,
  collaborators: 0,
  declaredVehicleCount: 0,
  totalMachinesDeclared: 6,
  insertMachinesNow: false,
  companyTaxId: '248193066',
  companyPhone: '912 000 000',
  fixedMonthlyCostsCents: 180000,
);

RespostaContabilista _fat(
  int ano,
  int mes,
  int cents, {
  OrigemResposta origem = OrigemResposta.contabilista,
}) => RespostaContabilista(
  rubrica: 'facturacao',
  mes: DateTime(ano, mes),
  valorCentavos: cents,
  origem: origem,
);

({ProviderContainer container, OperationsController notifier}) _cenario(
  List<RespostaContabilista> respostas, {
  bool onboarded = true,
  bool rebenta = false,
  List<HistoricalMonth> historicoInicial = const [],
}) {
  final repo = LocalDemoOperationRepository();
  if (onboarded) repo.saveOnboarding(_empresa);
  for (final h in historicoInicial) {
    repo.saveHistoricalMonth(h);
  }
  final container = ProviderContainer(
    overrides: [
      operationRepositoryProvider.overrideWithValue(repo),
      contabilistaServiceProvider.overrideWithValue(
        _ContabilistaFalso(respostas, rebenta: rebenta),
      ),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, notifier: container.read(operationsProvider.notifier));
}

void main() {
  group('Ponte contabilista → histórico', () {
    test('materializa cada mês de faturação como recebido do mês', () async {
      final c = _cenario([
        _fat(2026, 5, 320000),
        _fat(2026, 6, 450000),
        _fat(2026, 7, 510000),
      ]);

      final aplicados = await c.container.read(
        historicoDoContabilistaProvider.future,
      );

      expect(aplicados, 3);
      final estado = c.container.read(operationsProvider);
      expect(estado.historicalMonth(2026, 7)?.revenueReceivedCents, 510000);
      expect(estado.historicalMonth(2026, 6)?.revenueReceivedCents, 450000);
      expect(estado.historicalMonth(2026, 5)?.revenueReceivedCents, 320000);
    });

    test('a resposta do gestor ganha à do contabilista no mesmo mês', () async {
      final c = _cenario([
        _fat(2026, 7, 510000),
        _fat(2026, 7, 600000, origem: OrigemResposta.gestor),
      ]);

      await c.container.read(historicoDoContabilistaProvider.future);

      expect(
        c.container.read(operationsProvider).historicalMonth(2026, 7)?.revenueReceivedCents,
        600000,
        reason: 'o que o gestor escreveu por cima é que vale',
      );
    });

    test('não apaga outros campos de um mês que já existe', () async {
      final c = _cenario(
        [_fat(2026, 7, 510000)],
        historicoInicial: const [
          HistoricalMonth(year: 2026, month: 7, paidExpensesCents: 88000),
        ],
      );

      await c.container.read(historicoDoContabilistaProvider.future);

      final julho = c.container.read(operationsProvider).historicalMonth(2026, 7);
      expect(julho?.revenueReceivedCents, 510000, reason: 'a faturação entra');
      expect(julho?.paidExpensesCents, 88000, reason: 'a despesa que lá estava fica');
    });

    test('respostas sem mês (só o total do ano) ficam de fora', () async {
      final c = _cenario([
        const RespostaContabilista(
          rubrica: 'facturacao',
          ano: 2025,
          valorCentavos: 5000000,
          origem: OrigemResposta.contabilista,
        ),
      ]);

      final aplicados = await c.container.read(historicoDoContabilistaProvider.future);

      expect(aplicados, 0);
    });

    test('empresa ainda em onboarding não mexe no histórico', () async {
      final c = _cenario([_fat(2026, 7, 510000)], onboarded: false);

      final aplicados = await c.container.read(historicoDoContabilistaProvider.future);

      expect(aplicados, 0);
    });

    test('sem rede devolve zero em silêncio, não rebenta', () async {
      final c = _cenario([_fat(2026, 7, 510000)], rebenta: true);

      final aplicados = await c.container.read(historicoDoContabilistaProvider.future);

      expect(aplicados, 0);
      expect(c.container.read(operationsProvider).historicalMonth(2026, 7), isNull);
    });
  });
}

class _ContabilistaFalso implements ContabilistaService {
  _ContabilistaFalso(this._respostas, {this.rebenta = false});

  final List<RespostaContabilista> _respostas;
  final bool rebenta;

  @override
  Future<List<RespostaContabilista>> respostasDe(String rubrica) async {
    if (rebenta) throw StateError('sem rede');
    return _respostas.where((r) => r.rubrica == rubrica).toList();
  }

  @override
  Future<List<RubricaContabilista>> catalogo() async => const [];
  @override
  Future<List<ConviteContabilista>> convites() async => const [];
  @override
  Future<List<LacunaContabilista>> lacunas() async => const [];
  @override
  Future<List<MensagemContabilista>> mensagens() async => const [];
  @override
  Future<void> marcarMensagensLidas(List<String> ids) async {}
  @override
  Future<ConviteCriado> criarConvite({
    String? nome,
    String? email,
    int anos = 5,
  }) async => throw UnimplementedError();
  @override
  Future<void> revogarConvite(String conviteId) async {}
  @override
  Future<void> guardar({
    required String rubrica,
    DateTime? mes,
    int? ano,
    int? valorCentavos,
    String? valorTexto,
  }) async {}
}

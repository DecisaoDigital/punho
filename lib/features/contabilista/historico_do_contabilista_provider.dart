import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/operations/operations_controller.dart';
import '../../domain/models/historical_month.dart';
import 'contabilista_providers.dart';
import 'domain/contabilista.dart';

/// A rubrica de faturação no catálogo (`punho_rubricas_contabilista`). É o slug
/// estável de "quanto entrou" — a mesma coluna que o portal do contabilista
/// preenche mês a mês.
const _rubricaFaturacao = 'facturacao';

/// **Ponte contabilista → histórico dos KPIs.**
///
/// O contabilista preenche uma grelha rica de meses em
/// `punho_respostas_contabilista`, mas a tendência do painel só sabe ler
/// [OperationsState.historicalMonths]. Sem esta ponte, uma empresa que confia o
/// passado ao contabilista lê "sem histórico para comparar" para sempre — cega
/// precisamente nos meses que ele já tinha respondido, que são o passado todo de
/// quem abriu há pouco.
///
/// A faturação declarada entra como o **recebido** do mês: é a mesma convenção
/// que o onboarding já usa ao distribuir a faturação do ano passado, e é o que a
/// `tesourariaDoMes` compara. Quando o gestor escreveu por cima do contabilista,
/// vale a resposta dele — a mesma regra que o ecrã do histórico mostra. Os
/// outros campos de um mês que já exista ficam como estão: a ponte só toca no
/// que sabe, não apaga uma despesa ou um lead vindos de outro lado.
///
/// Corre uma vez por sessão, como o `fichaRecebidaProvider`, e é observado na
/// shell do gestor. Sem rede ou sem contabilista devolve zero em silêncio — não
/// haver o que trazer não é uma falha.
final historicoDoContabilistaProvider = FutureProvider<int>((ref) async {
  if (!ref.read(operationsProvider).onboarded) return 0;

  final List<RespostaContabilista> respostas;
  try {
    respostas = await ref
        .read(contabilistaServiceProvider)
        .respostasDe(_rubricaFaturacao);
  } catch (_) {
    return 0;
  }

  // Um valor por mês. Quando o gestor respondeu por cima do contabilista, é o
  // dele que fica; senão, o primeiro que aparecer.
  final porMes = <String, RespostaContabilista>{};
  for (final r in respostas) {
    final mes = r.mes;
    if (mes == null || r.valorCentavos == null) continue;
    final chave = '${mes.year}-${mes.month}';
    final atual = porMes[chave];
    if (atual == null || r.origem == OrigemResposta.gestor) {
      porMes[chave] = r;
    }
  }

  final operacoes = ref.read(operationsProvider.notifier);
  var aplicados = 0;
  for (final r in porMes.values) {
    final mes = r.mes!;
    final valor = r.valorCentavos!;
    final existente = ref
        .read(operationsProvider)
        .historicalMonth(mes.year, mes.month);
    // Já lá está com este valor — não vale um `saveHistoricalMonth` só para
    // reescrever o mesmo número e disparar uma sincronização à toa.
    if (existente?.revenueReceivedCents == valor) continue;
    operacoes.saveHistoricalMonth(
      HistoricalMonth(
        year: mes.year,
        month: mes.month,
        revenueReceivedCents: valor,
        paidExpensesCents: existente?.paidExpensesCents,
        advertisingSpendCents: existente?.advertisingSpendCents,
        leadsReceived: existente?.leadsReceived,
        convertedLeads: existente?.convertedLeads,
        maintenanceCents: existente?.maintenanceCents,
      ),
    );
    aplicados++;
  }
  return aplicados;
});

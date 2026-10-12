// Copyright (c) 2025-2026 Decisão Digital / César Mendes. Todos os direitos reservados.
// Software proprietário e confidencial. Proibida a reprodução, adaptação, distribuição,
// engenharia inversa (salvo o permitido por lei imperativa) e a utilização deste código,
// da sua lógica, interface, textos e ícones para treino, afinação ou geração de obras
// derivadas por sistemas de inteligência artificial ou outros, sem autorização escrita.
// All rights reserved. Proprietary: no reproduction, reverse engineering, or use for AI
// training or to generate derivative works without written permission.
// SPDX-License-Identifier: LicenseRef-Proprietary

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_destination.dart';
import '../../../core/navigation/navigation_controller.dart';
import '../../../core/operations/operations_controller.dart';
import '../../kpis/presentation/cadeia_do_kpi_page.dart';
import 'kpi_catalogo.dart';
import 'kpi_explicacoes.dart';
import 'widgets/celula_semaforo.dart';
import 'widgets/grelha_com_graficos.dart';
import 'widgets/grelha_de_kpis.dart';

/// **Um ecrã do painel: até quatro KPIs, na ordem em que o gestor os pôs.**
///
/// Antes eram três slides escritos à mão — Síntese, Operacional, Procura —,
/// cada um com as suas quatro células fixas. Diziam a mesma coisa a todas as
/// empresas, e à maior parte delas diziam "aguarda" quatro vezes. Aqui a
/// página não sabe que KPIs são: recebe ids, vai buscá-los ao [catalogoKpis] e
/// arruma-os na mesma grelha de sempre.
///
/// Existe como widget próprio, e público, para os testes poderem afirmar sobre
/// as células sem terem de montar o painel inteiro e navegar até à página
/// certa.
class PaginaDoPainel extends ConsumerWidget {
  const PaginaDoPainel({super.key, required this.ids, this.agora});

  /// Os ids do catálogo a mostrar, por ordem. Mais de quatro não cabem na
  /// grelha — quem pagina é o painel.
  final List<String> ids;

  /// Injectável para os testes não dependerem do dia em que correm.
  final DateTime? agora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(operationsProvider);
    final now = agora ?? DateTime.now();
    // **Os gráficos são KPIs como os outros** (escolhem-se na lista dos KPIs):
    // os cartões de número vão em cima, iguais entre si, e os gráficos por
    // baixo, também iguais. Sem gráficos, a grelha 2×2 de sempre.
    final kpis = [
      for (final id in ids)
        if (kpiPorId(id) case final kpi?) kpi,
    ];
    final graficos = [
      for (final kpi in kpis)
        if (kpi.grafico case final desenhar?) desenhar(estado, now),
    ];
    final celulas = [
      for (final kpi in kpis)
        if (kpi.grafico == null)
          AbrirDestinoDoKpi(
            destino: kpi.destino,
            // **Um KPI com filhos abre a cadeia; uma folha vai direita à
            // acção.** É a regra inteira do toque no painel.
            //
            // Só se pode descer onde há alguma coisa por baixo: as «Entregas
            // hoje» não têm explicação nenhuma para dar, e abrir uma página
            // que só repetisse a célula era um toque a mais para chegar ao
            // mesmo sítio. Já o Lucro tem — e mandar quem lhe toca para as
            // Finanças, sem lhe dizer primeiro o que se mexeu, é despachá-lo
            // para o sítio certo com a pergunta errada na cabeça.
            cadeia: filhosDe(kpi.id).isEmpty && !temGrafico(kpi.id)
                ? null
                : kpi.id,
            agora: agora,
            child: _comNotas(
              kpi,
              estado,
              now,
              detalhado: graficos.isEmpty && kpis.length <= 4,
            ),
          ),
    ];
    if (graficos.isNotEmpty) {
      return GrelhaComGraficos(celulas: celulas, graficos: graficos);
    }
    return GrelhaDeKpis(celulas: celulas);
  }
}

/// Torna uma célula tocável: ou desce a cadeia, ou vai ao destino operacional.
///
/// É o padrão editorial da Decisão 7 — cada leitura tem de ter caminho para o
/// sítio onde se age sobre ela. Sem [cadeia] nem [destino], devolve a célula tal
/// como está: um `InkWell` que não vai a lado nenhum é uma promessa por cumprir.
///
/// [cadeia] ganha ao [destino] quando existe. Quem toca num número mau quer
/// saber porquê antes de saber onde — e o ecrã da cadeia acaba com o botão para
/// o destino, portanto não se perde caminho nenhum, ganha-se uma explicação.
class AbrirDestinoDoKpi extends ConsumerWidget {
  const AbrirDestinoDoKpi({
    super.key,
    required this.destino,
    required this.child,
    this.cadeia,
    this.agora,
  });

  final AppDestination? destino;
  final Widget child;

  /// O id do KPI cuja cadeia se abre ao toque. `null` numa folha.
  final String? cadeia;

  /// Injectável para os testes não dependerem do dia em que correm.
  final DateTime? agora;

  static final _canto = BorderRadius.circular(12);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cadeia = this.cadeia;
    final destino = this.destino;
    if (cadeia == null && destino == null) return child;
    return Material(
      color: Colors.transparent,
      borderRadius: _canto,
      child: InkWell(
        borderRadius: _canto,
        onTap: cadeia != null
            ? () => CadeiaDoKpiPage.abrir(context, kpiId: cadeia, agora: agora)
            : () => ref.read(navigationProvider.notifier).goTo(destino!),
        child: child,
      ),
    );
  }
}

/// A célula do KPI e, no Windows, as notas que o detalhe já mostra: o que
/// compõe o número (filhos da cadeia), como se chega a ele e a apreciação.
/// Tudo vem de dados já calculados — nada é inventado.
Widget _comNotas(
  KpiDefinicao kpi,
  OperationsState estado,
  DateTime now, {
  bool detalhado = false,
}) {
  final celula = kpi.celula(estado, now);
  if (!Platform.isWindows || celula.nivel == NivelSemaforo.aguarda) {
    return celula;
  }
  final notas = <String>[];
  final filhos = [
    for (final f in filhosDe(kpi.id))
      if (f.grafico == null &&
          f.celula(estado, now).nivel != NivelSemaforo.aguarda)
        f,
  ];
  if (filhos.isNotEmpty) {
    notas.add(
      'Composto por: ${[for (final f in filhos) _resumo(f.celula(estado, now))].join(' · ')}',
    );
  }
  final e = explicacaoDe(kpi.id);
  if (e != null) {
    notas.add(
      'Como se chega: ${detalhado ? e.comoSeChega : _primeiraFrase(e.comoSeChega)}',
    );
    final apreciacao = switch (celula.nivel) {
      NivelSemaforo.verde =>
        detalhado ? e.parabens : _primeiraFrase(e.parabens),
      NivelSemaforo.laranja || NivelSemaforo.vermelho =>
        e.paraMelhorar.isEmpty ? null : e.paraMelhorar.first,
      _ => null,
    };
    if (apreciacao != null) notas.add(apreciacao);
    // Com poucos KPIs no ecrã há altura para as restantes dicas.
    if (detalhado &&
        (celula.nivel == NivelSemaforo.laranja ||
            celula.nivel == NivelSemaforo.vermelho)) {
      notas.addAll(e.paraMelhorar.skip(1));
    }
  }
  return notas.isEmpty ? celula : celula.comNotas(notas);
}

String _resumo(CelulaSemaforo c) {
  final v = c.valor;
  if (v == null) return c.rotulo;
  final un = c.unidade?.split(' ').first;
  return '${c.rotulo} $v${un == null ? '' : ' $un'}';
}

String _primeiraFrase(String t) {
  final i = t.indexOf(RegExp(r'[.!?](\s|$)'));
  return i < 0 ? t : t.substring(0, i + 1);
}

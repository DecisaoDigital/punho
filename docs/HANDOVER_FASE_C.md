# Handover — Fase C (consolidação)

**Data:** 10 de Agosto de 2026
**Estado à entrada:** `origin/main` em `8f51e7d`; três sessões de trabalho sem
um único commit; duas delas misturadas na mesma árvore de `~/punho`.
**Estado à saída:** `main` em `v0.3.5`, árvore limpa, 1090 testes verdes.

Este ficheiro é também o exemplo da regra nova do `AGENTS.md` («Uma sessão por
fase»). Se a Fase 3 arrancar bem só com o que está aqui escrito, a regra
funciona; se não, é este ficheiro que tem de melhorar.

---

## O que fez

A Fase C não escreveu lógica de negócio nenhuma. Arrumou o que já existia em
disco e não estava em lado nenhum.

### Linha B — backend (worktree `~/punho-backend`, removido a 14/8/2026)

Cinco commits que já existiam, empurrados e integrados em `main` por merge
commit (`4b761c5`). Nenhum ficheiro Dart:

- RLS fechado nas sete tabelas partilhadas com o WashInvoice;
- `UPDATE`/`DELETE` inertes retirados de `pings` e `aceites_termos`;
- identidade derivada do token em `registar-terminal` e `validar-licenca`,
  com rate limit no registo de terminais;
- 58 migrations renomeadas para reconciliar o repositório com o registo da
  produção (ver `docs/RECONCILIACAO_MIGRATIONS_2026-08-10.md`);
- smoke de isolamento entre empresas ressuscitado e alargado ao POS.

### Linha A — hardening (4 commits)

| Commit | Assunto |
|---|---|
| `ff95efd` | uma recusa do servidor deixa de trancar a fila de sincronização |
| `b2cc886` | conflito de reserva (23P01) deixa de desaparecer em silêncio |
| `c70a807` | o operador cobra, o operador não altera preços (Fase 2) |
| `13ec1cb` | «já está na lista» passa a funcionar; acesso recusado volta a abrir |

### Painel (2 commits)

| Commit | Assunto |
|---|---|
| `f7290f4` | o painel nasce vazio e monta-se na bancada — catálogo de KPIs, arranjo do gestor, os três slides fixos removidos |
| `9180f45` | a tendência do mês passa a ver o que o contabilista já declarou |

### Terceiro trabalho, que ninguém tinha anunciado (2 commits)

| Commit | Assunto |
|---|---|
| `dd59f9e` | três regras de negócio fixadas a 9 de Agosto: reserva agendada já é agenda ocupada, ticket médio por cliente distinto, entrega 09:00 / recolha 18:00 |
| `2eac3bb` | doc do método de simulação de utilizador real |

### Regra de higiene

Secção «Uma sessão por fase» no `AGENTS.md`, mais este ficheiro.

---

## O que ficou por fazer

**Por decisão explícita, não por esquecimento:**

- **Nada foi publicado.** Sem APK, sem GitHub Release, sem
  `update-release-catalog.sh`, sem `INSERT` em `versoes_apps`. A tag `v0.3.5`
  é um ponto de retorno antes da Fase 3, não uma versão distribuída.
- **As migrations novas da Linha A não foram aplicadas à produção.**
  `20260810140000_punho_o_operador_cobra_nao_altera_precos.sql` e
  `20260810_punho_ficha_por_id_local_e_reabrir_acesso.sql` estão no
  repositório e por correr. **A Fase 3 tem de começar por decidir isto** —
  enquanto não forem aplicadas, o servidor continua a deixar um operador
  escrever o valor de uma reserva, e o botão «já está na lista» continua a
  responder `22P02`.
- **O fluxo à mão no telemóvel, nos dois perfis, não foi percorrido.** A regra
  que esta fase instalou não foi cumprida pela própria fase. É dívida
  assumida: a Fase C não escreveu lógica de negócio, mas integrou o trabalho
  de três sessões que escreveram, e ninguém conduziu a app depois disso.
  Já havia dívida deste tipo antes desta fase (o teste inteiro do zero, no
  Redmi físico, continua pendente).

**Por não ser desta fase:**

- Fase 1.1 e 1.3 do hardening de Agosto continuam por fazer — mexem na base
  de dados viva e esperam autorização.
- Os KPIs do painel fecham depois da Fase 3.

---

## O que descobriu pelo caminho

Esta é a parte que não estava no plano de ninguém.

1. **Não houve conflito nenhum entre as duas sessões.** O
   `operation_repository.dart` era o candidato óbvio — foi o ficheiro que o
   briefing marcou como risco. Os dez hunks são todos do painel
   (`ArranjoDoPainel`, `_painelPorSubir`, o instantâneo). A Linha A não lhe
   tocou. Só **dois** ficheiros foram mexidos por dois trabalhos diferentes,
   e em zonas disjuntas: `app_shell.dart` (badge de conflitos + ponte do
   contabilista) e `kpis.dart` (tesouraria + pulso/ticket). Ambos separados
   por hunk, sem uma única linha em disputa.

2. **Havia um terceiro trabalho na árvore.** O briefing falava de duas
   sessões. Havia três assuntos: as regras de negócio de 9 de Agosto
   (`dd59f9e`) não pertenciam nem à Linha A nem ao painel, e teriam sido
   committadas por engano dentro de um dos outros se ninguém tivesse olhado
   hunk a hunk. **Lição: o inventário de uma consolidação faz-se pelo diff,
   não pelo que as sessões dizem ter feito.**

3. **`git merge` recusa-se a correr com renomeações staged por cima de
   modificações não-staged.** O merge da Linha B falhou com «local changes
   would be overwritten» em três ficheiros que a Linha B nem toca — os testes
   dos slides, que estavam simultaneamente renomeados no índice e alterados
   no working tree. Não é conflito de conteúdo, é o `ort` a recusar mexer no
   índice nesse estado. **Contorno sem descartar nada:** fazer o merge commit
   num worktree limpo (`git worktree add -b … origin/main`) e trazê-lo para
   `main` com `git merge --ff-only`, que usa outro caminho de código e passa.

4. **`git apply --cached --recount` é a forma de partir um ficheiro por
   assunto sem sessão interactiva.** Escreve-se o patch só com os hunks que
   se quer, aplica-se ao índice, e o que sobra fica no working tree para o
   commit seguinte. O `--recount` dispensa acertar as contagens à mão.

5. **A contagem de testes não mede o que parece.** 1090 à entrada e 1090 à
   saída, com oito commits pelo meio — porque o número era já o total dos
   três trabalhos por committar. A Linha A isolada dá **1021**. Um número
   estável entre o antes e o depois de uma consolidação não prova que nada se
   partiu; prova que nada se perdeu. São coisas diferentes.

6. **`cartao_caixa.dart` e `cartao_tendencia.dart` estão órfãos.** Nenhum
   ficheiro de `lib/` os importa — só testes. O catálogo novo define os seus
   próprios `kpiCaixa` e `kpiTendencia` lá dentro. São widgets a caminho de
   serem código morto, mantidos vivos por testes que testam apenas eles.
   Vale a pena decidir isto na Fase 3: ou voltam ao ecrã, ou saem com os
   testes.

---

## Como arrancar a Fase 3

```bash
cd ~/punho
git log --oneline 8f51e7d..v0.3.5     # tudo o que a Fase C integrou
git status                            # tem de estar limpo
```

Primeira decisão da sessão: aplicar (ou não) as duas migrations pendentes da
Linha A. Sem isso, metade da Fase 2 do hardening está escrita e não está a
proteger nada.

Antes de fechar a Fase 3: percorrer o fluxo à mão no Redmi, gestor e operador,
e escrever `docs/HANDOVER_FASE_3.md`.

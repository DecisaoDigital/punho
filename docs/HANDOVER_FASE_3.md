# Handover — Fase 3, um só motor de sincronização

**Data:** 10 de Agosto de 2026
**Branch:** `fase3/um-so-sync` (empurrado)
**Estado:** os sete passos estão feitos. **Falta a prova nos dois telemóveis** —
a única que conta, e a que precisa do César. Ver o fim deste ficheiro.

`flutter analyze` limpo, **1115 testes passam**, zero vermelhos.

O parcial (`docs/HANDOVER_FASE_3_PARCIAL.md`) continua a valer para o que este
não repete: as contagens de produção antes/depois das migrations e o que se
descobriu nos passos 1 e 2.

---

## O problema, numa frase

Três canais de sincronização e nenhum dono declarado: dois deles julgavam-se
donos das mesmas entidades, e o mais lento ganhava.

A 4 de Agosto de 2026, num Redmi: fechar um trabalho gravava, subia à fila de
operações e chegava ao servidor — está lá, com o id daquele telemóvel. Segundos
depois estava outra vez «em curso». O canal do instantâneo, parado na revisão 1,
tinha escrito por cima com o estado antigo. Sem erro, sem aviso.

## Os três canais, como ficaram

| Canal | O quê | Quem ganha | Onde |
|---|---|---|---|
| operações | máquinas, clientes, leads, reservas, despesas, recebimentos, colaboradores, veículos | ordem do servidor (`seq`) | `SincronizacaoOperacionalPorOperacoes` |
| ficha da empresa | onboarding, custos fixos, histórico mensal | o servidor: revisão diferente, o local cede | `SincronizacaoFichaEmpresa` |
| painel | o arranjo do painel do gestor | o carimbo mais recente de quem arrumou | `SincronizacaoDoPainel` |

---

## Os sete passos

| # | O quê | Onde ficou |
|---|---|---|
| 1 | as entidades saem do payload que sobe | `_payloadLocal()` (disco) vs `_payloadDaFicha()` (servidor) |
| 2 | o painel ganha canal próprio | `sincronizacao_do_painel.dart`, tabela `punho_painel` |
| 3 | o servidor deixa de projectar entidades a partir da ficha | migrations `20260810151000` e `152000`, aplicadas |
| 4 | a app deixa de as importar de lá | `apenasDadosDaEmpresa` em `_applyData` |
| 5 | os nomes passam a dizer qual é qual | `SincronizacaoFichaEmpresa`, `SincronizacaoOperacionalPorOperacoes`, `exportarFichaDaEmpresa` |
| 6 | o teste de fronteira | `test/core/sync/fronteira_dos_canais_test.dart` |
| 7 | a perda silenciosa | `fichas_postas_de_lado.dart` + aba Estado da Empresa |

Commits: `ea3fa21` (servidor), `c963c03` (app, WIP), `7df5604` (painel),
`db50524` (nomes), `71dc8ce` (fronteira), e o do passo 7.

---

## Passo 6 — a fronteira

`test/core/sync/fronteira_dos_canais_test.dart`, 7 testes em três grupos:

- **o que sobe** — a ficha leva `onboarding` e `historicalMonths` e mais nenhuma
  chave; um telemóvel com uma de cada uma das oito entidades sobe exactamente a
  mesma ficha (a marca `FRONTEIRA` não aparece em lado nenhum do payload);
- **o que desce** — uma ficha do servidor que traga as oito listas a contradizer
  o aparelho não substitui nenhuma. O payload é válido e completo de propósito:
  o corte tem de estar na decisão de não o ler, não num erro de leitura;
- **o cruzamento** — um fluxo da ficha não regista operação nenhuma, com a sonda
  inversa a provar que o `aoRegistarOperacao` dispara.

A lista das chaves permitidas vive no ficheiro de teste. Ir buscá-la ao próprio
método era escrever um teste que concorda sempre com o que lá estiver.

**Contraprova feita:** com `'machines'` de volta ao `_payloadDaFicha` e o
`if (apenasDadosDaEmpresa) return;` arrombado, falham 4 dos 7.

---

## Passo 7 — a perda silenciosa

### O defeito

No ramo em que a revisão remota difere, `SincronizacaoFichaEmpresa` importava a
ficha do servidor por cima da local e punha `hasPendingRemoteChanges` a `false`.
Se o gestor tinha escrito custos fixos naquele telemóvel sem rede, aquilo
desaparecia: não estava no servidor, não estava no telemóvel, e não havia aviso
nenhum. A app dava a sincronização por boa. O teste
`o_servidor_manda_test.dart` **consagrava** isto — dava a perda por boa e não
perguntava para onde tinha ido o que o gestor escreveu.

### A correcção

**A regra fica.** Velho perde. A alternativa (parar e pedir revisão humana) já
tinha sido tentada e é pior: não há ninguém a intervir, e o aparelho ficava
indefinidamente a mostrar uma ficha que já não era a da empresa.

O que muda é o silêncio:

- **`lib/core/sync/fichas_postas_de_lado.dart`** (novo) — `FichaPostaDeLado`
  (quando, revisão local, revisão do servidor, **o payload inteiro**) e
  `RegistoDeFichasPostasDeLado`, no feitio da quarentena e do balde de
  conflitos: lista em `SharedPreferences`, tecto de 20, uma linha ilegível não
  tranca as outras. Mais o `fichasPostasDeLadoProvider`, que lê do disco e não
  do motor — com o Supabase desligado tem de continuar a aparecer.
- **`SincronizacaoFichaEmpresa.receberDoServidor`** (novo, `@visibleForTesting`)
  — captura o que ia subir **antes** de importar e persiste-o **depois**, só se
  a importação tiver corrido bem: uma ficha que não chegou a entrar não deitou
  nada fora. É este método que torna a decisão testável sem rede.
- **aba Estado da Empresa** — secção «Ficou por enviar», que só aparece quando
  aconteceu. Mostra a empresa, quantas rubricas de custos fixos e quanto somavam
  por mês, quantos meses de histórico, a data e as duas revisões. Mais um botão
  «Já reescrevi — limpar».
- **badge da Empresa** na barra lateral passa a somar conflitos + fichas postas
  de lado. Sem badge, some-se sem ninguém dar por ela — que é o defeito que se
  foi corrigir.

Guarda-se o payload inteiro e não só o resumo: o resumo serve para o gestor
perceber o que perdeu, o payload serve para se poder repor sem depender da
memória de ninguém.

### De caminho

O `_push` a seguir à importação era **código que nunca corria**: existia para o
painel poder subir na mesma passagem, e o painel saiu deste canal no passo 2. A
importação limpa sempre a marca de «por subir», portanto o `if` acima dele era
sempre verdadeiro. Caiu.

### Testes

- `test/core/sync/ficha_posta_de_lado_test.dart` (novo, 7) — durabilidade, ordem
  (a mais recente primeiro), o resumo em números, payload ilegível a dar cartão
  sem números, linha estragada no disco a não levar as outras, tecto de 20,
  limpar;
- `o_servidor_manda_test.dart` — o teste que consagrava a perda passa a exercer
  `receberDoServidor` e a exigir que a ficha descartada fique guardada com as
  duas revisões e o payload. Mais dois casos novos: **sem nada por subir não se
  guarda perda nenhuma** (um balde que enchesse a cada passagem ensinava o
  gestor a ignorá-lo) e **ficha ilegível: ninguém recebe e ninguém perde**.

**Contraprova feita:** removida a escrita no balde, o teste falha.

### O que ficou por cobrir

Não há teste de widget do cartão novo — como não há do cartão de conflitos, que
vive ao lado desde a Fase C. O `resumo` está coberto em unitário, incluindo o
payload ilegível. Quem for à Fase 5 (visibilidade) apanha os dois de uma vez.

---

## A prova que falta, e é a única que conta

**Dois telemóveis, gestor e operador.** O operador entrega uma máquina; o gestor
altera os custos fixos; **a reserva não volta atrás**. Screenshots dos dois
lados.

Nenhum teste unitário substitui isto — foi assim que a avaria de 4 de Agosto
passou despercebida. Enquanto não estiver feita, a Fase 3 **não vai para
`main`**.

Segunda cena, agora que há onde a ver: pôr o telemóvel do gestor em modo de voo,
escrever uma rubrica de custos fixos, gravar a ficha no outro aparelho, e voltar
a ligar a rede. **A aba Estado da Empresa tem de mostrar a rubrica que se
perdeu**, e o badge da Empresa tem de a contar.

---

## Pendentes herdados, por decidir

- migrations `20260810140000_punho_o_operador_cobra_nao_altera_precos.sql` e
  `20260810_punho_ficha_por_id_local_e_reabrir_acesso.sql` — da Fase C, ainda
  por aplicar;
- a projecção **não tem guarda de ordem** em canal nenhum, nem no das operações.
  Ali é menos grave (o carimbo é `feito_em`, o momento do facto, e não `now()`),
  mas uma operação que chegue muito atrasada continua a poder reescrever uma
  entidade mais recente. Fora do âmbito desta fase;
- as políticas com `roles = {public}` e o `punho_meu_estado_acesso` — ver
  `docs/HANDOVER_C3.md`.

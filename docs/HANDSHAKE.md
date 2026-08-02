# Handshake — aba nova, Punho

Lê só isto para começar. O detalhe está em `docs/HANDOVER_SESSAO_SEGUINTE.md`;
vai lá quando precisares, não antes.

**Onde estás:** `/home/cesar/punho`, dentro do i9 (`hostname` =
`home-lab-claude`). `flutter` está no PATH — corre directamente, **não uses
ssh**. Branch `main`, commits directos, `git add` por ficheiro, nunca `-A`.

**Estado:** limpo em `ee9b1be`. `flutter test` verde (593, 1 skipped),
`flutter analyze` com 8 avisos `info` pré-existentes — essa é a linha de base,
não tentes limpá-los.

---

## Aviso primeiro: pode haver trabalho de outros a meio

A sessão anterior deixou dois agentes a mexer no repo **sem commitar**. Corre
`git status` antes de tudo. Se houver alterações por commitar, são deles:
`flutter analyze` e `flutter test`, e commita por ficheiro. Não desfaças.

Ficheiros que eles têm entre mãos: `operational_pages.dart`,
`finance_pages.dart`, `workforce_pages.dart`, `operations_controller.dart`,
`operation_repository.dart`, `lib/domain/models/operations.dart`.

---

## Três regras do Cesar. Sem elas vais desfazer trabalho de propósito feito

1. **A app começa vazia.** O onboarding não cria registos. Quem declara quinze
   máquinas fica sem nenhuma; a app só lembra o que falta. As fichas
   placeholder foram removidas de propósito, campo `placeholder` incluído, sem
   compatibilidade. Não as reponhas.
2. **Não se disfarçam falhas.** Palavras dele: «se parte, tem de partir com
   estrondo». Nada de `try/catch` decorativos, valores por omissão a mascarar
   erro, nem migrações silenciosas. Encontraste um sítio onde a app maquilha
   uma falha? **Aponta, não remendes.**
3. **Dados a fingir só para testes**, e por seed no servidor — nunca dentro da
   app.

E a decisão de produto fechada hoje: o **limite de colaboradores** é o que o
Cesar autoriza no Control (`punho_subscricoes.limite_colaboradores_ativos`). O
número do onboarding é só informativo. Exceder **não impede o cadastro** —
impede o **acesso** sem autorização expressa dele. Autorizar o sétimo significa
que o contrato subiu.

---

## Só ele decide (não faças, pede)

- Aplicar `supabase/seeds/mare_alta.sql` (ver `docs/DADOS_DE_TESTE.md`).
- A migração da notificação de instalação — SQL pronto na adenda de
  `docs/PLANO_PUSH_INSTALACAO_PUNHO.md`. **Escrever na base de dados de
  produção foi recusado pelo classificador de permissões**: não contornes,
  pede-lhe.
- Publicar (APK + GitHub Release + `versoes_apps`) — só a pedido explícito, e
  aí vai até ao fim.
- Apagar os cinco tokens FCM mortos em `admin_dispositivos`.

---

## O que fazer a seguir, por ordem

1. **Ver no aparelho.** Nada do que foi feito hoje foi visto a correr. À hora
   deste ficheiro não havia telemóvel ligado (`adb devices` vazio). O `adb`
   está em `~/android-sdk/platform-tools/adb` — caminho completo, o PATH do
   `.bashrc` não chega a shells não interactivos. Falta ele ligar o aparelho e
   aceitar a impressão digital RSA; em Xiaomi/MIUI precisa também de «Instalar
   via USB» e «Depuração USB (definições de segurança)».
   Prioridade a ver: onboarding a começar vazio, ficha do cliente a abrir e
   editar, os três diálogos convertidos (lead, reserva, marcação), painel de
   tesouraria a sair de "Por apurar", e o cabeçalho do login com `SafeArea`
   (era P0, corrigido às cegas na sessão anterior).
2. ~~Máquina alugada bloqueia todas as semanas seguintes~~ (achado 18) —
   **resolvido**: bloqueia só a data ocupada. Lógica em `3c7fe1c`, testes em
   `3db013b`.
3. **Control — menus do Punho.** Proposta em aberto, três peças, detalhe no
   handover. A peça pequena que o desbloqueia: RPC `punho_definir_limite` para
   editar o limite fora da criação da empresa.

---

## Duas coisas que valem mais do que parecem

**As tabelas por entidade estão vazias.** `punho_clientes`, `punho_maquinas` e
companhia têm zero linhas apesar de uso real. A fonte de verdade é o log
append-only `punho_operacoes` (sync por `seq`, Realtime pelo trigger
`punho_operacoes_avisar`), e é só de lá que o telemóvel puxa. Esclarecer isto
antes de construir seja o que for por cima daquelas tabelas.

**O bug do dinheiro.** `1.500,00 €` grava **zero**, calado, em oito sítios:
`(double.tryParse(texto.replaceAll(',', '.')) ?? 0)` dá `1.500.00`, que não é
número, e o `?? 0` inventa o zero. O ajudante correcto já existe —
`centsDeTexto` em `lib/core/format/campos.dart`. Os agentes em voo estavam a
tratar disto; confirma o que ficou feito antes de repetires.

---

## Custos

Ficheiros >500 linhas não se lêem inteiros no thread principal — delegar
(`operational_pages.dart` tem 3600+). Capturas de ecrã nunca com `Read` no
thread principal. O Cesar tem poucos tokens: bullets curtos, sem preâmbulos,
perguntas em vez de suposições.

---

## Empresa de teste

**Lavandaria Mare Alta** (`1a267759-…`), `cesarmendes78+punhoteste@gmail.com`
/ `MareAlta2026`. Supabase: projecto WashInvoice, `oefqbkhioncakojipqyx`.

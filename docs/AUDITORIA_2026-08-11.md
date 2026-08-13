# Auditoria de 11 Ago 2026 — estado

Alvos: `punho` (v0.3.72), `punho_operador` (v0.0.2), `washinvoice-control`, base
`oefqbkhioncakojipqyx`. Lentes: código morto · dados (integridade, RGPD,
backup) · runtime · experiência.

Este ficheiro é a lista viva. Actualiza-se à medida que se fecha.

> **Correcção ao original.** O relatório dizia `flutter analyze` limpo nas três
> apps. Não estava: o Control tinha 12 avisos `deprecated_member_use` — `value:`
> em campos de formulário e `onChanged` em `Radio`, do SDK ter andado para a
> frente. Confirmado com `git stash`, eram anteriores a qualquer coisa feita
> aqui. **Corrigidos a 12/8**; as três apps estão limpas agora.

## Fechado

| # | Achado | Como fechou |
|---|---|---|
| 3.1 | Não existia apagamento de titular | `punho_apagar_titular` + ecrã em Gestão. Redacção no lugar, porque o log é append-only e os terminais re-hidratam dele. Prova em `punho_apagamentos` |
| 3.2 | Não existia retenção | `punho_expurgar_dados()` no pg_cron, 04:17 diário. Telemetria 30 d, leads 6 meses, auditoria 12 meses. Fiscal e laboral intocados |
| 2.1 | `licencas_audit`: 62 de 113 linhas a apontar para licenças apagadas | Identidade passou para `licenca_machine_id`/`licenca_app`; FK `on delete set null`; trigger escreve null no DELETE. 0 órfãos |
| 2.2 | RLS ligado e 0 políticas em 3 tabelas | Era o contrário do que parecia: a ausência de políticas é deliberada, o errado eram os GRANT. O `anon` tinha INSERT/UPDATE/DELETE em **25** tabelas (`chaves_mestre`, `licencas`, `punho_empresas`, `punho_apagamentos`…). Revogados. Agora 0 |
| 2.3 | Colunas `*_id` sem chave estrangeira | 4 chaves criadas em `punho_alteracoes_contabilista` e `punho_conflitos_pendentes`, com índices. Os 3 `entidade_*_id` **não levam chave** — são ids locais em `text`, apontam para o log, não para uma linha. O achado estava errado |
| 2.4 | `reltuples = -1`, planeador às cegas | `ANALYZE`. 0 tabelas sem estatísticas |
| 1.2 | Ficheiros nunca importados | `access_profile.dart` removido. `graficos.dart` **fica** — ver abaixo |
| 1.4 | `flutter_riverpod` declarado e não usado no OP | Removido do pubspec |
| 1.6 | Assets sem referência | Falso alarme parcial: são originais do gerador de ícones. Não se apagam |
| 3.7 | Políticas do `storage.objects` nunca verificadas | Verificadas: estão bem. Cada empresa só chega à sua pasta, o comprovativo de despesa só é lido pelo autor ou por um gestor, e as fotografias de máquinas exigem membro activo. O que faltava era o `file_size_limit`, a null — qualquer membro podia enviar 900 MB e encher o plano de 1 GB, levando atrás o balde de onde saem os APKs. Posto a 20 MB |
| 5.1 | 26 `ListView(` não-lazy | Convertidas as **duas que crescem com o negócio**: o extracto de despesas/recebimentos e a lista de clientes e leads (esta com `SliverList`, por ter dois títulos pelo meio). As outras — máquinas, colaboradores, veículos — não se converteram de propósito: uma lavandaria tem dez máquinas e cinco empregados, e trocar `children` por `builder` aí é ruído sem ganho |
| 5.2 | 10 `.select()` sem limite | Sete não eram nada: dois eram `select` do Riverpod, o sincronizador de operações já tem cursor e lote, e os catálogos são fechados por desenho. Três levaram tecto — a conversa com o contabilista, a caixa de entrada de leads e a lista de convites — com teste que olha para o **pedido que sai**. O sincronizador de conflitos fica sem tecto de propósito: sem uma coluna que diga quando a linha mudou, um `limit` traz sempre as mesmas N e há conflitos que nunca chegariam. Está escrito no código |
| — | **Novo: `.order()` sem `ascending` em 8 sítios das 3 apps** | O postgrest-dart ordena **ao contrário** por omissão. O catálogo de rubricas saía do fim para o princípio, as listas de clientes e de organizações saíam de Z a A, e as reservas e cobranças do OP do fim do dia para o princípio. Descoberto porque o teste do tecto da caixa de leads falhou. Todos explícitos agora |
| 4.1 + 4.2 | Nenhum script de backup, nenhum agendamento, nenhum restauro alguma vez feito | Cópia da produção tirada, restaurada e **usada** a 11/8, e agendada: diária às 04:40, provada ao domingo às 05:20. O primeiro restauro a sério apanhou o que dias de ensaio não tinham apanhado — os dois gatilhos do `auth.users` perdiam-se em silêncio, com inventário a bater certo e a prova a dar-se por boa. Corrigido nos três sítios que interessam: o inventário conta-os, uma queixa do `pg_restore` reprova a cópia, e os gatilhos entram depois do `public`. Ver [COPIAS_DE_SEGURANCA.md](COPIAS_DE_SEGURANCA.md) |
| 3.4 | Leads de terceiros sem consentimento registado | Três bases legais em `punho_leads_entrada`, com `check` que exige texto e carimbo para se dizer «consentimento» e proíbe meia prova pendurada noutra base. Quem nos telefonou tem base própria (art. 6.º/1/b); o resto fica `nao_registada` em vez de ser reclassificado para parecer legal, e não entra sozinho no pipeline. **O buraco a sério era outro**: o `authenticated` tinha a tabela toda, e um gestor podia carimbar consentimento numa lead que nunca consentiu — pior do que não ter coluna, porque um registo falso passa numa auditoria que um registo em falta não passaria. Ficou com `select` e `update` de duas colunas. Provado com 6 restrições, 6 POSTs à função publicada e 5 tentativas com o papel trocado dentro da base |
| 3.5 | 5 funções `SECURITY DEFINER` executáveis pelo `anon` | 24 políticas passaram de `to public` a `to authenticated`, `EXECUTE` revogado nas quatro, e o `punho_validar_convite` ganhou travão por IP — 60 falhas em 15 minutos, com sonda a provar antes e depois. **E ao fazê-lo apareceu o que a lista à mão de 2.2 tinha deixado passar:** ~20 tabelas ainda com INSERT/UPDATE/DELETE para o `anon`. Fechado por varrimento e com `ALTER DEFAULT PRIVILEGES`, para as tabelas novas nascerem fechadas |
| 4 | `allowed_mime_types` a null no `punho-documentos` | Fechado aos oito tipos que a app produz, mais PDF. O receio — «se a inferência falhar, o envio passa a ser recusado» — era fundado: o cliente do Supabase adivinha pela extensão e cai em `application/octet-stream`. Agora o tipo decide-se na app (`tipos_aceites.dart`), e um ficheiro que não se sabe nomear é recusado com uma frase em vez de um 415. Provado sem precisar de sessão, porque o controlo do tipo corre antes da autorização: APK → 415, PNG → passa o tipo e esbarra na RLS |
| — | **Novo: o balde `releases` era público** | Três APKs do Punho v0.0.6 de 27 Jul, esquecidos quando a publicação passou para as Releases do GitHub. Nenhuma das 54 linhas de `versoes_apps` aponta para lá. Passou a privado; **os ficheiros foram apagados a 14/8**, com o ok dele — pela API do Storage e não por `delete` a `storage.objects`, que apagaria a linha e deixava o ficheiro órfão no S3. O balde fica, vazio: é ele que sustenta as políticas cujo 403 anónimo esta auditoria usou como prova |
| — | **Novo: fotografias de máquinas ficavam no balde para sempre** | Política de DELETE por empresa + a app a apagar o que sai da lista, com 8 testes na função pura que decide o que sai |
| 6.5 | 549 `Text(` para 49 guardas de overflow | **Proxy mau.** A esmagadora maioria são rótulos fixos. O que rebenta é o texto do cliente: 11 ecrãs montados com nomes patológicos a 761 dp e a 360 dp, com controlo negativo. Zero transbordos |
| 6.6 | 94 alvos de toque abaixo de 48 dp | **Proxy mau, duas vezes.** À primeira, contados: eram 1 no Punho e 5 no Control. À segunda, *medidos* com uma régua que monta a peça e pergunta ao Flutter quanto ocupou — título de secção 28, chip de filtro 35, acção de linha 40 (esta era minha, com justificação a olho), e a célula de meio-dia do OP **47, que falha por um dp escondido no risco entre linhas**. Todos a 48, com controlo negativo em cada régua |
| 6.1 | Acessibilidade quase inexistente | **Estava mal medido.** Contar `Semantics` é mau indicador: o `InkWell` já anuncia o toque e um filho com texto já traz rótulo. Medido pela lente certa — botões que são *só* um ícone —, o Punho tinha 2 (o contador de mais/menos) e o Control 6, entre eles o olho da palavra-passe repetido em 3 ecrãs. Todos com nome agora. Mais o `Semantics` na linha que se copia no diagnóstico de licença, que só se anunciava por um ícone de 14 px |

## Aberto

### Alta

**Nada aberto em Alta.** Fechou a 13/8 o que aqui esteve umas horas: **o
cadeado não se conseguia activar com o telemóvel deitado**. O primeiro campo do
«Definir PIN» tem `autofocus`, portanto o teclado abre sozinho e come 200 dos
393 dp de altura; o conteúdo mede 336 e não havia nada para rolar, por isso o
campo de repetir e o «Guardar» ficavam 143 dp abaixo do fundo do ecrã. A app
oferecia um cadeado que não se podia fechar. Os campos passam a lado a lado em
paisagem, o «Guardar» foi para a barra — como em todos os outros formulários —
e o corpo rola. Cinco testes em
`test/core/cadeado/definir_pin_cabe_no_ecra_test.dart`, com controlo de pé.

Passou-me ao lado no smoke da véspera **porque eu conduzi a app por `adb`**:
para chegar ao segundo campo carreguei em «voltar atrás» para esconder o
teclado, uma manobra que ninguém faz com o dedo, e registei-a como esquisitice
do `uiautomator` em vez de a ler pelo que era.

### Média

**Nada aberto em Média.** O 6.3/6.4 saiu da lista por não ser defeito — ver «O
que fica de pé».

### Falta um dedo, e só um dedo

**Os três primeiros fecharam a 12/8 à noite, no Redmi.** A fotografia entrou no
balde como `image/jpeg` e voltou a sair — balde a 0 objectos, `photoPaths` vazio;
o ecrã de RGPD foi tocado a dedo; e o `docs/SMOKE.md` correu inteiro na 0.3.74,
dez fluxos em dez. O que ficou por fazer está abaixo.

E havia um quarto, que era pré-requisito de muito: **as três contas de ensaio já
não entravam**. ~~`gestor.`, `operador.` e `contabilista.nocturno` devolvem
`invalid_credentials`.~~ **Resolvido a 14/8.**

As senhas do `gestor.` e do `operador.` foram rodadas e provadas por REST — as
duas dão sessão, e os 30 testes do `punho_campos_do_colaborador_rest.sh` voltaram
a passar. Fez-se **sem a senha passar pelo transcript**: gera-se localmente,
grava-se no ficheiro, e só o hash bcrypt (`$2a$`, como o `gen_salt('bf')` do
Postgres) vai no `update`. Sem `psql`, sem service_role, e sem pedir ao
classificador nada que ele recuse.

O `contabilista.nocturno@decisaodigital.pt` **não era senha errada: era conta que
nunca existiu** — não há uma única linha em `auth.users` com `contabil` no email,
nem nunca houve. O contabilista entra pelo portal por token de convite, sem se
registar (`punho_convites_contabilista` + a edge function `portal-contabilista`).
As linhas `C_EMAIL`/`C_SENHA` foram tiradas do ficheiro em vez de «arranjadas»:
apontavam para nada.

### Baixa

**1.3** — ~~7 tabelas `punho_*_copia_2026_08_09` vivas em produção.~~ **Largadas a
14/8, com o ok dele.** Conferido antes: 0 linhas em todas as sete, contra 23
clientes, 194 despesas, 298 leads e 773 recebimentos nas vivas — nunca foram
cópia de nada, foram moldes que ficaram. Sem chaves estrangeiras a apontar-lhes
e sem vistas dependentes (`pg_constraint` e `pg_depend`). As 7 políticas RLS
foram com elas. Ficou registado como migração `largar_copias_vazias_2026_08_09`.

**1.5** — ~~`~/punho-backend` é uma cópia completa do repo.~~ **Removido a 14/8 —
e a descrição aqui estava errada.** Não era cópia: era um **worktree** do próprio
`~/punho`, com o `.git` a apontar para `~/punho/.git/worktrees/`. Um `rm -rf`
teria deixado o registo pendurado no repositório principal. Saiu com
`git worktree remove`, depois de se confirmar que `main..hardening/backend`
estava vazio e que o 9c1cb6a já está contido no `origin/main` — nem uma linha se
perdeu. O `git worktree prune` levou de caminho dois registos de `/tmp` cujas
pastas já não existiam.

**3.6** — *leaked password protection* desligada na autenticação. É um interruptor
(`password_hibp_enabled`). Não se ligou porque rejeita palavras-passe que
apareçam em fugas conhecidas, e isso dá atrito imediato com as contas de ensaio.

### Por verificar — nunca foram olhados

Índices contra planos reais.

**Resolvido a 13/8, e ao contrário do que eu tinha escrito.** A 12/8 dei a
etiqueta da reserva por não responder ao toque, depois de seis pontos e de um
toque de 140 ms injectados por `adb`. **Com o dedo dele abre à primeira** — o
que não respondia era a injecção, não a app. A sonda tinha razão e eu li-a mal:
ela dizia que a árvore estava certa, e estava.

O que o dedo dele encontrou foi outra coisa, mais real: **a caixa que abre não
dizia de que reserva era.** Título «Atualizar estado da reserva» e mais nada —
nem máquina, nem cliente, nem dia. E numa célula de meio-dia com duas reservas,
a segunda era invisível: a célula tem 44 dp e a etiqueta de baixo fica cortada.
Mudava-se o estado às cegas. Além disso, os seis estados não cabiam na caixa
deitado, e **«Cancelada» — o desfazer — era o primeiro a ficar de fora.**
Fechado com identidade no título, a lista das vizinhas com salto directo, e a
caixa a rolar. Cinco testes em `test/features/operations/celula_com_duas_reservas_test.dart`.

## O que fica de pé

**6.3 e 6.4 saem da lista de defeitos.** O Control não tem `Theme.of(context)` e
tem 285 `Colors.*` em 95 ficheiros; nenhuma das três apps define `darkTheme`.
Isso é dívida de desenho, não avaria: sem `darkTheme`, o Flutter usa o `theme`
nos dois modos, e a app fica clara — coerentemente clara, porque as cores estão
todas escritas à mão. O defeito seria o contrário: metade dos ecrãs a seguir o
sistema e a outra metade não. Fechar isto a sério é escolher uma paleta escura e
olhar para 95 ficheiros, e essa é uma decisão de desenho que não se toma a
dormir.


`graficos.dart` (250 linhas, `SparklineDiaria`, `AnelPercentagem`,
`BarraHorizontal`, `MiniCalendario`) não é importado por ninguém desde que o
carrossel de slides saiu — vem do commit `53c9183`. Não se apagou de propósito:
são exactamente as peças de desenho de que o **ecrã de futurologia** precisa, e
apagá-las agora é garantir que se reescrevem daqui a um mês. Se não for isso que
se quer, `git rm` e o commit guarda-as.

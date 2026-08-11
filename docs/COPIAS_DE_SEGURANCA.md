# Cópias de segurança do Punho

**Estado: a correr. Cópia da produção tirada, restaurada e usada a 11/8/2026,
e agendada.** Diária às 04:40, provada ao domingo às 05:20, com registo em
`~/copias/punho.log`.

O primeiro restauro a sério apanhou um defeito que nenhum ensaio tinha
apanhado — os gatilhos do `auth.users` — e está descrito em
[O que o primeiro restauro real ensinou](#o-que-o-primeiro-restauro-real-ensinou).

A auditoria de 11/8/2026 (achados 4.1 e 4.2) encontrou isto: nenhum script de
`pg_dump`, nenhum agendamento, e nenhum restauro alguma vez feito. O que havia
eram os backups automáticos do plano Supabase — que ninguém nunca abriu — e sete
tabelas `punho_*_copia_2026_08_09`, todas vazias.

Um backup que nunca foi restaurado não é um backup, é uma esperança.

## As duas peças

```
./scripts/copia_de_seguranca.sh      tira a cópia
./scripts/restaurar_prova.sh         prova que a cópia serve
```

A segunda é a que interessa. Sem ela, o que existe são ficheiros que ninguém
sabe se abrem.

### Como se prova

`restaurar_prova.sh` levanta um PostgreSQL 17 descartável num contentor,
restaura a cópia lá dentro, volta a correr o mesmo inventário
(`scripts/copia_manifesto.sql`) que correu na base viva, e compara linha a
linha: cada tabela com o seu número de linhas, mais as vistas, funções,
políticas RLS, gatilhos, índices, chaves estrangeiras e contas.

Depois **usa** a base restaurada, porque restaurar tabelas e não conseguir fazer
uma pergunta é meio restauro: lê `punho_clientes` — uma vista que se monta sobre
o log a cada leitura, e que só responde se o log tiver vindo inteiro —, conta
`punho_operacoes` e `punho_reservas`, e confirma que `punho_apagar_titular` e
`punho_expurgar_dados` lá estão.

No fim destrói o contentor. A produção nunca é tocada: lê-se a pasta da cópia,
escreve-se num contentor que morre.

## O ensaio

```
./scripts/ensaio_de_copia.sh
```

Levanta um PostgreSQL 17 com a forma da base do Punho — papéis, esquema `auth`,
log de operações, vista com `security_invoker`, RLS, gatilho, as funções do
RGPD — e manda os dois scripts de cima trabalhar contra ele. São os mesmos
scripts, sem ramo de teste lá dentro: só muda para onde apontam
(`PUNHO_DB_ANFITRIAO`, `PUNHO_DB_PORTA`, `PUNHO_COPIA_CONFIG`).

No fim faz o que interessa mais: estraga a cópia de duas maneiras e exige que a
prova recuse ambas — um ficheiro rasurado, que as impressões têm de apanhar, e
uma cópia **íntegra e assinada** cujo inventário mente numa linha, que só a
comparação apanha. Sem a segunda, o teste só provava o `sha256`.

Correr o ensaio pela primeira vez encontrou três defeitos reais nos scripts:
um *here-document* mal fechado, um `grep -c` que devolvia dois zeros e partia
uma linha ao meio, e um `create schema public` do dump a queixar-se contra a
base nova — um erro que não era erro, e um restauro que se queixa é um restauro
em que ninguém confia.

A produção não é tocada em momento nenhum.

## O que a cópia leva

| Ficheiro | O que é |
|---|---|
| `public.dump` | O esquema `public` inteiro — tabelas, dados, vistas, funções, gatilhos, políticas RLS e as permissões dos papéis |
| `contas.dump` | `auth.users` e `auth.identities`. Sem isto restaura-se a empresa e ninguém consegue entrar nela |
| `papeis.sql` | Os papéis a que o `public` dá permissões. Sem eles os `GRANT` não têm a quem se agarrar |
| `agenda.sql` | As tarefas do `pg_cron` — o expurgo RGPD diário vive aí. Não saem no dump do `public` e perdiam-se em silêncio |
| `manifesto.txt` | O inventário da base no momento da cópia. É contra ele que o restauro se compara |
| `impressoes.sha256` | Para se saber se algum ficheiro mudou desde que a cópia foi feita |

Formato `custom` comprimido: abre com `pg_restore`, permite restaurar só uma
tabela, e o script confirma que o ficheiro abre antes de dizer que a cópia está
feita.

## O que a cópia NÃO leva — e porquê

**Os ficheiros do storage.** Hoje o balde `punho-documentos` está vazio e o
`releases` só tem três APKs antigos que também vivem no GitHub. Nada ali é
insubstituível. **No dia em que os documentos começarem a existir, isto passa a
ser um buraco** e o script tem de passar a puxar o balde.

**Uma segunda máquina.** As cópias ficam em `~/copias/punho`, no i9, no mesmo e
único disco (`nvme0n1`) onde vive tudo o resto. Protege contra apagar a base por
engano, contra uma migração que corre mal, contra a Supabase perder o projecto.
Não protege contra o disco morrer. Falta um destino fora da máquina — disco
externo ou `rclone` para um sítio cifrado.

**PITR.** Não está no plano. O que existe é o backup diário da Supabase, e este
é o nosso, independente dela.

## Retenção

30 diárias, mais a primeira de cada mês durante um ano. Prunagem automática no
fim de cada cópia.

## Ligação

Direta a `db.oefqbkhioncakojipqyx.supabase.co:5432`, que **só responde em
IPv6** — daí o `--network host` no docker, porque a rede predefinida dos
contentores é só IPv4. Não há `pg_dump` instalado no i9 e não faz falta: vem do
`postgres:17-alpine` (pg_dump 17.10 contra servidor 17.6).

**O i9 chega lá — provado a 11/8, e sem precisar de senha nenhuma.** Ligou-se
com uma senha errada de propósito e o servidor respondeu `password
authentication failed`. Isso só se diz depois de haver TCP, TLS e handshake,
portanto o caminho de rede está fechado ponta a ponta e o único degrau que falta
é a senha certa. A saída IPv6 do i9 confirma-se com
`curl -6 https://ifconfig.co`, e o `db.*` resolve só em `AAAA` (não tem `A`).

Numa máquina **sem IPv6** isto falharia a resolver o endereço, o que se lê como
«a senha está errada» e faz perder a tarde a repor senhas que já estavam boas. O
`--verificar` sabe distinguir os dois casos e diz qual é. O caminho alternativo,
se um dia for preciso, é o **Session pooler** (*Project Settings → Database →
Connection string → Session pooler*), onde o utilizador é
`postgres.oefqbkhioncakojipqyx` e não `postgres`:

```bash
PUNHO_DB_ANFITRIAO=<anfitriao-do-pooler> \
PUNHO_DB_UTILIZADOR=postgres.oefqbkhioncakojipqyx \
  ./scripts/copia_de_seguranca.sh --verificar
```

Session e **não** Transaction: o `pg_dump` precisa de sessão. O add-on de IPv4
da Supabase resolveria o mesmo, mas é pago e aqui não é preciso.

## O que o primeiro restauro real ensinou

O ensaio corria verde havia dias. O primeiro restauro **da produção a sério**
falhou em duas coisas que a base de ensaio não tinha forma de mostrar.

**Os gatilhos do `auth.users` perdiam-se sem consequência visível.** São dois —
`criar_pedido_acesso_novo_utilizador` e `punho_criar_pedido_ao_registar` — e
vivem no `auth`, mas chamam funções do `public`. Como as contas se restauravam
primeiro (as chaves estrangeiras do `public` apontam para `auth.users`, portanto
têm de vir depois), o `public` ainda não existia e o `pg_restore` saltou-os.

O que se via era o pior caso possível: **inventário idêntico linha a linha**, a
base a responder a tudo, a prova a dar-se por boa. E na base restaurada,
qualquer pessoa que se registasse nunca mais gerava pedido de acesso — ninguém
entrava, e nada no restauro dizia porquê.

Três correcções, por ordem de importância:

1. **O inventário passou a contar os gatilhos das contas.** É isto que faz
   qualquer perda futura ser apanhada pela comparação, em vez de depender de
   alguém ler os avisos do `pg_restore` às 5h20 de domingo.
2. **Uma queixa do `pg_restore` reprova a cópia.** Estava a ser impressa por
   baixo de um visto verde. Uma prova que avisa e aprova não é uma prova.
3. **Os gatilhos entram depois do `public`**, separados por objecto
   (`pg_restore -L`) e não por secção. A chave primária do `auth.users` também
   vive no post-data: partir por secções trocava dois gatilhos perdidos por ~20
   chaves estrangeiras perdidas.

A lição que fica: um ensaio contra uma base que nós próprios desenhámos só
encontra os defeitos que soubemos imaginar. A forma real da produção — neste
caso, gatilhos que atravessam esquemas — traz os outros.

## A senha

Os scripts lêem `~/.punho/copia.env`:

```
PGPASSWORD=a-senha-da-base
```

**Não escrever esse ficheiro à mão.** O script faz `source`, e uma senha com
`$`, espaço, `'` ou `"` chega truncada ou vazia — o que depois se lê como senha
errada e manda-se repor uma que já estava boa. Verificado: `PGPASSWORD=ab$c d#e`
escrito à mão chega como string vazia. Escrever assim, que não põe a senha no
histórico da shell nem no ecrã e cita-a como deve ser:

```bash
(umask 077; read -rsp 'senha: ' p; printf 'PGPASSWORD=%q\n' "$p" > ~/.punho/copia.env; unset p; echo)
```

É a senha do utilizador `postgres`, escolhida quando o projecto foi criado e
mostrada **uma vez**. Nunca mais foi precisa porque nada liga directamente ao
Postgres: as apps falam por PostgREST com a chave anon, as edge functions usam
a `service_role`, o CLI usa o login. Esta cópia é a primeira coisa a precisar
dela — e é por isso que a ausência dela não é sinal de nada estar mal.

A original perdeu-se — não estava no i9, nem no `D:\Seguro` onde vivem as das
keystores. Foi reposta a 11/8/2026 em *Project Settings → Database → Reset
database password*, e a nova está no `D:\Seguro`. Repor não partiu nada, e não
partiu exactamente pela razão que explicava não a termos: não havia um único
sítio a usá-la. O reset não toca nas chaves `anon`/`service_role`, no token
`sbp_` nem no login do CLI.

**O ficheiro não se escreve à mão** — ver a receita acima. E se um dia a
ligação falhar, ler primeiro o que o `--verificar` diz: ele distingue «não
cheguei lá» de «cheguei e a senha não serve», e essa distinção poupa a tarde de
repor uma senha que já estava boa.

## A correr

```cron
# copia da base do Punho — diaria, e provada uma vez por semana
40 4 * * * /home/cesar/punho/scripts/copia_de_seguranca.sh >> /home/cesar/copias/punho.log 2>&1
20 5 * * 0 /home/cesar/punho/scripts/restaurar_prova.sh   >> /home/cesar/copias/punho.log 2>&1
```

Fica às 04:40 por não chocar com o expurgo RGPD, que corre às 04:17. Ambos os
scripts foram corridos com o ambiente reduzido do cron (`env -i
PATH=/usr/bin:/bin HOME=/home/cesar`) antes de serem agendados — um `docker`
fora do `PATH` dava uma falha silenciosa todas as noites, que é precisamente o
que isto existe para não acontecer. O `restaurar_prova.sh` sem argumento escolhe
a cópia mais recente.

**O que ainda não está resolvido:** o registo é um ficheiro que ninguém lê. Uma
cópia que comece a falhar às 04:40 fica a falhar até alguém abrir o
`~/copias/punho.log`. Falta um aviso activo — e enquanto não existir, isto é
uma cadeia provada com uma vigia por fazer.

# Cópias de segurança do Punho

**Estado: montado, por provar.** Falta um passo, e é do César — ver
[O que falta](#o-que-falta-a-senha) no fim.

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

## O que falta: a senha

Os scripts lêem `~/.punho/copia.env`:

```
PGPASSWORD=a-senha-da-base
```

A senha não está em lado nenhum do disco — procurei em todos os `.env`, no CLI
da Supabase e num varrimento por connection strings.

Se não estiver guardada em lado nenhum, a Supabase nunca a volta a mostrar: só
deixa gerar outra em *Project Settings → Database → Reset database password*.
**Gerar outra aqui é seguro** — nada usa essa senha. As apps usam a chave anon,
as edge functions usam a `service_role`, e não existe nenhuma connection string
no disco.

Assim que o ficheiro existir:

```bash
./scripts/copia_de_seguranca.sh --verificar   # só confirma que a senha serve
./scripts/copia_de_seguranca.sh               # tira a primeira cópia
./scripts/restaurar_prova.sh                  # prova-a
```

E **só depois** é que isto vai para o cron. Agendar um backup por provar era só
mudar de esperança. A entrada será:

```cron
# copia da base do Punho — diaria, e provada uma vez por semana
40 4 * * * /home/cesar/punho/scripts/copia_de_seguranca.sh >> /home/cesar/copias/punho.log 2>&1
20 5 * * 0 /home/cesar/punho/scripts/restaurar_prova.sh   >> /home/cesar/copias/punho.log 2>&1
```

Fica às 04:40 por não chocar com o expurgo RGPD, que corre às 04:17.

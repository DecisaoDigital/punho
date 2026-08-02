# Dados do funcionário a chegar em tempo real — como se faz a sério

> Estudo, 2 ago 2026. Estado: **proposta, nada implementado.**
> Sobre o que já existe: `lib/core/sync/sincronizacao_entre_dispositivos.dart`.

## O problema, em concreto

Um colaborador regista uma reserva no terreno. Quando é que aparece no telemóvel
do gestor?

Hoje, com o que está escrito:

| gatilho | atraso |
|---|---|
| a app volta ao ecrã (`resumed`) | imediato |
| temporizador com a app aberta | **até 5 minutos** |
| depois de uma alteração local | 3 segundos (debounce) |

Ou seja: com a app aberta na mão do gestor, **até cinco minutos**. Não há nada
que empurre. Toda a sincronização é o cliente a perguntar.

E não é por descuido — o comentário no código explica a escolha: *"o que muda no
terreno não muda ao segundo, e cada verificação é rede e bateria de quem está a
trabalhar"*. Perguntar de 30 em 30 segundos era pior: mais bateria, mais pedidos,
e continua a não ser tempo real.

**A metade difícil já está feita.** O log append-only (`punho_operacoes`), o
cursor por `seq`, o `upsert` idempotente, a supressão do próprio eco por
`por_dispositivo`, a ordem "recebe primeiro, envia depois" — isso é o motor de
sincronização, e está bem. Falta só a campainha.

## Como as apps profissionais resolvem isto

Há três famílias, e a diferença entre elas é **o que viaja no canal em tempo
real**.

### A. Campainha, não camião — *notify then reconcile*

O canal em tempo real transporta apenas **"há novidades"**. O cliente, ao ouvir,
faz o que já sabia fazer: puxar desde o cursor.

É o padrão dominante em produto sério, e a razão é uma só: **um WebSocket não é
de confiança para entrega**. Cai, reconecta, e o que passou durante a queda
perdeu-se. Quem trata o canal como camião fica com buracos silenciosos nos dados;
quem o trata como campainha só perde… uma campainha, e a próxima chegada — ou o
temporizador de segurança — repõe tudo.

O padrão de recuperação é sempre o mesmo, e é exactamente o que o Punho já tem:
ao reconectar, pedir o que falta a partir do **último identificador recebido**
([WebSocket.org](https://websocket.org/guides/reconnection/),
[OneUptime](https://oneuptime.com/blog/post/2026-01-24-websocket-reconnection-logic/view)).

**Consequência prática:** o tempo real passa a ser uma **optimização de
latência**, não um caminho de dados. Se falhar por completo, a app continua
correcta — só mais lenta. É esta propriedade que a torna segura de adoptar.

### B. Empurrar os dados pelo canal

O servidor manda a linha alterada e o cliente aplica-a directamente. Mais
simples de escrever, e tentador.

Problemas conhecidos, e é por aqui que os projectos se queimam:

- **não escala.** No Supabase, `Postgres Changes` processa as alterações **numa
  só thread** para manter a ordem, e **re-verifica o RLS por cliente ligado**. A
  própria documentação diz que acima de ~3 000 subscritores nas mesmas mudanças
  se deve passar a Broadcast
  ([Supabase Docs](https://supabase.com/docs/guides/realtime/subscribing-to-database-changes),
  [Benchmarks](https://supabase.com/docs/guides/realtime/benchmarks)).
- **os buracos são invisíveis.** Aplicar o que chega e nada mais significa que
  uma reconexão perdida deixa dados em falta sem ninguém dar por isso — até
  alguém reparar que falta uma reserva.
- **duas verdades.** Passa a haver dois caminhos para o mesmo dado (o canal e a
  sincronização normal), com duas ordens possíveis e dois sítios para o conflito.

### C. Trocar o motor por um sync engine local-first

PowerSync, ElectricSQL, Zero. Substituem a camada de sincronização inteira:
mantêm um SQLite local espelhado do Postgres e tratam de tudo.

Em 2026 são opções maduras — o PowerSync é o mais rodado em produção móvel,
o ElectricSQL o caminho mais simples para Postgres, o Zero o de melhor
experiência em web
([BuildPilot](https://trybuildpilot.com/648-electric-sql-vs-powersync-vs-zero-2026),
[Verity](https://verity.salient.community/research/local-first-software-in-2026.html)).

**Não é para aqui, e a razão não é técnica.** Estas ferramentas resolvem o
problema que o Punho **já resolveu**: fila local, cursor, idempotência,
resolução de conflitos. Adoptá-las agora seria deitar fora código que funciona,
está testado e está afinado ao modelo de negócio (ganha a última a chegar, por
`seq` do servidor), em troca de uma dependência nova e de outra forma de pensar.

Valem a pena quando o problema **muda de tamanho**: replicação parcial
complicada (cada colaborador só vê parte dos dados), volumes que não cabem em
memória, ou vários clientes a editar o mesmo registo ao mesmo tempo.

## Recomendação para o Punho: A, com Broadcast

Manter tudo o que existe. Acrescentar **uma campainha** e nada mais.

### Porquê Broadcast e não Postgres Changes

O Supabase tem hoje o `realtime.broadcast_changes()`, disparado por um trigger:
é SQL a decidir **o quê** vai para **que canal**, em vez de cada cliente filtrar
tudo. Suporta "dezenas de milhares de utilizadores ligados", contra a barreira
de milhares do Postgres Changes
([Supabase Blog](https://supabase.com/blog/realtime-broadcast-from-database)).

Encaixa no `punho_operacoes` sem esforço: já é append-only e já tem `empresa_id`.
Um canal por empresa, e cada telemóvel só ouve o da sua.

### O desenho

**1. Trigger que toca a campainha** — repare-se no que **não** vai no payload:

```sql
create or replace function public.punho_operacoes_avisar()
returns trigger
security definer
language plpgsql
as $$
begin
  -- Só o `seq`. Nem payload, nem entidade, nem quem fez.
  -- Quem ouve vai buscar pelo caminho normal, com RLS aplicado na leitura.
  -- Mandar os dados aqui seria abrir um segundo caminho para o mesmo dado.
  perform realtime.broadcast_changes(
    'empresa:' || NEW.empresa_id::text,
    'nova_operacao', 'INSERT', TG_TABLE_NAME, TG_TABLE_SCHEMA,
    jsonb_build_object('seq', NEW.seq), null
  );
  return null;
end;
$$;

create trigger punho_operacoes_avisar_trigger
after insert on public.punho_operacoes
for each row execute function public.punho_operacoes_avisar();
```

**2. Quem pode ouvir** — canal privado, com política sobre `realtime.messages`:
só membros activos da empresa cujo id está no nome do canal.

**3. No cliente**, dentro do `SyncController` que já existe:

```dart
_canal = supabase.channel('empresa:$empresaId', opts: const RealtimeChannelConfig(private: true))
  ..onBroadcast(event: 'nova_operacao', callback: (_) => _agendar())
  ..subscribe();
```

`_agendar()` — o debounce de 3 segundos que já lá está. **Uma linha de lógica
nova.** A campainha entra no mesmo caminho da alteração local, e tudo o resto
continua igual.

### O que muda no comportamento

| | hoje | com campainha |
|---|---|---|
| app aberta | até 5 min | ~1–3 s |
| app em fundo | ao voltar | ao voltar (igual) |
| sem rede | ao voltar rede | ao voltar rede (igual) |
| canal em baixo | — | volta ao comportamento de hoje |

Essa última linha é o ponto todo: **a falha do tempo real degrada, não parte.**

## Os erros que se pagam caro

1. **Aplicar o payload do canal directamente.** Volta-se à família B e aos
   buracos silenciosos. A campainha diz *que* há novidades, nunca *quais*.
2. **Desligar o temporizador dos 5 minutos.** É a rede de segurança para quando
   a campainha não toca. Baixar para 15 minutos, sim; desligar, não.
3. **Sincronizar a cada campainha sem debounce.** Um colaborador a gravar dez
   coisas seguidas toca dez vezes. O debounce que já existe resolve, desde que a
   campainha passe por ele.
4. **Esquecer o próprio eco.** Quem escreveu também recebe a campainha. Já está
   tratado (`por_dispositivo`), mas passa a acontecer muito mais vezes.
5. **Reconectar sem recuperar.** Ao voltar a ligar, sincronizar **sempre**, sem
   esperar por campainha — é durante a queda que se perdem os avisos.
6. **Um canal global em vez de um por empresa.** Todos acordariam com o trabalho
   de todos.

## O que fica por decidir

- **O gestor quer ver mexer, ou quer ser avisado?** São coisas diferentes. Isto
  resolve a primeira. A segunda é notificação push, e essa funciona com a app
  fechada — que é quando o gestor normalmente está.
- **Custo.** As mensagens de Realtime contam para o plano. Com uma empresa e dois
  aparelhos é ruído; convém olhar antes de haver cinquenta clientes.
- **Presença** ("o João está a ver isto agora") sai de graça do mesmo canal, se
  algum dia interessar.

## Fontes

- [Supabase — Realtime: Broadcast from Database](https://supabase.com/blog/realtime-broadcast-from-database)
- [Supabase Docs — Subscribing to Database Changes](https://supabase.com/docs/guides/realtime/subscribing-to-database-changes)
- [Supabase Docs — Realtime Benchmarks](https://supabase.com/docs/guides/realtime/benchmarks)
- [WebSocket.org — Reconnection: State Sync and Recovery](https://websocket.org/guides/reconnection/)
- [OneUptime — WebSocket Reconnection Logic](https://oneuptime.com/blog/post/2026-01-24-websocket-reconnection-logic/view)
- [BuildPilot — ElectricSQL vs PowerSync vs Zero (2026)](https://trybuildpilot.com/648-electric-sql-vs-powersync-vs-zero-2026)
- [Verity — Local-First Software in 2026](https://verity.salient.community/research/local-first-software-in-2026.html)

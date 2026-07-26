# Backlog v0.1.0

Coisas deixadas de fora de propósito, com o motivo registado. **Nada disto está
implementado.** O backlog da v0.0.4 (bug hunt da v0.0.3) está em
`BACKLOG_v0.0.4.md`.

## Push de notificações (FCM) — só se justificar

Fora do âmbito da sprint do aviso de update global
(`design/punho_v004_update_global.md`). Hoje o único canal é a app perguntar ao
Control no arranque, e isso cobre todos os utilizadores que abrem a app.

O que FCM acrescentaria: avisar quem tem a app **fechada**. O que custa:

- `firebase_messaging` no `pubspec.yaml` e projecto Firebase criado.
- `google-services.json` (Android) e configuração no `build.gradle`.
- Service account do lado do Control para enviar as mensagens.
- Código de registo e renovação do token, e uma tabela para o guardar.
- Tratamento das três situações — foreground, background, terminated — cada uma
  com comportamento próprio.
- Permissão de notificações a pedir ao utilizador no Android 13+.
- Custo Firebase: grátis no plano Spark para volumes baixos, mas é mais uma
  consola, mais um segredo e mais uma dependência de terceiros na cadeia.

**Só vale a pena quando** houver utilizadores reais que passem dias sem abrir a
app e a demora a actualizar se tornar um problema medido, não suposto. Até lá o
arranque chega.

## Aviso de update com contexto por ecrã

Voltar a embutir o `PunhoUpdateBanner` em ecrãs específicos, por cima do aviso
global, para dizer o que a versão nova traz para *aquele* ecrã ("esta
actualização inclui o novo painel financeiro").

Over-engineering para agora: implica saber, por versão e por ecrã, o que mudou —
ou seja um mapa de features na resposta da Edge Function. O aviso global já
resolve o problema real, que é o utilizador saber que existe versão nova.

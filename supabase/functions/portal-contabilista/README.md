# portal-contabilista

O formulário que o contabilista abre por link, sem conta e sem app. Desenho e
razões em `docs/PORTAL_DO_CONTABILISTA.md`.

## Deploy

```bash
supabase functions deploy portal-contabilista --no-verify-jwt
```

**`--no-verify-jwt` é obrigatório.** O contabilista não tem JWT nenhum: o token
do link é a autenticação toda. É por isso que ele tem de ser gerado com 256 bits
de entropia e que a base só guarda o `sha256`.

Se esta função for alguma vez redeployada com `verify_jwt` ligado, o link deixa
de abrir para toda a gente e o sintoma é um 401 sem explicação.

## Rotas

Todas levam `?t=<token>`.

| Método | Corpo | O que faz |
|---|---|---|
| `GET` | — | Devolve a página, já preenchida com o que existir |
| `POST` | `{accao:"guardar", rubrica, mes?, ano?, valor}` | Grava, ou apaga se `valor` vier vazio |
| `POST` | `{accao:"mensagem", texto}` | Caixa do fim |
| `POST` | `{accao:"submeter"}` | Marca `submetido_em` |

`guardar` devolve `{formatado}` — o valor como o servidor o interpretou. O
cliente repõe-no no campo, e é isso que impede alguém de escrever `1.200` a
pensar em mil e duzentos euros e ficar com um euro e vinte sem dar por isso.

## O que não se negoceia

1. **A empresa sai do token.** O `POST` só envia `convite_id`; quem deriva a
   empresa é `punho_guardar_resposta_contabilista`, na base. Aceitar
   `empresa_id` do corpo era deixar qualquer token escrever em qualquer empresa.
2. **O token nunca vai a log nem a resposta de erro.** Vive no histórico do
   browser e em emails reencaminhados.
3. **Um link inválido responde sempre igual**, seja porque não existe, expirou
   ou foi revogado. A diferença só serviria a quem anda a tentar à sorte.
4. **Campo vazio apaga.** Voltar a "não sei" tem de ser tão fácil como escrever.
5. **A janela do convite obriga na base, não na página.** A página só desenha os
   meses pedidos, mas quem tem o token monta o `POST` à mão. Mês ou ano fora de
   `[mes_inicial, mes_final]` levam 400 vindo de
   `punho_guardar_resposta_contabilista`. Validar no browser é cortesia para
   quem escreve; não é segurança.

## Testes

```bash
deno test supabase/functions/portal-contabilista/euros_test.ts
```

Cobrem a leitura de valores em euros — a parte que se testa sem base de dados e
onde um erro passa mais tempo despercebido. Um número mal lido não rebenta:
grava-se em silêncio e aparece meses depois num painel que ninguém percebe
porque está errado.

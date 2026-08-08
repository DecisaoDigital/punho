# Portal do contabilista — onde vive e porquê

O contabilista abre um link e preenche uma grelha de rubricas. Não tem conta,
não instala nada, e o que o autoriza é um token no URL. Este documento é sobre
**onde essa página está alojada** — porque a resposta não é a óbvia, e quem
vier a seguir vai querer mudá-la sem saber o que parte.

## A página não pode ser servida pela Edge Function

Foi, durante algum tempo, e nunca funcionou à vista de ninguém: o contabilista
abria o link e recebia o código-fonte em bruto.

**O Supabase reescreve `text/html` para `text/plain` e acrescenta
`X-Content-Type-Options: nosniff` em tudo o que sai de `*.supabase.co`.** É uma
defesa contra phishing alojado em Edge Functions, e não se desliga. Confirmado
com uma função descartável que só devolvia `<h1>olá</h1>`: chegou como texto.
O JSON passa intacto.

Domínio próprio no Supabase resolveria, mas são $10/mês por cima do Pro, e a
própria documentação diz que não é para alojar frontends.

## Como está agora

```
  Punho (app)                     i9 (Tailscale Funnel)          Supabase
  cria convite ──► link ──► https://…ts.net/portal/?t=TOKEN
                                        │
                                        ├─ GET  ?t=…&formato=json ──► {"html": "…"}
                                        │      document.write(html)
                                        └─ POST ?t=…             ──► grava resposta
```

- A **página estática** é `~/sites/portal/index.html` no i9. Lê o `?t=`, vai
  buscar o HTML dentro de JSON e escreve-o no documento.
- A **Edge Function** continua a desenhar a página inteira com os dados já lá
  dentro — não foi reescrita. Só mudou a embalagem.
- O link está numa constante só: `portalContabilista`, em
  `lib/features/contabilista/data/contabilista_service.dart`.

### CORS é por lista, não por `*`

`ORIGENS_PERMITIDAS`, no topo da Edge Function. **Não pôr `*`**: o token do
convite viaja no URL, e um `*` punha qualquer página do mundo a poder lê-lo com
o token na mão. Mudar de alojamento obriga a acrescentar a origem nova aqui.

### O URL da API não se deriva de `req.url`

Dentro da função o Supabase já terminou o TLS e cortou o prefixo — `req.url` dá
`http://…/portal-contabilista`, sem HTTPS e sem `/functions/v1`. Vem do
`SUPABASE_URL` do ambiente. Isto já partiu uma vez.

## O que isto custa

**Se o i9 estiver desligado, o contabilista não vê página nenhuma.** É o preço
de alojar em casa e foi uma escolha consciente. A configuração do Funnel
sobrevive a reboot — verificado com `systemctl restart tailscaled` — mas não
sobrevive à máquina estar em baixo.

**Mudar `portalContabilista` parte todos os convites já enviados.** O link é
gravado no momento em que o convite se cria; não é resolvido depois. Se um dia
isto passar para `portal.decisaodigital.pt`, os convites vivos têm de ser
reemitidos.

## Comandos

```bash
# estado
tailscale funnel status

# repor depois de mexer
sudo tailscale funnel --bg --set-path / /home/cesar/sites

# provar pelo caminho público, não pela MagicDNS local
curl -sS -D- -o /dev/null \
  --resolve decisaodigital.tailb66396.ts.net:443:176.58.90.63 \
  https://decisaodigital.tailb66396.ts.net/portal/
```

O `--resolve` não é fussiness: sem ele o `curl` no i9 resolve pela MagicDNS e
fala consigo próprio pela rede interna, e um Funnel partido passaria o teste.

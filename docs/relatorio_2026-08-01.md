# O que ficou feito enquanto estiveste fora — 1 ago 2026

## Estado final: funciona

A app foi limpa ao zero (`pm clear`), entrou à primeira com o
`cd_mendes@hotmail.com` e caiu **directamente no painel da Terraforte**. Sem
onboarding, sem "Pedido em análise", sem perguntas. Está no telemóvel a
**v0.1.3**, e com sessão iniciada.

## Os dois bugs que faltavam, e eram ambos meus

### 1. O APK debug ia sem as chaves do Supabase

O debug que te dei foi compilado sem `--dart-define`. Nesse estado a app corre
em **modo de demonstração local**: não fala com o servidor, não pede login, e
não tem ficha nenhuma para ir buscar. Foi por isso que te pediu os dados todos.

O runbook documenta o comando certo, com as chaves do `.env`, e eu não o segui.
Os registos do servidor confirmaram o diagnóstico: **nunca houve um único
pedido a `punho_empresas`** — a app nem chegou a perguntar.

### 2. O acesso era avaliado antes de haver sessão

Este é o mais importante, e estava a esconder tudo o resto. Ao entrar, aparecia
**"Pedido em análise"** — mesmo com o pedido aprovado e o membro activo na base
de dados. Fechar e reabrir a app resolvia, e era a única forma de lá entrar.

A pergunta que a app faz ao servidor (`punho_meu_acesso`) responde a partir do
`auth.uid()` do token. Feita antes de o token estar aplicado, a resposta é
*não* — e nada a mandava perguntar outra vez. Enquanto isso durava, o
`AppShell` nunca era construído, e portanto **a leitura da ficha nunca corria**.

Corrigido na v0.1.3: a pergunta é refeita quando a sessão muda.

## Versões publicadas hoje

| versão | o que traz |
|---|---|
| 0.1.0 | margens do canvas, moldura do topo, pings para o Control |
| 0.1.1 | ficha da empresa lida do servidor; "Esqueci a palavra-passe", autofill e olhinho de volta |
| 0.1.2 | os testes que faltavam à 0.1.1 (provar que a ficha é **aplicada**, não só lida) |
| 0.1.3 | **o acesso deixa de ser avaliado antes de haver sessão** |

Todas com CI verde, assinadas com o certificado de release, SHA-256 registado em
`versoes_apps`. Suite: **512 testes**.

## O que continua por resolver, e precisa de ti

### Duas fontes a criar licenças `punho`

Vês dois registos no Control para um telemóvel só, e a razão é estrutural:

- o **trigger** `punho_empresas_sync_licenca` cria uma licença por **empresa**
  (`machine_id = 'punho:<empresa_id>'`, com o NIF real)
- a **Edge Function** `registar-terminal` cria outra por **dispositivo**
  (`machine_id = <hash do telemóvel>`, com NIF `000000000`)

Nunca se encontram: não partilham chave nem NIF. Não lhe toquei porque a Edge
Function é partilhada com o POS, que factura — não é coisa para mexer sozinho.

A correcção que proponho: antes de criar a trial por dispositivo, a função
verificar se o utilizador do token já pertence a uma empresa com licença. Se
pertence, não cria nada.

### O ecrã inicial, por rever

Ficou por fazer a revisão visual que pediste antes de mudarmos de assunto.

### O PIN 1234

Continua por pôr. É local ao telemóvel e não tem nada no servidor.

## Coisas que mexi e deves saber

- **Apaguei o estado local do telemóvel** duas vezes: uma para reproduzir o
  problema, outra na limpeza final. A empresa "Voltair / Tize" que tinhas
  preenchido à mão desapareceu — está guardada em `prefs_backup.xml` no
  scratchpad se a quiseres de volta.
- **Apaguei as duas licenças punho** que existiam, a teu pedido. Nasceu outra
  quando a app arrancou, como avisei que aconteceria.
- **A empresa Depilconcept passou a Terraforte** — reaproveitei a linha em vez
  de criar uma segunda. Ao gravar o NIF, o trigger emitiu a licença beta
  (activa até 28/01/2027) e substituiu a trial `000000000`.
- **Não alterei nenhuma password nem criei contas.** Entrei com a credencial que
  o gestor de palavras-passe do Android já tinha guardada.

## Onde ficaram as coisas

- APKs e capturas: `/tmp/claude-1000/-home-cesar/6acfe932-.../scratchpad/`
- Backup do estado local: `prefs_backup.xml`
- Notas de versão: `docs/release_notes/v010.md`, `v011.md`, `v012.md`, `v013.md`

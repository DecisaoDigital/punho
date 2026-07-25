# Punho — Licenciamento

O Punho reutiliza a infra do WashInvoice Control: mesmo projecto Supabase
(`oefqbkhioncakojipqyx`), mesmas Edge Functions `registar-terminal` e
`validar-licenca` (v6+, multi-app), distinguidas pelo campo `app: 'punho'`.

Não há infra de licenciamento própria do Punho. Tudo o que o Cesar já faz para
o POS no Control aplica-se aqui.

## Auto-onboarding

No arranque da app (`main.dart`, logo após `Supabase.initialize`):

1. O Punho resolve o `machine_id` — ver secção abaixo.
2. Chama `registar-terminal` com `{machine_id, app: 'punho', info_host}`.
3. O Control cria uma linha em `licencas` com `app='punho'`, `plano='trial'`,
   `validade = hoje + 40 dias`, `activa=true`, `oferta=true` e
   `pendente_revisao=true`.
4. O Cesar vê a instalação no Control e decide o plano definitivo.

A chamada é **idempotente** do lado do servidor por `(machine_id, app)` — o
mesmo PC pode ter o POS e o Punho lado a lado sem colidir, e chamar em todos os
arranques não cria linhas duplicadas.

Corre **antes do login** e **não bloqueia o arranque**. Se falhar (offline,
timeout), falha em silêncio e volta a tentar no arranque seguinte.

### Porque é que funciona sem sessão

As duas Edge Functions estão deployed com `verify_jwt: true`, mas isso **não**
exige utilizador autenticado — exige apenas uma chave válida no header
`Authorization`. Quando não há sessão, o `supabase_flutter` envia a chave
pública do projecto, e o gateway aceita-a.

Verificado empiricamente contra o projecto real (Julho 2026), com body vazio
para não criar registos:

| Autenticação enviada | Resposta |
|---|---|
| Legacy anon key (JWT `eyJ…`) | `400 {"erro":"machine_id obrigatório"}` — passou |
| Publishable key (`sb_publishable_…`) | `400` — passou |
| Nenhuma | `401` |

Por isso o `PunhoLicencaService` **não** replica o
`if (session == null) return null;` que existe no `update_service.dart`. Essa
guarda é específica do auto-update, que só interessa depois do login.

## `machine_id`

SHA256 de uma semente própria da plataforma, calculado uma vez e guardado em
`SharedPreferences` sob a chave `punho_machine_id`.

| Plataforma | Semente |
|---|---|
| Android | `android:<ANDROID_ID>` |
| Windows | `windows:<computerName>:<MachineGuid>` |
| Outras | `desconhecido:<so>:<timestamp>` (fica em cache, logo estável) |

Só o hash sai do dispositivo — a semente nunca é enviada. O mesmo utilizador
com Punho no telemóvel e no PC conta como **dois terminais**, com duas linhas
em `licencas`.

O `info_host` enviado no registo tem apenas o que o Cesar precisa para
identificar a instalação no Control: plataforma, versão e build da app, nome do
host, fabricante e versão do SO. Nenhum dado de negócio.

## Validação

Em cada arranque e depois de 6 em 6 horas (`intervaloRevalidacaoLicenca`):

1. `validar-licenca` com `{machine_id, app: 'punho'}`.
2. A resposta é convertida em `LicencaInfo`.
3. Se houver algo a assinalar, o `LicencaBanner` mostra-o.

O banner está no topo do body do `AppShell`, por isso aparece em **todos** os
ecrãs e não só no painel de gestão — o aviso de trial a expirar não pode
depender do ecrã onde o utilizador está.

Excepção conhecida: o `AppShell` devolve cedo para `OnboardingPage` e
`CollaboratorShell`, e nesses dois ecrãs o banner não aparece. É aceitável —
durante o onboarding o terminal ainda agora foi registado, e o colaborador não
é quem trata da licença.

### Estados e avisos

| Estado | Condição | Cor | Mensagem |
|---|---|---|---|
| `activa` | plano pago, ou trial com > 10 dias | — | não mostra nada |
| `activa` | trial, 4 a 10 dias | amarelo | "Trial termina em N dias. Contactar suporte." |
| `activa` | trial, ≤ 3 dias | laranja | "Trial termina em N dias — contactar já." |
| `expirada` | — | vermelho | "Licença expirada. A app está em modo limitado." |
| `inactiva` | — | vermelho | "Licença suspensa. Contactar suporte." |
| `inexistente` | — | cinzento | "Terminal por registar. A tentar registo…" |

No estado `inexistente` o banner volta a chamar `registar-terminal` uma vez e
revalida. Cobre o caso de o registo do arranque ter falhado por estar offline.

`LicencaInfo` a `null` significa **"não foi possível saber"** — sem Supabase
configurado, offline, ou timeout. Não é o mesmo que "sem licença", e por isso
não mostra aviso nenhum. A app nunca fica inutilizável por falta de rede.

## Modo limitado — ainda NÃO implementado

O estado `expirada` mostra o banner vermelho mas **não bloqueia nada**. Toda a
funcionalidade continua disponível.

Foi decisão deliberada: bloquear features só faz sentido quando existir um
primeiro cliente pagante que não renove. Até lá, um bloqueio só criaria risco
de deixar o próprio Cesar de fora durante uma demonstração.

Fica para sprint futuro: desactivar escrita quando `estado == expirada`,
mantendo a leitura do histórico.

## Renovação

O utilizador clica "Contactar" no banner → abre email para
`cesarmendes78@gmail.com` com assunto "Licença Punho". O Cesar prolonga
manualmente no Control, no mesmo ecrã que já usa para o POS.

Não há pagamento dentro da app, nem ecrã de gestão de licença. Ambos ficam
para iteração futura.

## Ficheiros

| Ficheiro | Papel |
|---|---|
| `lib/core/licenca/licenca_info.dart` | Modelo e leitura do JSON da EF |
| `lib/core/licenca/machine_id.dart` | Identificador do dispositivo, com cache |
| `lib/core/licenca/licenca_service.dart` | Cliente das duas Edge Functions |
| `lib/core/licenca/licenca_provider.dart` | Providers Riverpod e timer das 6h |
| `lib/features/licenca/presentation/licenca_banner.dart` | Banner e regra de aviso |

O `PunhoLicencaService` não consulta `SupabaseConfig.enabled` — quem chama é
que decide (`licencaProvider` e o arranque em `main`). Assim o serviço fica
testável em `flutter test`, que corre sem `--dart-define`.

O construtor `PunhoLicencaService.comInvocador` existe só para os testes
substituírem a rede sem precisar de um package de mocking.

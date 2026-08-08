# Punho

Aplicação Flutter de gestão operacional e apoio à decisão para pequenas
empresas, desenvolvida pela **Decisão Digital**.

O Punho transforma registos do trabalho diário — clientes, reservas, máquinas,
recebimentos, despesas e equipa — em métricas, explicações e ações
recomendadas. A primeira vertical aprofundada é o aluguer de máquinas.

## Começar por aqui

- [Estado actual da aplicação](docs/ESTADO_ATUAL_DA_APP.md)
- [O que é o Punho](docs/O_QUE_E_O_PUNHO.md)
- [Decisões e roadmap vivo](docs/DECISOES_E_ROADMAP_VIVO.md)
- [Processo de release (runbook)](docs/PROCESSO_DE_RELEASE.md) ← **ler antes de cortar tag**
- [Smoke manual v0.0.8](docs/SMOKE_v0.0.8_CHECKLIST.md)
- [Índice da documentação](docs/README.md)

## Plataformas

- **Android** — plataforma principal e única publicada actualmente pelo CI.
- **Windows** — suportado para desenvolvimento e builds locais; job Windows
  do GitHub Actions está suspenso.
- **iOS** — suspenso.

## Preparar o ambiente

Requer Flutter stable compatível com o requisito Dart do `pubspec.yaml`,
JDK 21, Android SDK.

```powershell
Copy-Item .env.example .env
flutter pub get
flutter run
```

Preenche `.env` com `SUPABASE_URL` e `SUPABASE_ANON_KEY`. Ficheiro local,
ignorado pelo Git, nunca partilhado.

Windows:

```powershell
flutter run -d windows
```

> **Nota:** `.env` só serve para desenvolvimento. Builds de release **têm de
> passar as chaves por `--dart-define`** (ver [PROCESSO_DE_RELEASE.md](docs/PROCESSO_DE_RELEASE.md)).
> O CI bloqueia releases sem estes defines (guard-rail #236).

## Qualidade

```powershell
flutter analyze
flutter test --exclude-tags=screenshot
```

Testes marcados `screenshot` são goldens dependentes de fontes/rendering
Windows — excluídos no CI, corridos localmente quando se toca em UI.

## Fluxo de trabalho

- Branch principal: `main`. Push directo é permitido para fixes pequenos;
  features estruturais em `feat/*` com merge por PR.
- Antes de cortar tag: **smoke manual dos 9 fluxos** (`docs/SMOKE_*.md`).
- Ver [PROCESSO_DE_RELEASE.md](docs/PROCESSO_DE_RELEASE.md) para a sequência
  exacta de release (bump → workflow_dispatch → tag → APK → catálogo).

## Infra de trabalho

- **Máquina de trabalho preferida: i9 do Home Lab** (Ubuntu Server 24.04),
  hostname Tailscale `decisaodigital` (IP fixo `100.92.206.22`). Compila
  Flutter, corre `analyze` e `test`, produz APKs assinados. É onde deve
  arrancar qualquer build ou tarefa demorada — o mount NTFS do PC Windows
  via sandbox Cowork é impraticável (task #229): `flutter --version` já não
  cabe no timeout de 45 s.

  ```bash
  ssh cesar@decisaodigital       # via Tailscale MagicDNS (preferido)
  ssh cesar@100.92.206.22         # IP fixo Tailscale (fallback)
  ssh cesar@192.168.1.150         # LAN local (DHCP — pode mudar)
  ```

  Chave SSH ed25519 já autorizada em `~/.ssh/authorized_keys` (chaves
  `cowork-sandbox` e `cd_me@Portatil-CD`). **Sudo sem password.**
  Repos já clonados: `~/punho`, `~/washinvoice-control`. Keystores em
  `~/keystores/` (permissão 600, passwords em `D:\Seguro\`).
  Estado completo do i9 em `D:\Claude\infra\maquina_linux_i9.md`.
- **Self-hosted GitHub Actions runner** — no i9 (plano B quando CI cloud
  falhar, task #234).
- **PC Windows do Cesar** — desenvolvimento visual, smoke manual no
  telemóvel via cabo USB, build do instalador Windows (Inno Setup).
- **Supabase project `oefqbkhioncakojipqyx`** — partilhado com POS e Control
  (multi-app com coluna `app`).

## Releases

Não é apenas criar uma tag. **Ler o
[PROCESSO_DE_RELEASE.md](docs/PROCESSO_DE_RELEASE.md) antes de qualquer
release** — captura lições reais (a v0.0.8 teve 3 falhas até publicar).

Resumo:
1. `workflow_dispatch` verde primeiro (build + testes sem tag).
2. Só depois tag `vX.Y.Z` no commit certo → publica APK Android no GitHub Releases.
3. Só depois de APK público e testado, inserir linha em `versoes_apps`
   do Supabase para os clientes verem o update.

Instalador Windows: `installer/punho_setup.iss` (Inno Setup, local).

## Segurança

- Nunca commitar `.env`, chaves, tokens, keystones ou credenciais.
- Keystore de release: `D:\Seguro\keystores\punho_release.jks` (fora do repo).
  Nos secrets do GitHub Actions: `PUNHO_KEYSTORE_BASE64` (jks em base64) +
  `PUNHO_KEYSTORE_PASSWORD` (password da chave).
- Antes de trabalhar no backend, consultar [Segurança e RLS](docs/SEGURANCA_E_RLS.md).
- Valores públicos em `.env.example` (URL + anon key), nunca a service_role.

Repositório **público** em `github.com/DecisaoDigital/punho`.
Copyright © Decisão Digital. Todos os direitos reservados.

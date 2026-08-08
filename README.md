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
- [Publicar uma versão (runbook)](docs/PUBLICAR_RELEASE.md) ← **ler antes de cortar tag**
- [Smoke antes de anunciar](docs/SMOKE.md)
- [Índice da documentação](docs/README.md)

## Plataformas

- **Android** — plataforma principal e a única publicada. Compilada, assinada e
  verificada no i9; o GitHub só recebe o APK já pronto.
- **Windows** — suportado para desenvolvimento e builds locais; por publicar,
  falta o worker Windows no i9.
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
- Antes de anunciar uma versão: **smoke no aparelho** ([SMOKE.md](docs/SMOKE.md)).
- Ver [PUBLICAR_RELEASE.md](docs/PUBLICAR_RELEASE.md) para a sequência exacta
  de release (bump → analyze → testes → APK verificado → tag → Release → smoke
  → catálogo).

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
- **GitHub Actions** — se existir, só para verificação (`flutter analyze` e
  `flutter test`). Nunca compila, assina ou publica: o APK sai sempre do i9.
  Ver [AGENTS.md](AGENTS.md). *(workflow de verificação ainda por criar.)*
- **PC Windows do Cesar** — desenvolvimento visual, smoke manual no
  telemóvel via cabo USB, build do instalador Windows (Inno Setup).
- **Supabase project `oefqbkhioncakojipqyx`** — partilhado com POS e Control
  (multi-app com coluna `app`).

## Releases

Não é apenas criar uma tag. **Ler o
[PUBLICAR_RELEASE.md](docs/PUBLICAR_RELEASE.md) antes de qualquer release** —
captura lições reais (a v0.0.8 teve 3 falhas até publicar).

Resumo:
1. Ensaio primeiro, que não deixa rasto:
   `./scripts/release.sh X.Y.Z --ensaio`
2. `./scripts/release.sh X.Y.Z --yes` — analyze, testes, APK assinado e
   verificado, commit, tag e GitHub Release. **Pára aqui de propósito.**
3. Instalar o APK no aparelho e correr o [SMOKE.md](docs/SMOKE.md).
4. Só então anunciar aos telemóveis que já têm a app:
   `./scripts/update-release-catalog.sh X.Y.Z <build>`

Publicar o APK e anunciá-lo são dois comandos separados porque são duas
decisões separadas: entre eles está o smoke. Enquanto o passo 4 não correr,
ninguém recebe a actualização — e não há nada para desfazer.

Instalador Windows: `installer/punho_setup.iss` (Inno Setup, local).

## Segurança

- Nunca commitar `.env`, chaves, tokens, keystones ou credenciais.
- Keystore de release: `~/keystores/punho_release.jks` no i9 (permissão 600,
  fora do repo; cópia em `D:\Seguro\keystores\`). **Não existem secrets de
  keystore no GitHub**, e não devem passar a existir: o GitHub não assina nada.
  Perder esta chave significa não voltar a poder actualizar a app instalada.
- Antes de trabalhar no backend, consultar [Segurança e RLS](docs/SEGURANCA_E_RLS.md).
- Valores públicos em `.env.example` (URL + anon key), nunca a service_role.

Repositório **público** em `github.com/DecisaoDigital/punho`.
Copyright © Decisão Digital. Todos os direitos reservados.

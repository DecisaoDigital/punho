# Processo de release — Punho

Runbook para cortar uma nova versão do Punho (Android). **Ler inteiro antes de
começar.** Escrito com as lições da v0.0.10 (tag no commit errado, assinatura
em falta, testes de UI desactualizados, catálogo Supabase anunciado antes da
APK existir).

---

## Lições aprendidas (não repetir)

1. **A tag tem de nascer no commit certo.** Não herda correcções de outras
   branches: se o fix crítico está em `feat/x` e ainda não fez merge para
   `main`, a tag `vX.Y.Z` em `main` **não o inclui**. Faz sempre `git log`
   antes de taggar.
2. **APK de distribuição exige assinatura de release.** Nunca cair para
   assinatura debug em silêncio: o CI passa a bloquear (guard-rail #208+#236).
3. **Testes de UI têm de mudar com a UI antes da tag.** Se mudaste um
   TextField, o widget test / golden associado tem de ser actualizado no
   mesmo commit — senão a tag falha o CI.
4. **`workflow_dispatch` verde primeiro; só depois tag.** Corre o workflow
   em modo dispatch (build + testes sem publicar) para apanhar erros antes
   de queimar uma versão.
5. **Só anunciar update no Supabase depois de existir APK pública testada.**
   `versoes_apps.url_download` só depois de instalar o APK e confirmar que
   arranca.
6. **Uma tag publicada é imutável.** Se saiu bug, é `vX.Y.(Z+1)`, não
   `git tag -f`. O trigger DB (#237) recusa reescrita.
7. **A `v0.0.9` só vê o update porque `versoes_apps` tem build 10 activo
   com URL válido.** Sem essa linha, o auto-update não dispara.

---

## Requisitos antes de arrancar

- `main` com os commits que queres publicar (`git log --oneline` para confirmar).
- Smoke manual do build actual assinado (`docs/SMOKE_v0.0.X_CHECKLIST.md`).
- Keystore e password acessíveis (só necessário para build local; o CI usa secrets).
- PAT GitHub válido (não expirado — vale 60 dias, ver `D:\Seguro\`).

---

## Passo-a-passo

### 1. Bump da versão + release notes

Em `main`:

```powershell
# Bump em pubspec.yaml — X.Y.Z+B (B tem sempre de subir)
# Ex: 0.0.9+9 → 0.0.10+10
git checkout main
git pull

# Editar pubspec.yaml
# Editar/criar docs/release_notes/v0XX.md — curto, título + bullets
```

Commit:

```powershell
git add pubspec.yaml docs/release_notes/v0XX.md
git commit -m "chore(release): bump para X.Y.Z+B"
git push origin main
```

### 2. Dry-run: `workflow_dispatch` verde

No GitHub → Actions → `release.yml` → **Run workflow** → branch `main`.

Este job faz build + testes **sem** publicar release. Objectivo: apanhar
falhas de CI **antes** de queimar uma tag.

- Se falhar: corrige em `main`, commit, repete.
- Se passar: seguir para o passo 3.

### 3. Cortar tag no commit certo

```powershell
git checkout main
git pull
git log -1 --oneline   # confirma que o topo é o commit do bump
git tag vX.Y.Z
git push origin vX.Y.Z
```

Isto dispara o `release.yml` em modo tag → publica APK no GitHub Releases.

Se a tag foi cortada no commit errado (herdou fix que não está em main):

```powershell
git tag -d vX.Y.Z              # local
git push origin :vX.Y.Z        # remoto
# só depois refazer o merge para main + nova tag
```

Nunca `git tag -f` numa tag que já publicou release.

### 4. Verificar release em GitHub

- `https://github.com/DecisaoDigital/punho/releases/tag/vX.Y.Z`
- Confirmar: **3 APKs** (`arm64-v8a`, `armeabi-v7a`, `x86_64`) por causa do
  `--split-per-abi` (#209).
- Descarregar o `arm64-v8a` para um telemóvel real e instalar.

### 5. Smoke da nova versão

Copiar `docs/SMOKE_v0.0.X_CHECKLIST.md`, correr os 9 fluxos, assinar.

**Só passar para o passo 6 se o smoke estiver limpo.**

### 6. Anunciar update no Supabase (`versoes_apps`)

```sql
INSERT INTO public.versoes_apps
  (app, plataforma, versao, build, url_download, notas_lancamento, obrigatorio)
VALUES
  ('punho', 'android', 'X.Y.Z', B,
   'https://github.com/DecisaoDigital/punho/releases/download/vX.Y.Z/app-arm64-v8a-release.apk',
   'Descrição curta do que mudou.',
   false);
```

- `build` tem de ser **> ao actual** activo (se não, apps não vêem update).
- `url_download` **tem de ser um APK que existe** (o trigger #237 valida regex `github.com/.../releases/download/...`).
- Se erro depois disto: **nova versão**, nunca `UPDATE` do registo antigo.

### 7. Verificar auto-update num dispositivo

Abrir o Punho num telemóvel com versão anterior → banner de update aparece →
`Descarregar` → instala → arranca em `vX.Y.Z`.

---

## Onde encontrar as chaves e segredos

| Item | Onde |
|---|---|
| Keystore local (`.jks`) | `D:\Seguro\keystores\punho_release.jks` |
| Password da keystore | `D:\Seguro\Importantes para claude.txt` — linha "Punho keystore password" |
| PAT GitHub (releases) | `D:\Seguro\Importantes para claude.txt` — linha "Cowork Full Access DecisaoDigital" |
| GitHub secret `PUNHO_KEYSTORE_BASE64` | GitHub → Settings → Secrets → Actions (só admin org vê) |
| GitHub secret `PUNHO_KEYSTORE_PASSWORD` | idem |
| Supabase project | `oefqbkhioncakojipqyx` (partilhado com POS + Control) |
| Supabase service_role | Supabase dashboard → Project settings → API |
| FCM service account (push) | `D:\Seguro\` — `fcm-sender-*.json` |

Nunca colocar nenhum destes no repo. `.env.example` só tem `SUPABASE_URL` +
`SUPABASE_ANON_KEY` (públicas — a service_role fica de fora).

---

## GH CI vs i9 — quando usar cada um

**Regra calibrada 2026-08-XX:**

- **GH Actions (`workflow_dispatch` + tag) é o caminho por defeito** para
  releases standard. Workflow bem definido, secrets configurados, `--split-per-abi`
  automático, publicação no Releases automática. Overhead do sandbox Cowork é
  mínimo (1 API call + polling curto). Este é o pipeline documentado nos passos
  1–7 acima e é o que se usa 90 % das vezes.

- **i9 (Home Lab, Ubuntu Server 24.04, SSH via Tailscale) para:**
  - **Debug de builds partidos** — iterar `flutter analyze`/`build` sem esperar
    3–5 min de setup ubuntu-latest cada vez
  - **Hotfixes urgentes** quando CI está com fila ou parcialmente partido
  - **Builds ad-hoc** para inspecção do APK antes de o assinar como release
  - **Testes locais** que não fazem sentido correr no CI

- **PC Windows do Cesar** — reservado ao build do instalador (Inno Setup),
  smoke manual via USB e desenvolvimento visual. Mount NTFS via sandbox
  Cowork é impraticável para Flutter (task #229): `flutter --version` não cabe
  no timeout de 45 s.

Cowork/Claude Code que dispare uma release: **usar GH CI**. Se falhar 2×
seguidas ou o problema exigir logs completos do build, **passar ao i9**.

## Build no i9 (debug e fallback)

Quando cair no i9, os comandos são:

### Passos

```bash
ssh cesar@decisaodigital   # Tailscale MagicDNS; alternativas: 100.92.206.22 (Tailscale fixo) ou 192.168.1.150 (LAN)
cd ~/punho
git pull
flutter build apk --release --split-per-abi \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

# APKs em build/app/outputs/flutter-apk/
# Upload manual para github.com/DecisaoDigital/punho/releases/tag/vX.Y.Z
# (arrastar app-arm64-v8a-release.apk + os outros 2 ABIs)
```

### No PC Windows (só se i9 indisponível — pouco usado)

```powershell
flutter build apk --release --split-per-abi `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY

# Upload manual como acima.
```

---

## Checklist final antes de cortar tag

- [ ] `git log --oneline -5` mostra o commit certo no topo de `main`
- [ ] `pubspec.yaml` com `X.Y.Z+B` (B > build actual)
- [ ] `docs/release_notes/v0XX.md` existe e é curto
- [ ] `docs/SMOKE_v0.0.X_CHECKLIST.md` assinado
- [ ] `workflow_dispatch` verde em `release.yml`
- [ ] Tag apontada ao commit do bump
- [ ] APK descarregado, instalado, arranca
- [ ] Só agora `INSERT INTO versoes_apps`

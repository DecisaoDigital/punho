# Punho — contexto para Cowork / Claude Code

## Máquina de trabalho preferida: i9 (Home Lab)

Para builds Flutter, `flutter analyze`, `flutter test`, produção de APK
assinado, correr scripts que demoram — **usar o i9 por SSH via Tailscale**.

O mount NTFS via sandbox Cowork é impraticável (task #229): I/O demasiado
lento para `flutter --version` caber no timeout de 45s. Trabalhar no i9
resolve isto de forma estrutural.

### Como fazer login

```bash
ssh cesar@decisaodigital       # via Tailscale MagicDNS (preferido)
ssh cesar@100.92.206.22         # IP fixo Tailscale (fallback)
ssh cesar@192.168.1.150         # LAN local (DHCP — pode mudar)
```

- **Utilizador:** `cesar`
- **Chave SSH:** ed25519 já autorizada em `~/.ssh/authorized_keys`
  (identidades `cowork-sandbox` e `cd_me@Portatil-CD`) — sem password
- **Sudo:** sem password (`/etc/sudoers.d/cesar-nopasswd`)
- **Repos já clonados:** `~/punho`, `~/washinvoice-control`
- **Keystores:** `~/keystores/{punho,control}_release.jks` (permissão 600;
  passwords em `D:\Seguro\Importantes para claude.txt`)

Estado detalhado do i9 (hardware, software instalado, monitorização,
credenciais, roadmap): `D:\Claude\infra\maquina_linux_i9.md`.

O GitHub não compila, não assina e não publica nada (ver `AGENTS.md`). Um
workflow só de verificação — `analyze` e `test` — é permitido; o portão
continua a ser o i9.

## Antes de qualquer release

- Ler `docs/PUBLICAR_RELEASE.md` completo — é o runbook único
- Ensaiar primeiro: `./scripts/release.sh X.Y.Z --ensaio` (não deixa rasto)
- **Publicar e anunciar são dois comandos.** O `release.sh` cria a Release e
  pára; quem faz a versão chegar aos telemóveis é o
  `./scripts/update-release-catalog.sh`. Entre os dois corre-se o
  `docs/SMOKE.md` no aparelho
- As 7 lições da v0.0.10 estão em `docs/PROCESSO_DE_RELEASE.md` — não repetir

## Regras gerais Cowork

Ver `D:\Claude\CLAUDE.md` para regras transversais de operação com o Cesar
(postura fundamental, escolha de ferramentas, calibração de auditoria,
agentes em paralelo, segurança, ferramentas para ganhar ferramentas).

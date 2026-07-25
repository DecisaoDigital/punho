# Punho

Aplicação Flutter multi-plataforma (Android + Windows) desenvolvida pela **Decisão Digital**.

> _Descrição funcional a preencher._

## Plataformas alvo

- **Android** — APK auto-actualizável via GitHub Releases
- **Windows** — instalador Inno Setup (`Punho_Setup_vX.Y.Z.exe`) com auto-update
- iOS — **suspenso até nova ordem**

## Requisitos

- Flutter 3.24+ (canal stable)
- Dart 3.5+
- Android SDK 34 / Visual Studio 2022 (Desktop C++ workload)
- Inno Setup 6 (para gerar o instalador Windows localmente)

## Desenvolvimento

```bash
flutter pub get
flutter run                    # dispositivo/emulador conectado
flutter run -d windows         # Windows desktop
```

Configuração local: cria `.env` na raiz com `SUPABASE_URL` e `SUPABASE_ANON_KEY` (nunca commitado — `.gitignore` já cobre).

## Testes

```bash
flutter test
flutter analyze
```

## Releases

Publicação automática via GitHub Actions (`.github/workflows/release.yml`) quando é criada uma tag `vX.Y.Z`. Gera:

- `punho-android-vX.Y.Z.apk`
- `Punho_Setup_vX.Y.Z.exe` (installer Inno)

O auto-update dentro da app consulta a Edge Function `versao-mais-recente` do Supabase do Control e apresenta banner com botão de descarga.

## Licenciamento

Copyright © Decisão Digital. Todos os direitos reservados. Ver `LICENSE`.

## Suporte

`cesarmendes78@gmail.com`

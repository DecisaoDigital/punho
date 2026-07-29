# Distribuição Windows e Android

## Android: checklist de uma release publicável

1. Confirmar no `pubspec.yaml` a versão e o `build number` seguintes.
2. Confirmar que a branch a etiquetar contém a configuração de assinatura
   (`android/app/build.gradle.kts`) e o workflow de release. Uma tag não herda
   commits que existem apenas noutra branch.
3. No GitHub, confirmar os segredos `PUNHO_KEYSTORE_BASE64`,
   `PUNHO_KEYSTORE_PASSWORD`, `SUPABASE_URL` e `SUPABASE_ANON_KEY`.
4. Criar e enviar a tag `vX.Y.Z`. O workflow falha se a assinatura estiver em
   falta; não é permitido publicar um APK assinado com a chave de depuração.
5. Confirmar na GitHub Release o APK gerado e descarregá-lo para um teste num
   Android real antes de o anunciar.
6. Só depois inserir/ativar no catálogo `versoes_apps` a linha
   `app='punho'`, `plataforma='android'`, `build_number` superior e o URL
   exato do APK. Esta linha é o que faz instalações anteriores verem o aviso.

O keystore e `android/key.properties` são secretos e estão ignorados pelo Git.
O CI reconstrói-os apenas durante a release a partir dos segredos; nunca os
adicionar ao repositório, a um `.md` ou a um arquivo de partilha.

Para uma build local de release, criar `android/key.properties` fora do Git com
`storeFile`, `storePassword`, `keyAlias` e `keyPassword` da chave segura. Sem
esse ficheiro, `flutter build apk --release` falha deliberadamente.

Windows: `flutter build windows`; o executável fica em `build/windows/x64/runner/Release/punho.exe`.

Android: `flutter build apk --debug`; instalar com `adb install build/app/outputs/flutter-apk/app-debug.apk` ou transferir o APK para o dispositivo e permitir instalação da origem escolhida.

O projeto iOS exige macOS e Xcode para compilação e assinatura. Não é possível gerar IPA neste Windows.

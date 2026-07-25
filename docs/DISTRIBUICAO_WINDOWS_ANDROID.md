# Distribuição Windows e Android

Windows: `flutter build windows`; o executável fica em `build/windows/x64/runner/Release/punho.exe`.

Android: `flutter build apk --debug`; instalar com `adb install build/app/outputs/flutter-apk/app-debug.apk` ou transferir o APK para o dispositivo e permitir instalação da origem escolhida.

O projeto iOS exige macOS e Xcode para compilação e assinatura. Não é possível gerar IPA neste Windows.

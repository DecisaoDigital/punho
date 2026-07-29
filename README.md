# Punho

Aplicação Flutter multi-plataforma (Android + Windows) desenvolvida pela **Decisão Digital**.

> _Descrição funcional a preencher._

## Regra obrigatória de trabalho

Antes de alterar código, leia [AGENTS.md](AGENTS.md).

O repositório de trabalho oficial está no servidor i9:

```text
Máquina: home-lab-claude
Repositório: /home/cesar/punho
Acesso: ssh cesar@home-lab-claude
```

Todo o código, gestão de branches, commits, instalação de dependências, análise,
testes, compilações e validação de artefactos é feito nesse servidor.

O GitHub só recebe código e binários depois de todas as validações ficarem
verdes no i9. **GitHub Actions não é usado para analisar, testar, compilar,
assinar ou gerar artefactos do Punho.**

## Plataformas alvo

- **Android** — APK assinado e compilado no i9; GitHub Releases serve apenas
  para distribuição;
- **Windows** — instalador Inno Setup compilado num ambiente Windows alojado no
  i9; nunca usar GitHub Actions como substituto;
- iOS — **suspenso até nova ordem**.

## Requisitos

- servidor i9 `home-lab-claude`;
- Flutter 3.24+ (canal stable);
- Dart 3.5+;
- Android SDK e JDK instalados no i9;
- ambiente Windows no i9 com Visual Studio 2022 e Inno Setup 6, quando for
  necessário gerar o instalador Windows.

## Desenvolvimento

```bash
ssh cesar@home-lab-claude
cd ~/punho
flutter pub get
flutter run
```

A configuração Supabase e a chave de assinatura são carregadas apenas a partir
dos ficheiros/segredos locais protegidos do servidor. Nunca são escritas no
código, nos logs ou num commit. Os caminhos autorizados e a forma de validar as
sessões Supabase/GitHub estão documentados em [AGENTS.md](AGENTS.md).

## Validação obrigatória

No i9, antes de qualquer push:

```bash
flutter pub get
flutter analyze
flutter test --exclude-tags=screenshot
git diff --check
```

Além destes comandos, têm de ser compilados e verificados localmente no i9 os
artefactos das plataformas afetadas. Um push para o GitHub nunca pode ser usado
como ensaio.

## Releases

A compilação e assinatura acontecem primeiro no i9. Só depois de os testes e os
artefactos estarem verdes é permitido:

1. criar o commit no i9;
2. enviar o código para o GitHub;
3. criar a tag/release;
4. carregar para a release os binários já compilados e verificados no i9;
5. atualizar o catálogo de versões.

O GitHub funciona como repositório remoto e canal de distribuição, não como
máquina de compilação. Consulte [docs/PUBLICAR_RELEASE.md](docs/PUBLICAR_RELEASE.md).

## Licenciamento

Copyright © Decisão Digital. Todos os direitos reservados. Ver `LICENSE`.

## Suporte

`cesarmendes78@gmail.com`

# Publicar uma nova versão do Punho

As releases são iniciadas no servidor `home-lab-claude`. O comando de release
faz o aumento do build, valida o projeto, publica Android e Windows no GitHub e
atualiza o catálogo Supabase.

## Publicação normal

```bash
ssh cesar@home-lab-claude
cd ~/punho
./scripts/release.sh 0.0.10 --yes
```

Substitua `0.0.10` pela nova versão. O `build_number` é sempre incrementado a
partir do valor atual do `pubspec.yaml`; não é necessário indicá-lo.

O comando recusa publicar quando:

- a branch não é `main`;
- existem alterações locais;
- a `main` local não coincide com o GitHub;
- a versão não é superior à atual;
- a tag ou a release já existem;
- GitHub ou Supabase não estão autenticados;
- a análise, os testes, a compilação ou a assinatura falham;
- o catálogo não reconhece corretamente a versão anterior e a nova.

## O que é publicado

- `Punho_vX.Y.Z_universal.apk`: instalador Android recomendado e usado pelo
  aviso automático;
- três APKs Android separados por arquitetura;
- `Punho_Setup_vX.Y.Z.exe`: instalador Windows;
- release pública `vX.Y.Z` no GitHub;
- linhas Android e Windows ativas em `versoes_apps`.

O workflow falha se o APK não estiver assinado pelo certificado definitivo:

```text
SHA-256 33386ff0dd95bb57818aaabc32b37e378da9febb1fb905b2388c4b5aa0f70205
```

Nunca deve ser criada outra keystore para uma atualização do Punho.

## Se o workflow falhar

O comando mostra o endereço da execução GitHub Actions e termina com erro. Não
crie outra tag com a mesma versão. Corrija a causa e volte a executar a mesma
execução no GitHub:

```bash
gh run rerun RUN_ID --repo DecisaoDigital/punho --failed
gh run watch RUN_ID --repo DecisaoDigital/punho --exit-status
```

Depois de a release ficar concluída, execute novamente apenas a atualização do
catálogo:

```bash
./scripts/update-release-catalog.sh 0.0.10 10
```

Indique a versão e o `build_number` que ficaram no `pubspec.yaml`. A operação é
idempotente: pode ser repetida e não cria versões duplicadas.

# Publicar uma nova versão do Punho

## Regra inegociável

Código, branches, commits, dependências, análise, testes, compilações, assinatura
e validação de artefactos são feitos no servidor i9 `decisaodigital`, dentro de
`/home/cesar/punho`.

O GitHub só recebe o código e os binários depois de tudo ficar verde no i9.
**Não usar GitHub Actions para compilar, assinar ou gerar APKs e instaladores.**

Verificar é outra coisa. `.github/workflows/verificar.yml` corre `flutter pub
get`, `flutter analyze` e `flutter test` em cada push e PR — não compila, não
assina, não publica, e não produz nenhum artefacto que chegue a um cliente. É
uma segunda opinião sobre código que já passou no i9, não um caminho
alternativo para publicar. O portão continua a ser o i9: uma CI verde não
autoriza uma release, e uma CI vermelha é motivo para parar.

## Credenciais no i9

Não colocar passwords nem tokens no repositório.

- **Supabase:** usar `SUPABASE_ACCESS_TOKEN`, já presente no ambiente das
  sessões SSH do i9. Confirmar com `supabase projects list`, sem imprimir o
  valor. Se for necessário recuperar a credencial, a fonte autorizada está em
  `D:\Seguro\Importante_gpt\Importante_Gpt.txt`, fora do repositório.
- **GitHub:** usar a sessão autenticada do `gh` no i9 e confirmar com
  `gh auth status`. A credencial é gerida pela CLI em
  `/home/cesar/.config/gh/hosts.yml`; não abrir nem copiar esse ficheiro.

Se uma sessão expirar, renovar a autenticação no i9. Nunca escrever tokens em
comandos que fiquem no histórico, logs, documentação ou commits.

## O mecanismo antigo já não existe

O `.github/workflows/release.yml`, que compilava e assinava no GitHub, foi
removido a 3 de Agosto de 2026 (commit `65fae4e`). O `scripts/release.sh` **é**
hoje o caminho de publicação, e faz tudo no i9.

Continua a valer, e não por inércia:

- não usar um push ou uma tag para descobrir se o projecto compila;
- não publicar uma versão sem os binários finais já existirem e terem sido
  verificados no i9;
- não devolver ao GitHub a compilação nem a assinatura — as chaves não saem do
  i9.

## Publicar e anunciar são dois comandos

É a regra que estrutura tudo o resto, e existe porque estiveram colados:

| Comando | O que faz | Quem é afectado |
| --- | --- | --- |
| `scripts/release.sh` | commit, tag, GitHub Release com o APK | ninguém — o APK fica à espera de quem o vá buscar |
| `scripts/update-release-catalog.sh` | activa a versão em `versoes_apps` | **todos os telemóveis**, por auto-update |

Entre um e outro está o [SMOKE.md](SMOKE.md). Um APK que compila, está assinado
e tem os defines mas rebenta ao arrancar passa as duas primeiras fases sem uma
queixa — e só o smoke o apanha antes de ser tarde. Depois do segundo comando,
reverter é SQL à mão com o cliente já parado.

Ensaio antes, que não deixa rasto nenhum:

```bash
./scripts/release.sh X.Y.Z --ensaio
```

## Sequência obrigatória

### 1. Entrar no servidor e sincronizar

```bash
ssh cesar@decisaodigital
cd ~/punho
git status --short --branch
git fetch origin
git switch main
git pull --ff-only origin main
```

Não começar com alterações locais desconhecidas nem trabalhar numa cópia do
repositório fora do i9.

### 2. Alterar e validar no i9

Todo o trabalho de código é realizado no i9. Antes do commit:

```bash
flutter pub get
flutter analyze
flutter test --exclude-tags=screenshot
git diff --check
```

Também é obrigatório compilar, no i9, todas as plataformas afetadas e verificar
os artefactos resultantes. A compilação tem de usar a configuração Supabase e a
keystore definitiva guardadas no servidor, sem revelar segredos em logs.

Para Android, gerar no i9:

- `Punho_vX.Y.Z_universal.apk`, usado pelo atualizador;
- os APKs por arquitetura, se continuarem a fazer parte da release.

Confirmar antes do commit:

- package `pt.decisaodigital.punho`;
- `versionName` e `versionCode` esperados;
- certificado SHA-256 definitivo:
  `33386ff0dd95bb57818aaabc32b37e378da9febb1fb905b2388c4b5aa0f70205`;
- presença da configuração Supabase no binário;
- instalação e arranque num dispositivo de teste quando a alteração justificar.

Nunca criar outra keystore para uma atualização do Punho.

**A versão a seguir à 0.2.1 não se instala por cima da anterior.** A 4 de
Agosto de 2026 o `applicationId` passou de `com.example.punho` (o placeholder
do template, que a Google Play recusa) para `pt.decisaodigital.punho`. Para o
Android são duas apps diferentes: quem tiver a 0.2.1 instalada fica com as
duas lado a lado até desinstalar a antiga, e o atualizador embutido da 0.2.1
não consegue saltar esta ponte — a passagem é manual, uma vez. Os dados locais
do aparelho antigo perdem-se; os do servidor não. Depois disto o
`applicationId` não volta a mudar.

### 3. Windows também pertence ao i9

O Ubuntu não compila nativamente o executável Flutter para Windows. A solução
correta é usar uma VM ou worker Windows alojado no próprio i9, com Visual Studio
e Inno Setup.

Se esse ambiente ainda não estiver disponível, a publicação Windows fica
bloqueada até ser configurado. **GitHub Actions não é alternativa.**

### 4. Commit no i9

Só depois de análise, testes, compilações e verificações verdes:

```bash
git status --short
git diff
git add <apenas-os-ficheiros-da-alteração>
git commit -m "<descrição objetiva>"
```

O commit tem de representar exatamente a árvore que foi testada e compilada.

### 5. Enviar para o GitHub

Depois do commit verde:

```bash
git push -u origin <branch>
```

Se for usado pull request, este serve para revisão e integração. Não serve para
delegar testes ou compilações ao GitHub.

### 6. Criar a release com artefactos do i9

Depois de o commit estar integrado e apenas quando os binários finais já tiverem
sido produzidos e validados no i9:

1. criar a tag no i9;
2. enviar a tag;
3. criar a GitHub Release;
4. carregar com `gh` os APKs e o instalador já existentes.

É tudo isto que o `./scripts/release.sh X.Y.Z --yes` faz de uma vez. E acaba
aqui: o script imprime o que falta e **não** anuncia nada.

O GitHub armazena e distribui os ficheiros. Não os constrói.

### 7. Smoke no aparelho

```bash
adb install -r dist/punho-android-vX.Y.Z.apk
```

Correr os dez pontos do [SMOKE.md](SMOKE.md). Instalar por cima da versão
anterior, não numa app limpa.

### 8. Anunciar

Só com o smoke todo verde:

```bash
./scripts/update-release-catalog.sh X.Y.Z <build>
```

É este comando, e só este, que faz a versão aparecer nos telemóveis. Pode ser
repetido sem risco: se a linha já existir, actualiza o que é mutável em vez de
rebentar.

## Regra de paragem

Se qualquer análise, teste, compilação, assinatura ou verificação falhar:

- não fazer push;
- não criar tag;
- não criar release;
- corrigir e repetir todo o gate relevante no i9.

Uma execução verde no i9 é condição obrigatória para o código subir ao GitHub.

E a paragem que interessa mais, porque é a única depois de o código já estar
público: **se o smoke falhar, não correr o passo 8.** Não há nada para desfazer
— a release fica no GitHub sem ninguém a receber. Corrige-se e publica-se
`X.Y.(Z+1)`. Nunca mover uma tag publicada.

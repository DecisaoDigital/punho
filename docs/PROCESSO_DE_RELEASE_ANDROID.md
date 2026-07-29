# Processo de release Android

Este é o procedimento obrigatório para publicar uma versão do Punho e fazê-la
aparecer como atualização nas instalações anteriores. A sequência existe para
evitar publicar uma tag errada, uma APK não assinada ou um aviso de atualização
sem ficheiro para descarregar.

## O que correu mal na v0.0.10

1. A tag foi criada numa branch que não continha a configuração de assinatura
   Android. Essa configuração existia na `main`, mas uma tag só contém os
   commits alcançáveis a partir do commit que ela aponta.
2. O workflow permitia continuar sem keystore e assinar uma release com a chave
   de depuração. Esse fallback era inadequado para distribuição.
3. Dois testes de widget continuavam a procurar textos da interface anterior.
   O erro só foi descoberto no CI, depois de a tag já existir.
4. A tag foi movida durante a recuperação porque ainda não havia release
   publicada. Isto é excecional; uma tag publicada não deve ser reescrita.

As correções permanentes são: release sem assinatura falha, o workflow confirma
os testes antes de construir a APK, e esta documentação torna a ordem explícita.

## Regra de ouro

**Não criar nem enviar a tag antes de o commit de release estar pronto, testado
e enviado na branch certa.** Se for necessário corrigir algo depois de uma
release publicada, criar a versão seguinte; não mover a tag anterior.

## Pré-validação local

Na branch que será publicada:

```powershell
git status --short
git log -1 --oneline
flutter analyze
flutter test --exclude-tags=screenshot
```

O `git status` deve estar limpo para os ficheiros da release. Alterações de
outras pessoas não devem ser incluídas sem confirmação. Corrigir qualquer teste
de interface na mesma alteração que muda o texto, estrutura ou semântica do
ecrã.

Confirmar também a versão:

```powershell
Select-String -Path pubspec.yaml -Pattern '^version:'
```

O `build number` tem de ser superior ao que está ativo em
`versoes_apps` para Android.

## Assinatura

O keystore e as palavras-passe nunca são versionados. O Git ignora
`android/key.properties`, `*.jks` e `*.keystore`.

No repositório GitHub devem existir estes segredos:

- `PUNHO_KEYSTORE_BASE64`
- `PUNHO_KEYSTORE_PASSWORD`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

O workflow reconstrói o keystore temporariamente no runner. Se faltar um dos
segredos da assinatura, a release tem de falhar; nunca substituir a chave de
release pela chave de depuração.

Para uma build local de release é preciso obter a chave pelo canal seguro e
criar `android/key.properties` localmente. Não colocar esse ficheiro no Git,
nem em documentação, mensagens ou arquivos.

## Publicar sem surpresas

1. Enviar todos os commits de release para a branch pretendida.
2. Executar primeiro o workflow manual (`workflow_dispatch`). Ele compila e
   testa, mas não publica uma release. Só avançar se ficar verde.
3. Criar a tag no commit já validado e enviá-la:

```powershell
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```

4. Acompanhar o workflow `Release Punho`. A ordem correta é: reconstruir o
   keystore, dependências, testes, build da APK, upload do artefacto e GitHub
   Release.
5. Confirmar na release publicada o nome, tamanho e URL da APK. Instalar a APK
   num Android físico antes de a anunciar aos utilizadores.

Se qualquer passo falhar antes de a release existir, corrigir o commit e criar
uma nova tag apenas se a tag já estiver visível fora da equipa. Não forçar tags
publicadas.

## Anunciar atualização no catálogo

Só depois de a APK estar publicamente disponível, inserir a versão no catálogo
remoto. O registo precisa de `app='punho'`, `plataforma='android'`, versão,
`build_number`, URL da APK, notas simples e `activa=true`. A versão Android
anterior deve deixar de estar ativa.

Verificar após a escrita:

```sql
select versao, build_number, url_download, obrigatoria, activa
from public.versoes_apps
where app = 'punho' and plataforma = 'android'
order by build_number desc;
```

## Teste de atualização real

1. Num Android com uma versão anterior, confirmar ligação à internet e
   configuração Supabase.
2. Fechar totalmente e reabrir o Punho. A verificação ocorre no arranque; a
   app volta a consultar o catálogo a cada 24 horas.
3. Confirmar o aviso com a versão e as notas de lançamento.
4. Abrir o botão de atualização e confirmar que o URL descarrega a APK correta.
5. Instalar a APK e confirmar no Perfil a nova versão.

Uma atualização obrigatória só é usada para segurança ou integridade. Para
melhorias normais, como a v0.0.10, manter `obrigatoria=false`.

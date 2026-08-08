# Processo de release Android

> **Este documento já não é o procedimento.**
> O runbook único é **[PUBLICAR_RELEASE.md](PUBLICAR_RELEASE.md)**.
>
> A sequência que aqui estava assumia um workflow de GitHub Actions que já não
> existe (removido em `65fae4e`). Fica o relato do incidente, que é a razão de
> ser de metade das verificações do `scripts/release.sh` — apagá-lo era perder
> o porquê e ficar só com o quê.

---

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

## O que ficou no lugar do workflow

Cada um dos quatro pontos acima tem hoje uma verificação em
`scripts/release.sh`, e é por isso que o script é longo:

| Incidente | O que hoje o impede |
| --- | --- |
| Tag num commit sem a assinatura | recusa se `main` local ≠ `origin/main` |
| APK assinado a debug | compara o SHA-256 do certificado com o da keystore |
| Testes desactualizados só vistos no CI | `flutter analyze` e `flutter test` antes de tocar no git |
| Tag movida | a tag e a release são verificadas como inexistentes antes de arrancar |

E uma quinta, que não veio da v0.0.10 mas da v0.2.1: **constrói-se antes de
empurrar seja o que for.** Nessa versão o script empurrou o commit e a tag e só
depois foi compilar; o build falhou e ficou uma tag publicada sem release
nenhuma por trás.

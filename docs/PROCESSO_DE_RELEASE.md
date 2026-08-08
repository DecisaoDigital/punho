# Processo de release — Punho

> **Este documento já não é o procedimento.**
> O runbook único é **[PUBLICAR_RELEASE.md](PUBLICAR_RELEASE.md)**.
>
> O que aqui estava descrevia um pipeline de GitHub Actions
> (`workflow_dispatch`, secrets de keystore, publicação automática) que foi
> removido a 3 de Agosto de 2026 no commit `65fae4e`. Ficou aqui a dar ordens
> que já não podiam ser cumpridas — e, pior, a contradizer o `AGENTS.md`, que
> proíbe o GitHub compilar ou assinar. Quem seguisse este ficheiro ia bater
> numa parede.
>
> Ficam só as lições, que continuam verdadeiras e custaram versões a aprender.

---

## Lições aprendidas (não repetir)

1. **A tag tem de nascer no commit certo.** Não herda correcções de outras
   branches: se o fix crítico está em `feat/x` e ainda não fez merge para
   `main`, a tag `vX.Y.Z` em `main` **não o inclui**. Faz sempre `git log`
   antes de taggar. *(Hoje o `release.sh` recusa arrancar se `main` local não
   coincidir com `origin/main`.)*
2. **APK de distribuição exige assinatura de release.** Nunca cair para
   assinatura debug em silêncio. *(Hoje o `release.sh` compara o SHA-256 do
   certificado com o da keystore definitiva e morre se não bater certo.)*
3. **Testes de UI têm de mudar com a UI antes da tag.** Se mudaste um
   `TextField`, o widget test associado tem de ser actualizado no mesmo commit.
4. **Ensaio verde primeiro; só depois a publicação a sério.** Era
   `workflow_dispatch`; hoje é `./scripts/release.sh X.Y.Z --ensaio`, que corre
   analyze, testes, build e as verificações do APK sem commit, sem tag, sem
   push e sem release.
5. **Só anunciar o update no Supabase depois de existir um APK público e
   testado.** É por isto que anunciar deixou de fazer parte do `release.sh` e
   passou a ser um comando à parte — ver a secção "Regra de paragem" no
   runbook.
6. **Uma tag publicada é imutável.** Se saiu bug, é `vX.Y.(Z+1)`, não
   `git tag -f`. O gatilho `trg_versoes_apps_release_integrity` recusa a
   reescrita do lado da base de dados.
7. **O catálogo é que faz o update existir.** Sem a linha activa em
   `versoes_apps` com URL e `sha256` válidos, o auto-update não dispara e
   ninguém recebe nada — e nada no ecrã o denuncia.

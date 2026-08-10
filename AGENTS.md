# Regras obrigatórias para trabalhar no Punho

Este ficheiro aplica-se a todo o repositório.

## Fonte de verdade

- Máquina de trabalho: `decisaodigital` (servidor i9 Ubuntu).
- Repositório: `/home/cesar/punho`.
- Acesso normal: `ssh cesar@decisaodigital`.

Não desenvolver, testar, compilar ou criar commits numa cópia local alternativa.
O i9 é a única árvore de trabalho oficial.

## GitHub não é uma máquina de compilação

É proibido usar GitHub Actions ou runners GitHub para:

- compilar Android ou Windows;
- assinar APKs;
- gerar, validar ou publicar artefactos de release.

Também é proibido fazer push para “ver se passa”. O GitHub só recebe código que
já passou no i9 e binários que já foram produzidos e verificados no i9.

**O que é permitido:** um workflow que corra apenas `flutter pub get`,
`flutter analyze` e `flutter test`. Não compila, não assina, não publica e não
toca em keystores nem em secrets. Não é o portão — o portão continua a ser o
i9 —, é uma segunda opinião que apanha o commit que subiu sem alguém ter
corrido a suite. Hoje os 960 testes só correm quando se arranca uma publicação,
que é o pior momento possível para descobrir que estão vermelhos.

O GitHub é usado apenas para:

- repositório remoto e histórico;
- revisão/integração de código já verde;
- tags e release notes;
- armazenamento e distribuição de artefactos já compilados no i9.

## Nenhuma alteração em produção sem migration no repositório primeiro

Ordem obrigatória, sem excepção: **escrever o ficheiro em
`supabase/migrations/` e só depois aplicar**. Nunca ao contrário, nunca só um
dos dois.

Vale para tudo o que muda o servidor: tabelas, colunas, políticas RLS, `grant`
e `revoke`, funções, triggers, vistas. Aplicar por SQL solto — pelo editor do
Supabase, pelo MCP, por `psql` — é a mesma coisa que não aplicar: fica no
servidor e desaparece do repositório na primeira vez que alguém for procurar.

Foi assim que se perdeu o guard-rail #236 e é por isso que o repositório tinha
58 migrations para 96 versões aplicadas na base. Um `revoke` que ninguém sabe
que existe é indistinguível de um `revoke` que nunca foi feito.

Se encontrares deriva entre o repositório e a produção, reconcilia — não
dupliques. Quando um `supabase db pull` gerar um ficheiro que repete uma
migration escrita à mão, **fica com a escrita à mão e descarta a gerada**: os
comentários dela explicam porquê, e é isso que se perde.

## Credenciais: onde procurar

Usar primeiro as sessões já configuradas no i9. Os agentes não devem pedir,
copiar ou mostrar um token quando a CLI já está autenticada.

### Supabase

- No i9, o token está disponível na variável de ambiente
  `SUPABASE_ACCESS_TOKEN` das sessões SSH.
- Confirmar o acesso com `supabase projects list`; nunca imprimir a variável.
- Se o ambiente perder a credencial, a cópia de recuperação autorizada está
  fora do repositório, em
  `D:\Seguro\Importante_gpt\Importante_Gpt.txt`.
- O valor desse ficheiro nunca pode ser copiado para código, Markdown, logs,
  commits, issues ou mensagens.

### GitHub

- No i9, usar a sessão já autenticada do `gh`.
- Confirmar com `gh auth status`.
- A CLI lê a credencial protegida de `/home/cesar/.config/gh/hosts.yml`.
- Os agentes não devem abrir, imprimir, copiar ou editar manualmente
  `hosts.yml`; devem deixar o `gh` gerir a autenticação.
- Se a sessão expirar, usar `gh auth login` no i9 ou pedir ao proprietário que
  a renove. Nunca guardar o token no repositório.

Uma chave `anon`/publishable da aplicação não substitui o PAT da CLI. Uma chave
`service_role` também não deve ser usada como login de agente.

## Fluxo obrigatório

1. Entrar por SSH no i9 e trabalhar em `/home/cesar/punho`.
2. Confirmar branch, sincronização e working tree antes de alterar.
3. Fazer todas as alterações no i9.
4. Executar no i9:
   - `flutter pub get`;
   - `flutter analyze`;
   - `flutter test --exclude-tags=screenshot`;
   - `git diff --check`;
   - as compilações locais das plataformas afetadas.
5. Verificar versão, package, assinatura e configuração dos binários.
6. Só com tudo verde, criar o commit no i9.
7. Só depois, enviar branch/commit para o GitHub.
8. Numa release, carregar para o GitHub apenas artefactos já compilados no i9.

## Uma sessão por fase

Escrito a 10 de Agosto de 2026, depois de três sessões terem trabalhado em
paralelo sobre a mesma árvore e nenhuma ter feito commit. O `origin/main`
ficou oito commits atrás do que existia em disco, dois trabalhos diferentes
misturaram-se nos mesmos ficheiros, e foi preciso uma sessão inteira só para
os separar — sem que ninguém já se lembrasse ao certo do que era de quem.

As regras que saíram daí:

1. **Uma sessão por fase, nunca uma sessão para tudo.** Uma fase é uma
   unidade de trabalho com um fim reconhecível. Quando ela acaba, a sessão
   acaba — não se aproveita o contexto quente para começar a seguinte.

2. **Cada fase fecha com `docs/HANDOVER_<fase>.md`**, com três partes e as
   três obrigatórias:
   - **o que fez** — o que mudou e porquê, ao nível de quem vai continuar;
   - **o que ficou por fazer** — incluindo o que foi decidido deixar de fora;
   - **o que descobriu pelo caminho** — o que ninguém sabia quando a fase
     começou. É esta a parte que mais se perde e a que mais custa redescobrir.

3. **A fase seguinte começa em sessão nova, a partir desse ficheiro.** Se o
   handover não chega para arrancar, o handover é que está mal escrito — a
   correcção é melhorá-lo, não recorrer à memória da sessão anterior.

4. **Cada fase fecha com o fluxo percorrido à mão, no telemóvel, nos dois
   perfis** — gestor e operador. `flutter test` verde não é isto e nunca foi:
   os testes provam o que a app faz, o percurso à mão mostra o que ela deixa
   fazer. Um bug encontrado assim vale mais do que dez testes a passar.

5. **Nenhuma fase termina com trabalho por committar.** O trabalho de uma
   sessão vive no `git`, não na árvore. Commits atómicos por assunto, e a
   branch empurrada antes de a sessão fechar.

O exemplo está em `docs/HANDOVER_FASE_C.md`.

## Windows

Para Windows, usar uma VM ou worker Windows alojado no i9. Se não existir,
parar e pedir que esse ambiente seja configurado. Nunca usar GitHub Actions como
atalho.

## Mecanismo antigo

`.github/workflows/release.yml` e a versão atual de `scripts/release.sh` ainda
dependem de compilação no GitHub Actions. Não os executar para publicar até
serem migrados para o fluxo integral no i9.

Leia também:

- `README.md`;
- `docs/PUBLICAR_RELEASE.md`.

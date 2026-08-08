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

- instalar dependências como parte do gate;
- executar análise ou testes;
- compilar Android ou Windows;
- assinar APKs;
- gerar ou validar artefactos de release.

Também é proibido fazer push para “ver se passa”. O GitHub só recebe código que
já passou no i9 e binários que já foram produzidos e verificados no i9.

O GitHub é usado apenas para:

- repositório remoto e histórico;
- revisão/integração de código já verde;
- tags e release notes;
- armazenamento e distribuição de artefactos já compilados no i9.

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

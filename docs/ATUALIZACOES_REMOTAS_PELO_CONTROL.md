# Atualizacoes remotas pelo WashInvoice Control

O Punho reutiliza o mesmo catalogo `versoes_apps` e a mesma Edge Function
`versao-mais-recente` do WashInvoice Control. O empresario ve apenas a marca
Punho e um aviso de nova versao; a ligacao ao Control nao e apresentada.

## Aplicar uma unica vez no projeto Supabase do Control

1. Executar `D:\WashInvoiceControl\washinvoice_control\supabase\punho_extensao_apps.sql` no SQL Editor.
2. Publicar a Edge Function atualizada em `washinvoice_control/supabase/functions/versao-mais-recente/index.ts`.
   A unica alteracao funcional e aceitar `app: 'punho'`.

## Publicar uma versao do Punho

1. Gerar e publicar o instalador/APK assinado num URL de download estavel.
   Para Android, confirmar primeiro a GitHub Release e o APK num dispositivo.
   Não catalogar uma versão sem artefacto publicamente descarregável.
2. Inserir a versao no catalogo remoto, usando sempre um `build_number` maior:

```sql
insert into public.versoes_apps
  (app, plataforma, versao, build_number, url_download, obrigatoria, notas_lancamento, activa)
values
  ('punho', 'windows', '1.0.1', 2, 'https://SEU-REPO-PUNHO/releases/download/v1.0.1/PunhoSetup.exe', false,
   'Melhorias de reservas e sincronizacao.', true);
```

3. A proxima vez que um gestor autenticado abrir o painel Gestao, o Punho consulta a versao remota e mostra o aviso. O botao `Atualizar` abre o URL definido pelo Control.

## Repositorio proprio e plataformas

O repositorio de distribuicao pode e deve ser independente do WashInvoice. Criar uma release no repositorio do Punho com os ficheiros adequados, por exemplo `PunhoSetup.exe` para Windows e `Punho.apk` para Android.

Inserir uma linha no catalogo por plataforma (`windows`, `android` ou `ios`). A app envia a plataforma ao servidor, por isso um Windows recebe apenas o instalador Windows e Android apenas o APK ou link Google Play. O valor `all` existe apenas para retrocompatibilidade com apps antigas.

## Atualizacao obrigatoria

Usar `obrigatoria = true` apenas para uma correcao critica. A app mostra o aviso destacado, mas a distribuicao e instalacao continuam a ser feitas pelo URL indicado. Para uma atualizacao realmente bloqueante e automatica em Windows/Android sera necessario definir primeiro o canal de distribuicao final (MSIX, instalador assinado, Google Play ou APK privado).

## Seguranca

- O Punho nunca inclui `service_role`.
- A verificação usa a configuração pública Supabase e pode ocorrer sem sessão
  autenticada, para também avisar no ecrã de início de sessão.
- A Edge Function le o catalogo com permissao de servidor e nao expoe dados de licencas.

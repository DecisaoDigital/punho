# Auditoria ao backend do Punho — 7 de Agosto de 2026

Auditoria de `0.3.2+37` (commit `0cf10f8`) verificada contra o projecto Supabase
real `oefqbkhioncakojipqyx`. Este documento existe porque a migration
`20260808_punho_fechar_exposicao_anon.sql` remete para ele: sem isto, quem lá
chegasse daqui a seis meses lia «contexto e prova em…» e não encontrava nada.

Só cobre o que foi **fechado**. O que ficou por fazer vive no plano de
hardening, não aqui.

---

## O que estava aberto

### 1 · Três funções de projecção ao alcance de qualquer pessoa

`punho_projectar_entidade`, `punho_projectar_ficha` e `punho_reprojectar_empresa`
são `SECURITY DEFINER` e não verificam `auth.uid()` — nunca foram feitas para ser
chamadas de fora. Tinham `EXECUTE` concedido a `anon` e `authenticated`, e uma
chamada REST com a chave pública respondia 200/204.

Quem soubesse o `empresa_id` — um uuid que anda no cliente — escrevia
directamente nas tabelas de leitura de qualquer empresa, **sem passar pelo
registo de operações**. É a falha mais grave das três: contorna o único canal de
escrita, portanto não deixa rasto no `punho_operacoes` e a auditoria não a vê.

### 2 · Bucket `releases` com escrita anónima

Havia políticas `public upload releases` e `public update releases` em
`storage.objects` para o papel `anon`. Qualquer pessoa com a chave pública
substituía o APK que os telemóveis descarregam na actualização automática.

### 3 · O gestor escrevia o próprio limite

A política de `punho_subscricoes` era `FOR ALL`. O gestor de uma empresa fazia
`UPDATE` ao seu `limite_colaboradores_ativos` — o número que só é decidido no
Control. O limite existia, mas não obrigava a nada.

### 4 · Funções de trigger executáveis por `anon`

Além das três acima, todas as funções que devolvem `trigger` tinham `EXECUTE`
aberto. Uma função de trigger invocada à mão, com o `NEW` que o chamador quiser,
faz o que a tabela faria — sem a tabela. Não há caso de uso legítimo: quem as
chama é o motor de triggers, por dentro, como dono.

---

## O que foi feito

Duas migrations, aplicadas a 8 de Agosto de 2026 às 00:09 e 00:10 UTC:

| ficheiro | o que fecha |
|---|---|
| `20260808_punho_fechar_exposicao_anon.sql` | pontos 1, 2 e 3 |
| `20260808_punho_revogar_funcoes_trigger_de_anon.sql` | ponto 4, em bloco |

Os ficheiros só entraram no repo a 8 de Agosto: foram aplicadas directamente
contra produção e ficaram sem registo em `supabase/migrations/` durante meio dia.

---

## Prova

Verificado a 8 de Agosto de 2026. Não basta ver a política: um `0 linhas`
também aparece quando o contexto de autenticação não pegou. Por isso a prova
encarna um gestor real dentro do Postgres e mostra primeiro **quem é**, e só
depois o que lhe é recusado.

Contexto confirmado antes de cada tentativa: `auth.uid()` de um gestor activo,
`punho_e_gestor() = true`, `punho_empresa_atual()` preenchida, uma linha de
`punho_subscricoes` visível com o limite verdadeiro.

| tentativa | resultado |
|---|---|
| `UPDATE` do próprio `limite_colaboradores_ativos` | 0 linhas |
| `DELETE` da subscrição | 0 linhas |
| `INSERT` de subscrição | `42501` |
| `punho_projectar_ficha`, `punho_reprojectar_empresa` (em SQL) | `42501` |
| os três RPC por REST com a chave `anon` | 401, corpo `42501` |
| `POST` e `PUT` anónimos no bucket `releases` | 403 |

### Contraprova

Fechar tudo também dá zero. Estas três mostram que não se partiu nada:

- escrita real em `punho_operacoes` projectou para `punho_clientes` — a
  projecção continua a funcionar sem os `GRANT` revogados, porque os triggers
  correm como o dono;
- leitura pública de `releases` responde 206, com e sem `apikey`;
- funções de trigger ainda executáveis por `anon` ou `authenticated`: **0**.

### Isolamento entre empresas

`supabase/tests/rls_smoke_isolamento_empresas.sql` — **passou**. Corrido contra
produção, dentro de transacção com `rollback`, e com o trigger
`trg_notificar_novo_pedido_punho` desligado dentro dessa mesma transacção: usa
`pg_net`, e uma notificação enviada não se desfaz com o rollback. O teste não
foi alterado. Base verificada a seguir: nada ficou para trás.

# Edge Functions — o que existe em produção e onde vive o código

Levantamento feito a 8 de Agosto de 2026 contra o projecto
`oefqbkhioncakojipqyx`, comparando `list_edge_functions` com o que estava em
disco. **Sete das catorze funções em produção não tinham ficheiro nenhum em
repositório.** Estavam a servir clientes e existiam só dentro da Supabase.

Isto não é um detalhe de arrumação. Uma função sem ficheiro não se revê, não
se compara, não se restaura, e não há maneira de saber o que mudou nem
quando. Pior: as que **têm** ficheiro podem estar desactualizadas em relação
ao que corre — e aí o ficheiro é pior que a ausência dele, porque um
`supabase functions deploy` a partir do repositório **reverte produção em
silêncio**. Aconteceu com duas (ver mais abaixo).

## As catorze, e onde estão

| Função | `verify_jwt` | Código | Serve |
|---|---|---|---|
| `validar-licenca` | sim | `punho/` | Punho **e** POS |
| `registar-terminal` | sim | `punho/` ¹ | Punho **e** POS |
| `enviar-sugestao` | sim | `punho/` ¹ | Punho **e** POS |
| `portal-contabilista` | não | `punho/` | Punho |
| `sincronizar-empresa-punho` | sim | `punho/` ¹ | Punho |
| `receber-lead` | sim | `punho/` ¹ | Punho |
| `versao-mais-recente` | sim | `washinvoice-control/` ² | Todas (`pos`, `control`, `punho`, `punho_op`) |
| `gerir-licenca` | sim | `washinvoice-control/` | Control |
| `assinar-documento` | sim | `washinvoice-control/` | POS |
| `comunicar-serie` | não | `washinvoice-control/` ³ | Control |
| `enviar-push` | não | `washinvoice-control/` ² | Todas |
| `sincronizar-empresa` | não ⁴ | `washinvoice-control/` ¹ | POS |
| `guardar-credenciais-wse-pos` | não | `washinvoice-control/` ¹ | POS |
| `comunicar-serie-pos` | não | `washinvoice-control/` ¹ | POS |

¹ **Recuperada de produção a 8/8/2026** — não existia em repositório nenhum.
² **O ficheiro estava desactualizado** e foi reposto a partir de produção.
³ O ficheiro é a versão legível; o que está publicado é o mesmo código
  minificado. Lógica equivalente — um redeploy a partir do repositório é
  seguro.
⁴ `verify_jwt: true` na plataforma, mas a função não usa a sessão: identifica
  por `machine_id`.

Uma função só existe numa das duas árvores, nunca nas duas. As multi-app
vivem em `punho/` por serem as que o Punho chama ao arranque; as do POS e do
Control vivem em `washinvoice-control/`.

## As duas que estavam a mentir

**`versao-mais-recente`** — o ficheiro tinha `APPS = ['pos', 'control',
'punho']`. Produção tem `'punho_op'` também. Um redeploy a partir do
repositório teria feito o auto-update do **Punho OP** responder
`400 app inválida` a todas as instalações, sem aviso nenhum.

**`enviar-push`** — o ficheiro era anterior à v8. Faltava-lhe o
`prefixarTituloPorApp`, que põe `[POS]` ou `[PUNHO]` no título. Um redeploy
tirava o prefixo de todas as notificações e ninguém perceberia porquê.

Ambos repostos. A lição é a regra abaixo.

## A regra

**Editar o ficheiro, depois publicar. Nunca o contrário.**

```bash
supabase functions deploy <slug> --project-ref oefqbkhioncakojipqyx
```

Uma função editada no painel da Supabase e não trazida para aqui é uma bomba
com temporizador: fica a funcionar até alguém publicar a partir do
repositório, e nessa altura desaparece sem deixar rasto no `git log`.

Para conferir se alguma se desviou, comparar as datas de publicação
(`list_edge_functions` dá `updated_at`) com `git log -1 -- <pasta>`. Se a
publicação for mais recente que o commit, alguém editou fora daqui.

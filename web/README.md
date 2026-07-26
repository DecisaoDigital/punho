# Landing pública do Punho (`web/`)

Site estático que aceita convites: o gestor cria um convite na app, partilha o
link, o convidado abre-o no telemóvel e cria a conta ali — sem instalar nada
primeiro e sem copiar códigos à mão.

**Zero backend, zero build step.** HTML + CSS + JS puro, `@supabase/supabase-js`
por CDN. Não há `npm install`, não há bundler, não há função serverless.

```
web/
├── index.html            landing genérica (quem aterra sem convite)
├── convite/index.html    aceitar convite: valida o código e cria a conta
├── confirmado/index.html destino do link de confirmação do email
├── assets/styles.css     cores da app (punho_theme.dart)
├── assets/punho-logo.svg placeholder da marca
└── vercel.json           rewrites, redirect /download e headers
```

## Como funciona

1. `/convite/A3F2B819D0` → o `vercel.json` reescreve para `convite/index.html`.
2. O JS lê o código do último segmento do caminho (ou de `?codigo=`, para
   testar localmente) e chama a RPC `punho_validar_convite`.
3. `valido` → mostra o formulário (nome, email, palavra-passe + confirmação).
   Qualquer outro estado → explica porquê e oferece a descarga da app na mesma.
4. Submit → `supabase.auth.signUp` com
   `data: { app: 'punho', convite, nome, empresa: '', perfil: '' }`.
   **`empresa` e `perfil` vão vazios de propósito:** com convite válido, o
   trigger `punho_criar_pedido_ao_registar` lê-os do próprio convite. A landing
   nunca cria empresas nem membros — só nasce um pedido, e a decisão é do
   Control.
5. Sucesso → ecrã final com os passos que faltam e os botões de descarga.

### O email tem de ser o do convite

O trigger em `auth.users` exige `lower(email) = lower(email do convite)`. Se o
convidado escrever outro endereço, o registo é **recusado pelo servidor**. O
GoTrue devolve isso como erro genérico de base de dados — não dá para distinguir
a causa exacta — por isso a landing mostra a causa mais provável ("usa o mesmo
email onde recebeste o convite"). O formulário avisa disto antes de submeter.

### Chaves

A `anon key` está escrita no `convite/index.html`. É **pública por desenho**:
toda a autorização vive nas policies RLS e nas RPCs `security definer`. A RPC
`punho_validar_convite` tem `grant execute ... to anon` exactamente para isto.

**Nunca** pôr aqui a `service_role`. Se um dia a `anon key` legacy for
desactivada, substituir pela publishable key (`sb_publishable_…`) do mesmo
projecto — a chamada é igual.

---

## Setup — passos para o Cesar

### 1. Domínio

Confirmar `decisaodigital.pt` activo e com acesso ao painel de DNS (onde se
criam registos CNAME).

### 2. Vercel

1. Criar conta grátis em <https://vercel.com> (login com o GitHub).
2. **Add New → Project**, importar `DecisaoDigital/punho`.
3. Nas opções do import:
   - **Framework Preset:** `Other`
   - **Root Directory:** `web`
   - **Build Command:** vazio · **Output Directory:** vazio · **Install
     Command:** vazio (não há build)
4. Deploy. Fica em `<projecto>.vercel.app`.

### 3. Domínio no Vercel

1. **Settings → Domains → Add**, escrever `punho.decisaodigital.pt`.
2. O Vercel mostra o registo a criar. No painel de DNS do domínio:

   | Tipo | Nome | Valor |
   |---|---|---|
   | CNAME | `punho` | `cname.vercel-dns.com` |

3. Esperar a propagação (minutos, às vezes horas). O Vercel emite o
   certificado HTTPS sozinho.

### 4. Verificar

Abrir `https://punho.decisaodigital.pt/convite/TESTE`. Deve aparecer **"Convite
inválido"** — está certo: `TESTE` não existe. Se aparecer isso, a landing está
viva e a falar com o Supabase.

Se der erro de ligação em vez de "Convite inválido", o problema é a chamada ao
Supabase, não o DNS.

### 5. Supabase — URLs de redirecção

**Authentication → URL Configuration**, acrescentar a *Redirect URLs*:

```
https://punho.decisaodigital.pt/confirmado
https://punho.decisaodigital.pt/**
```

Sem isto o link de confirmação do email ignora o destino e cai na Site URL do
projecto (que é do Control).

### 6. Supabase — template do email

**Authentication → Email Templates → Confirm signup**. Depois do botão de
confirmação, acrescentar:

```html
<p style="margin-top:24px;color:#5b6b78;font-size:14px">
  Depois de confirmares o email, o acesso ao Punho fica pendente de aprovação
  central — recebes aviso quando ficar activo.
</p>
<p style="color:#5b6b78;font-size:14px">
  Ainda não tens a app? Descarrega em
  <a href="https://punho.decisaodigital.pt/download">punho.decisaodigital.pt/download</a>
</p>
```

### 7. Teste de ponta a ponta

1. Na app, com um gestor aprovado: **Convites → criar convite** para um email
   teu a que tenhas acesso.
2. **Enviar por WhatsApp** — a mensagem já leva o link único.
3. Abrir o link no telemóvel → criar conta (com **esse** email).
4. Confirmar o email na caixa de entrada → cai em `/confirmado`.
5. Aprovar o pedido no Control.
6. Instalar a app, entrar → deve abrir a shell do cargo do convite.

---

## Testar localmente

Não é preciso servidor:

```
start web/convite/index.html?codigo=TESTE      # Windows
```

O `?codigo=` existe precisamente para isto: com `file://` não há rewrites de
caminho. Atenção que os caminhos absolutos (`/assets/styles.css`, `/download`)
**não** resolvem em `file://`, portanto a página abre sem estilo — a lógica
funciona, o aspecto não. Para ver as duas coisas, servir a pasta com qualquer
servidor estático:

```
python -m http.server 8080 --directory web
# depois: http://localhost:8080/convite/index.html?codigo=TESTE
```

### Cenários a testar à mão

Não há testes automatizados aqui — é pouco JS e o valor estava no fluxo real,
não em mocks. São 5 cliques:

| Código | Esperado |
|---|---|
| válido (criado na app) | formulário de criação de conta |
| expirado (`expira_em` no passado) | "Convite expirado" |
| usado (`usado = true`) | "Convite já utilizado" |
| inexistente (`TESTE`) | "Convite inválido" |
| nenhum (`/convite/`) | "Falta o código" |

Para forjar os estados, mexer na linha em `punho_convites` pelo SQL editor do
Supabase.

---

## Notas de implementação

- **`/download` é um `redirect`, não um `rewrite`.** Um rewrite faria o Vercel
  servir a página do GitHub por proxy sob o nosso domínio; um redirect 307 manda
  o browser para lá, que é o que se quer. Ambos os botões (Android e Windows)
  vão para a mesma página de releases, onde estão o APK e o instalador — quando
  os nomes dos ficheiros estabilizarem, dá para apontar a cada asset.
- **`persistSession: false`** no cliente Supabase: a landing cria a conta e
  acaba ali, não deixa token no telemóvel de quem passou uma vez.
- **`noindex`** em `/convite` e `/confirmado` — são páginas de fluxo, não de
  divulgação.

# Prompt Claude Code — Landing web para aceitar convites Punho

## Objectivo

Fluxo profissional para convidar utilizadores: gestor gera convite na app → partilha link único (`https://punho.decisaodigital.pt/convite/<codigo>`) → convidado abre link no telemóvel → landing web pede email+palavra-passe → cria conta → recebe email com link para descarregar a app → Cesar aprova no Control → utilizador entra.

**Repo:** `D:\Punho`
**Branch novo:** `feat/landing-convites` (a partir de `release/v0.0.3`)

---

## Estado actual (para não duplicar)

- App Flutter tem `ConvitesScreen` (gestor cria convite) — funciona hoje só com "Copiar código".
- Já foi adicionado botão **"Enviar por WhatsApp"** que abre `wa.me/?text=...` com URL do GitHub Releases + código. Precisa de ser ajustado nesta task para usar o link único da landing (ver secção 4).
- RPC `punho_validar_convite(p_codigo text)` já existe (retorna `'valido' | 'expirado' | 'usado' | 'invalido'` — ver migration `20260731_punho_contas_organizacao.sql`).
- Trigger em `auth.users` cria `punho_pedidos_acesso` com `origem='convite'` quando signup traz `raw_user_meta_data->>'convite'` e código é válido.
- Cesar vai tratar do DNS (`punho.decisaodigital.pt`) em paralelo.

---

## Regras não negociáveis

1. **Zero backend novo.** Landing é 100% estática, chama Supabase directamente com chave pública. Não escreve serviço serverless.
2. **RPC `punho_validar_convite` não é alterada** — a landing consome como é.
3. **Signup passa pelo Supabase Auth padrão** (`supabase.auth.signUp` com `data: {app: 'punho', convite, nome, empresa, perfil}`). O trigger existente faz o resto.
4. **A landing NÃO cria empresas nem membros** — só cria pedidos, tudo o resto é aprovação central no Control.
5. **Anon key exposta na landing é OK** — é chave pública Supabase, uso legítimo. Não usar service role.
6. **Mensagem WhatsApp na app** passa a incluir o link único; o código fica lá como fallback caso a landing não abra por qualquer motivo.

---

## Alterações

### 1. Estrutura da landing

Criar pasta `D:\Punho\web\` com:

```
web/
├── index.html               # landing genérica (opcional agora, redirecciona para GitHub Releases)
├── convite/
│   └── index.html           # aceitar convite: form de signup
├── assets/
│   ├── styles.css
│   └── punho-logo.svg       # se existir logo, senão placeholder
├── vercel.json              # config de rewrites + headers
└── README.md                # instruções de setup Vercel + DNS
```

**Stack:** HTML + CSS + JS puro (zero framework, zero build step). Chamadas Supabase via `@supabase/supabase-js` do CDN (script tag).

**Config Supabase para a landing:** ler `SUPABASE_URL` e `SUPABASE_ANON_KEY` de `.env` local, e injectar no HTML final via build simples. Mas dado que Vercel pode servir variables via `vercel.json`, alternativa: hard-code os valores públicos no JS (é anon key, público de propósito). **Recomendo hard-code** — mais simples, zero build.

### 2. `web/convite/index.html`

Fluxo do JS:

1. Ler `codigo` do último segmento da URL: `https://punho.decisaodigital.pt/convite/A3F2B819D0` → `A3F2B819D0`.
2. Chamar `supabase.rpc('punho_validar_convite', { p_codigo })`.
3. Se `!== 'valido'`: mostrar mensagem apropriada ("Convite inválido / expirado / já utilizado") e link para descarregar app na mesma.
4. Se `'valido'`: mostrar formulário:
   - Campo Nome (obrigatório)
   - Campo Email (obrigatório, tipo email)
   - Campo Palavra-passe (obrigatório, mín 8, com **campo de confirmação**)
   - Botão "Criar conta"
5. Submit: `supabase.auth.signUp({ email, password, data: { app: 'punho', convite: codigo, nome, empresa: '', perfil: '' } })`.
   - **Importante:** `empresa` e `perfil` vão a vazio — o trigger no servidor lê do próprio convite. Ver `20260731_punho_contas_organizacao.sql:25` (`v_convite.perfil`) e a `select nome into v_empresa`.
6. Sucesso: mostrar ecrã final com:
   - Ícone check + "Conta criada"
   - Explicação: "Vais receber um email para confirmar. Depois disso, o acesso fica pendente de aprovação e recebes um novo email quando ficar activo."
   - **Botão "Descarregar Punho para Android"** (link para GitHub Releases latest).
   - **Botão "Descarregar Punho para Windows"** (idem).

### 3. `web/index.html` (landing genérica, opcional)

Página simples: logo + slogan Punho + 2 botões (Descarregar Android / Windows). Se um dia alguém aterrar em `punho.decisaodigital.pt` sem convite, não vê 404.

### 4. Actualizar mensagem WhatsApp na app

Em `D:\Punho\lib\features\gestao\presentation\convites_screen.dart`:

- Ajustar `_kUrlDescargaPunho` — passa a ser a base da landing (`https://punho.decisaodigital.pt`).
- Ajustar `mensagemConvite(convite)` — o texto passa a incluir o link único primeiro, e o código como fallback. Sugestão:

```
Olá! Foste convidado(a) para o Punho como <cargo>.

Abre este link no telemóvel para criares conta:
https://punho.decisaodigital.pt/convite/<codigo>

Se o link não funcionar, instala a app em
https://punho.decisaodigital.pt/download
e usa este código de convite: <codigo>

Código válido durante 14 dias e de uma só utilização.
```

### 5. `vercel.json`

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "rewrites": [
    { "source": "/convite/:codigo", "destination": "/convite/index.html" },
    { "source": "/download", "destination": "https://github.com/DecisaoDigital/punho/releases/latest" }
  ],
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "X-Frame-Options", "value": "DENY" },
        { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" }
      ]
    }
  ]
}
```

### 6. Template de email do Supabase Auth

Ficheiro `web/README.md` deve incluir instruções para o Cesar personalizar no dashboard Supabase (Authentication → Email Templates → Confirm signup):

- Adicionar após o botão de confirmação: "Depois de confirmar o email, o acesso fica pendente de aprovação central. Se ainda não tens a app: descarrega em https://punho.decisaodigital.pt/download".

### 7. `web/README.md` — instruções setup

Documento com passos para o Cesar:

1. **Comprar/confirmar `decisaodigital.pt`** e ter acesso ao painel DNS.
2. **Criar conta Vercel** (grátis) e ligar ao repo `github.com/DecisaoDigital/punho`, apontar root para `/web/`.
3. **Configurar domínio custom** no Vercel: adicionar `punho.decisaodigital.pt` como custom domain, seguir instruções DNS (CNAME para `cname.vercel-dns.com`).
4. **Verificar** que `https://punho.decisaodigital.pt/convite/TESTE` mostra a landing (com mensagem "Convite inválido" — normal, o código é falso).
5. **Personalizar template email Supabase** (ver §6).
6. **Testar fluxo end-to-end:** criar convite na app (gestor de teste) → abrir link no telemóvel → criar conta na landing → verificar email → confirmar → aprovar no Control → instalar app → login → entra.

---

## Testes

- **Landing:** dado o volume baixo de JS puro, testes automatizados são over-engineering. Deixa manual: 5 cenários (código válido, expirado, usado, inválido, empty).
- **App Flutter:** actualizar `convites_screen_test.dart` (se existir) para verificar que `mensagemConvite` inclui a URL da landing.
- **Não** correr `flutter build apk` — este trabalho pode ser mergeado sem release Android (o botão apenas melhora a mensagem WhatsApp).

---

## Gate

1. `flutter test` — verde.
2. `flutter analyze` — limpo.
3. `web/` compila localmente sem build tool (basta abrir `web/convite/index.html?codigo=TESTE` no browser — vê a landing).
4. `web/README.md` cobre passos DNS + Vercel + template email.

## Entrega

- Branch `feat/landing-convites`, N commits locais, sem push.
- `pubspec.yaml` **não** bumpado (v0.0.3+3 fica; ou 0.0.4 acumula se ainda for pré-release).
- Sem tag, sem GitHub Release publicado.
- Aviso no fim: **enquanto DNS não estiver configurado, o link `punho.decisaodigital.pt/convite/XXX` dá "servidor não encontrado". Testar em `<projecto>.vercel.app/convite/XXX` primeiro.**

## Fora do âmbito (backlog)

- **Deep link** `punho://convite/XXX` que abre a app se instalada. Requer intent-filter Android + associated domains iOS. v0.1.0.
- **QR code do link** no diálogo do gestor. Trivial mas fica para depois se for pedido.
- **Email transaccional próprio** (Resend/SendGrid) para melhor controlo de deliverability. Actualmente Supabase Auth chega.
- **Analytics da landing** (visitas, conversões). Adicionar quando fizer sentido medir.

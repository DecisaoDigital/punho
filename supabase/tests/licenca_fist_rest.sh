#!/usr/bin/env bash
# ============================================================================
# licenca-fist — prova pelo caminho verdadeiro (REST com token de sessão real)
#
# Empresa de ensaio «Lavandaria Nocturna (teste)». Prova: sem sessão não entra; a
# licença é da EMPRESA (gestor e colaborador veem a mesma validade); no máximo 2
# aparelhos por funcionário; sessão única (quem abre, o outro perde).
#
# PRECISA DE  ~/punho/.env (SUPABASE_URL, SUPABASE_ANON_KEY) e
#             ~/.punho/contas_teste.env (G_EMAIL/G_SENHA, O_EMAIL/O_SENHA)
# RESULTADO   «passaram N, falharam 0» => bom. Sai com 0.
# Deixa rasto em fist_dispositivos/fist_sessoes (machine_id «teste-fist-*»).
# ============================================================================
set -uo pipefail
source "${PUNHO_ENV:-$HOME/punho/.env}"
source "${PUNHO_CONTAS:-$HOME/.punho/contas_teste.env}"

entrar() {
  curl -s "$SUPABASE_URL/auth/v1/token?grant_type=password" \
    -H "apikey: $SUPABASE_ANON_KEY" -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"$2\"}" \
    | jq -r '.access_token // ("ERRO:" + (.error_description // .msg // .error // "?"))'
}
# chamar TOKEN CORPO  -> imprime o JSON; HTTP na última linha
chamar() {
  curl -s "$SUPABASE_URL/functions/v1/licenca-fist" \
    -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $1" \
    -H 'Content-Type: application/json' -w '\nHTTP:%{http_code}' -d "$2"
}
corpo() { sed '$d' <<<"$1"; }
http()  { tail -1 <<<"$1" | cut -d: -f2; }

ok=0; mau=0
verifica() { # descrição, esperado, obtido
  if [[ "$2" == "$3" ]]; then ok=$((ok+1)); echo "  ok   $1"; else mau=$((mau+1)); echo "  FALHA $1 (esperado '$2', obtido '$3')"; fi
}

G=$(entrar "$G_EMAIL" "$G_SENHA"); C=$(entrar "$O_EMAIL" "$O_SENHA")
[[ $G == ERRO:* || $C == ERRO:* ]] && { echo "login falhou: G=$G C=$C"; exit 1; }

echo "1. sem sessão de utilizador"
r=$(chamar "$SUPABASE_ANON_KEY" '{"machine_id":"teste-fist-A"}')
verifica "a chave publicável não serve" 401 "$(http "$r")"

echo "2. a licença é da empresa"
rg=$(chamar "$G" '{"machine_id":"teste-fist-A","reclamar_sessao":true}')
rc=$(chamar "$C" '{"machine_id":"teste-fist-C1","reclamar_sessao":true}')
verifica "gestor: 200" 200 "$(http "$rg")"
verifica "colaborador: 200" 200 "$(http "$rc")"
verifica "mesma validade para gestor e colaborador" \
  "$(corpo "$rg" | jq -r .validade)" "$(corpo "$rc" | jq -r .validade)"
verifica "mesma empresa" "$(corpo "$rg" | jq -r .empresa.id)" "$(corpo "$rc" | jq -r .empresa.id)"

echo "3. no máximo 2 aparelhos por funcionário"
r2=$(chamar "$G" '{"machine_id":"teste-fist-B","reclamar_sessao":true}')
verifica "2.º aparelho aceite" "2" "$(corpo "$r2" | jq -r .dispositivos.usados)"
r3=$(chamar "$G" '{"machine_id":"teste-fist-C","reclamar_sessao":true}')
verifica "3.º aparelho recusado" "dispositivos_excedidos" "$(corpo "$r3" | jq -r .estado)"
rA=$(chamar "$G" '{"machine_id":"teste-fist-A"}')
verifica "aparelho já conhecido continua a entrar" 200 "$(http "$rA")"

echo "4. sessão única"
SB=$(corpo "$r2" | jq -r .sessao.id)           # B reclamou por último
SA=$(corpo "$rg" | jq -r .sessao.id)           # sessão antiga de A
hb_a=$(chamar "$G" "{\"machine_id\":\"teste-fist-A\",\"sessao_id\":\"$SA\"}")
hb_b=$(chamar "$G" "{\"machine_id\":\"teste-fist-B\",\"sessao_id\":\"$SB\"}")
verifica "A perdeu a sessão" false "$(corpo "$hb_a" | jq -r .sessao.ativa)"
verifica "B tem a sessão" true "$(corpo "$hb_b" | jq -r .sessao.ativa)"
re=$(chamar "$G" '{"machine_id":"teste-fist-A","reclamar_sessao":true}')
SA2=$(corpo "$re" | jq -r .sessao.id)
hb_b2=$(chamar "$G" "{\"machine_id\":\"teste-fist-B\",\"sessao_id\":\"$SB\"}")
verifica "A reabre: B perde a sessão" false "$(corpo "$hb_b2" | jq -r .sessao.ativa)"
verifica "A reabre: id novo" true "$([[ "$SA2" != "$SA" && "$SA2" != "$SB" ]] && echo true || echo false)"

echo; echo "passaram $ok, falharam $mau"
[[ $mau -eq 0 ]]

#!/usr/bin/env bash
# ============================================================================
# CRM fase 1 — reuniões e visibilidade das leads, pelo caminho verdadeiro
#
# REST com token de sessão real, na empresa de ensaio «Lavandaria Nocturna
# (teste)». Mesmo método e mesmas contas de punho_campos_do_colaborador_rest.sh.
#
# PROVA
#   1. O autor de uma reunião é carimbado pelo servidor (um criadoPorUid
#      forjado pelo cliente é substituído pela conta real).
#   2. O colaborador remarca a reunião que ele marcou.
#   3. O colaborador NÃO remarca a reunião de outra pessoa (mas muda-lhe o estado).
#   4. O tipo não muda depois de nascer.
#   5. Reservas antigas (sem tipo) continuam editáveis pelo colaborador.
#   6. O colaborador só lê as leads atribuídas a si (ou criadas por si); o gestor lê todas.
#
# Deixa rasto na empresa de ensaio (registo append-only). Nunca contra uma
# empresa a sério.
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
uid_do_token() { cut -d. -f2 <<<"$1" | tr '_-' '/+' | base64 -d 2>/dev/null | jq -r .sub; }

EMPRESA=11111111-2222-3333-4444-555555555555
G=$(entrar "$G_EMAIL" "$G_SENHA")
C=$(entrar "$O_EMAIL" "$O_SENHA")
[[ $G == ERRO:* || $C == ERRO:* ]] && { echo "login falhou: G=$G C=$C"; exit 1; }
UID_C=$(uid_do_token "$C"); UID_G=$(uid_do_token "$G")
FICHA_C=$(curl -s "$SUPABASE_URL/rest/v1/punho_membros?select=colaborador_id&user_id=eq.$UID_C" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $C" | jq -r '.[0].colaborador_id')
echo "gestor $UID_G · colaborador $UID_C (ficha $FICHA_C)"

ok=0; mau=0
uuid() { cat /proc/sys/kernel/random/uuid; }
S=$$

post() { # <token> <entidade> <id> <payload>
  curl -s "$SUPABASE_URL/rest/v1/punho_operacoes" \
    -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $1" \
    -H 'Content-Type: application/json' -H 'Prefer: return=minimal' \
    -w '\nHTTP:%{http_code}' \
    -d "$(jq -nc --arg id "$(uuid)" --arg e "$3" --arg ent "$2" --arg emp "$EMPRESA" \
         --argjson p "$4" \
         '{id:$id, empresa_id:$emp, entidade:$ent, entidade_id:$e, payload:$p,
           feito_em:(now|todate), por_dispositivo:"provas-crm"}')"
}
http() { local r=$1; echo "${r##*HTTP:}"; }

confere() { # <nome> <esperado> <obtido>
  if [[ "$2" == "$3" ]]; then ok=$((ok+1)); printf '  ✓ %s\n' "$1"
  else mau=$((mau+1)); printf '  ✗ %s (esperado %s, obtido %s)\n' "$1" "$2" "$3"; fi
}

reuniao() { # <id> <uidAutor> <inicio> <status> <notas> [tipo]
  jq -nc --arg id "$1" --arg u "$2" --arg i "$3" --arg s "$4" --arg n "$5" --arg t "${6:-reuniao}" \
    '{id:$id,tipo:$t,criadoPorUid:$u,customerId:"c-prova",machineIds:[],
      startsAt:$i,endsAt:($i|sub("T10";"T11")),status:$s,notes:$n,lembreteMinutos:15,
      customerNameSnapshot:"Cliente prova"}'
}

echo "1. autor carimbado pelo servidor"
R1=reu-prova-$S
post "$C" booking "$R1" "$(reuniao "$R1" "forjado-pelo-cliente" 2026-12-01T10:00:00 confirmed "")" >/dev/null
AUTOR=$(curl -s "$SUPABASE_URL/rest/v1/punho_operacoes?select=payload&entidade_id=eq.$R1&order=seq.desc&limit=1" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $G" | jq -r '.[0].payload.criadoPorUid')
confere "criadoPorUid forjado → conta real do colaborador" "$UID_C" "$AUTOR"

echo "2. colaborador remarca a sua"
r=$(post "$C" booking "$R1" "$(reuniao "$R1" "$UID_C" 2026-12-02T10:00:00 confirmed "nota")")
confere "remarcar a própria reunião (HTTP 2xx)" "2" "$(http "$r" | cut -c1)"

echo "3. reunião de outra pessoa"
R2=reu-prova-g-$S
post "$G" booking "$R2" "$(reuniao "$R2" "$UID_G" 2026-12-03T10:00:00 confirmed "")" >/dev/null
r=$(post "$C" booking "$R2" "$(reuniao "$R2" "$UID_G" 2026-12-09T10:00:00 confirmed "")")
confere "colaborador NÃO remarca a reunião do gestor (403)" "403" "$(http "$r")"
r=$(post "$C" booking "$R2" "$(reuniao "$R2" "$UID_G" 2026-12-03T10:00:00 cancelled "")")
confere "mas pode mudar-lhe o estado" "2" "$(http "$r" | cut -c1)"

echo "4. o tipo não muda"
r=$(post "$C" booking "$R1" "$(reuniao "$R1" "$UID_C" 2026-12-02T10:00:00 confirmed "nota" maquina)")
confere "reunião → máquina recusado (403)" "403" "$(http "$r")"

echo "5. reserva antiga continua editável"
B=res-prova-$S
post "$G" booking "$B" '{"id":"'$B'","customerId":"c-prova","machineIds":[],"startsAt":"2026-12-05T00:00:00","endsAt":"2026-12-06T00:00:00","status":"request","notes":""}' >/dev/null
r=$(post "$C" booking "$B" '{"id":"'$B'","tipo":"maquina","lembreteMinutos":null,"criadoPorUid":null,"customerId":"c-prova","machineIds":[],"startsAt":"2026-12-05T00:00:00","endsAt":"2026-12-06T00:00:00","status":"confirmed","notes":""}')
confere "estado de reserva antiga com tipo=maquina (2xx)" "2" "$(http "$r" | cut -c1)"

echo "6. visibilidade das leads"
LA=lead-prova-atrib-$S; LN=lead-prova-livre-$S; LC=lead-prova-propria-$S
post "$G" lead "$LA" '{"id":"'$LA'","name":"Atribuída","phone":"911","status":"newLead","createdAt":"2026-12-01T10:00:00","collaboratorResponsibleId":"'$FICHA_C'"}' >/dev/null
post "$G" lead "$LN" '{"id":"'$LN'","name":"Por atribuir","phone":"912","status":"newLead","createdAt":"2026-12-01T10:00:00"}' >/dev/null
post "$C" lead "$LC" '{"id":"'$LC'","name":"Do operador","phone":"913","status":"newLead","createdAt":"2026-12-01T10:00:00"}' >/dev/null
ler() { curl -s "$SUPABASE_URL/rest/v1/punho_operacoes?select=entidade_id&entidade=eq.lead&entidade_id=in.($LA,$LN,$LC)" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $1" | jq -r '[.[].entidade_id]|unique|sort|join(",")'; }
confere "colaborador vê a atribuída e a sua, não a por atribuir" "$(printf '%s\n' $LA $LC | sort | paste -sd,)" "$(ler "$C")"
confere "gestor vê as três" "$(printf '%s\n' $LA $LN $LC | sort | paste -sd,)" "$(ler "$G")"

echo
echo "passaram $ok, falharam $mau"
[[ $mau -eq 0 ]]

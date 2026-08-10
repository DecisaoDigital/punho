#!/usr/bin/env bash
# ============================================================================
# O operador cobra, não altera preços — prova pelo caminho verdadeiro
#
# Fala com o servidor como as apps falam: REST com token de sessão real, na
# empresa de ensaio «Lavandaria Nocturna (teste)». SQL como `postgres` salta o
# RLS e responde sempre que sim; é por isso que esta prova existe ao lado do
# `punho_campos_do_colaborador_test.sql`.
#
# PRECISA DE
#   ~/punho/.env                 SUPABASE_URL e SUPABASE_ANON_KEY
#   ~/.punho/contas_teste.env    G_EMAIL/G_SENHA (gestor) e O_EMAIL/O_SENHA
#                                (colaborador activo da empresa de ensaio)
#
# RESULTADO
#   «passaram N, falharam 0» => está fechado. Sai com 0.
#
# Deixa rasto: o registo é append-only e as operações de prova ficam na empresa
# de ensaio. É de propósito — nunca correr isto contra uma empresa a sério.
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

escrever() {
  curl -s "$SUPABASE_URL/rest/v1/$2" \
    -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $1" \
    -H 'Content-Type: application/json' -H 'Prefer: return=minimal' \
    -w '\nHTTP:%{http_code}' -d "$3"
}

EMPRESA=11111111-2222-3333-4444-555555555555
G=$(entrar "$G_EMAIL" "$G_SENHA")
C=$(entrar "$O_EMAIL" "$O_SENHA")   # operador.nocturno — colaborador da empresa
[[ $G == ERRO:* || $C == ERRO:* ]] && { echo "login falhou: G=$G C=$C"; exit 1; }
echo "gestor e colaborador com sessão."

ok=0; mau=0
uuid() { cat /proc/sys/kernel/random/uuid; }

# operacao <token> <entidade> <id_local> <payload_json>
operacao() {
  escrever "$1" punho_operacoes "$(jq -nc \
    --arg id "$(uuid)" --arg e "$3" --arg ent "$2" --arg emp "$EMPRESA" \
    --argjson p "$4" \
    '{id:$id, empresa_id:$emp, entidade:$ent, entidade_id:$e, payload:$p,
      feito_em:(now|todate), por_dispositivo:"provas-fase2"}')"
}

# espera <esperado:ok|42501> <nome> <token> <entidade> <id> <payload>
espera() {
  local alvo=$1 nome=$2; shift 2
  local r; r=$(operacao "$@")
  local http=${r##*HTTP:}
  local corpo=${r%$'\n'HTTP:*}
  local veredicto
  if [[ $alvo == ok ]]; then
    [[ $http == 2* ]] && veredicto=PASSA || veredicto=FALHA
  else
    grep -q "$alvo" <<<"$corpo" && veredicto=PASSA || veredicto=FALHA
  fi
  if [[ $veredicto == PASSA ]]; then
    ok=$((ok+1)); printf '  ✓ %s\n' "$nome"
    [[ $alvo != ok ]] && printf '      → %s\n' "$(jq -r '.message // .hint // .' <<<"$corpo" 2>/dev/null | head -1)"
  else
    mau=$((mau+1)); printf '  ✗ %s\n      http=%s %s\n' "$nome" "$http" "$(head -c 300 <<<"$corpo")"
  fi
}

M=maq-prova-$$
CL=cli-prova-$$
B=res-prova-$$
R=rec-prova-$$
L=lead-prova-$$
D=desp-prova-$$

maquina() { # <status> <dailyRate> <purchase> <reference> <name> <notes>
  jq -nc --arg id "$M" --arg s "$1" --arg r "$4" --arg n "$5" --arg no "$6" \
     --argjson d "$2" --argjson p "$3" \
    '{id:$id, name:$n, reference:$r, category:"Escavadoras", status:$s,
      dailyRateCents:$d, acquiredOn:null, purchasePriceCents:$p,
      notes:$no, photoPaths:[], archived:false}'
}

echo
echo "── o gestor põe a máquina no inventário ─────────────────────────"
espera ok "gestor cria a máquina (5000/dia, comprada por 900000)" \
  "$G" machine "$M" "$(maquina available 5000 900000 REF-1 'Giratória 3T' '')"

echo
echo "── o que o operador PODE ────────────────────────────────────────"
espera ok "entregar: status available → rented" \
  "$C" machine "$M" "$(maquina rented 5000 900000 REF-1 'Giratória 3T' '')"
espera ok "escrever notas de obra" \
  "$C" machine "$M" "$(maquina rented 5000 900000 REF-1 'Giratória 3T' 'Óleo a meio')"
espera ok "reenviar exactamente o mesmo (carga inicial)" \
  "$C" machine "$M" "$(maquina rented 5000 900000 REF-1 'Giratória 3T' 'Óleo a meio')"

echo
echo "── o que o operador NÃO pode, na máquina ────────────────────────"
espera 42501 "baixar o preço por dia para 1,00 €" \
  "$C" machine "$M" "$(maquina rented 100 900000 REF-1 'Giratória 3T' 'Óleo a meio')"
espera 42501 "mexer no valor de compra" \
  "$C" machine "$M" "$(maquina rented 5000 1 REF-1 'Giratória 3T' 'Óleo a meio')"
espera 42501 "mudar a referência" \
  "$C" machine "$M" "$(maquina rented 5000 900000 REF-9 'Giratória 3T' 'Óleo a meio')"
espera 42501 "mudar o nome" \
  "$C" machine "$M" "$(maquina rented 5000 900000 REF-1 'Minha' 'Óleo a meio')"
espera 42501 "apagar o preço (null)" \
  "$C" machine "$M" "$(maquina rented null 900000 REF-1 'Giratória 3T' 'Óleo a meio')"
espera 42501 "criar uma máquina nova" \
  "$C" machine "outra-$M" "$(maquina available 5000 1 REF-X 'Minha giratória' '')"

echo
echo "── cliente ──────────────────────────────────────────────────────"
cliente() { # <phone> <archived>
  jq -nc --arg id "$CL" --arg t "$1" --argjson a "$2" \
    '{id:$id, name:"Casa Ferreira", phone:$t, taxId:null, email:null,
      address:null, postalCode:null, locality:null, notes:"",
      companyId:"local-company", archived:$a}'
}
espera ok    "gestor cria o cliente"            "$G" customer "$CL" "$(cliente 912000000 false)"
espera ok    "operador corrige o telemóvel"     "$C" customer "$CL" "$(cliente 913111111 false)"
espera 42501 "operador arquiva o cliente"       "$C" customer "$CL" "$(cliente 913111111 true)"

echo
echo "── trabalho ─────────────────────────────────────────────────────"
INI=$(date -u -d '+1 day'  +%Y-%m-%dT08:00:00Z)
FIM=$(date -u -d '+3 days' +%Y-%m-%dT18:00:00Z)
OUTRO=$(date -u -d '+5 days' +%Y-%m-%dT18:00:00Z)
reserva() { # <status> <valor> <cliente> <inicio> <fim>
  jq -nc --arg id "$B" --arg s "$1" --argjson v "$2" --arg c "$3" \
     --arg i "$4" --arg f "$5" --arg m "$M" \
    '{id:$id, customerId:$c, machineIds:[$m], startsAt:$i, endsAt:$f,
      status:$s, expectedValueCents:$v, collaboratorResponsibleId:null,
      companyId:"local-company", customerNameSnapshot:"Casa Ferreira",
      collaboratorNameSnapshot:"", notes:""}'
}
espera ok "gestor marca o trabalho por 200,00 €" \
  "$G" booking "$B" "$(reserva confirmed 20000 "$CL" "$INI" "$FIM")"
espera ok "operador entrega (confirmed → rented)" \
  "$C" booking "$B" "$(reserva rented 20000 "$CL" "$INI" "$FIM")"
espera 42501 "operador faz um desconto de 150 €" \
  "$C" booking "$B" "$(reserva rented 5000 "$CL" "$INI" "$FIM")"
espera 42501 "operador troca o cliente" \
  "$C" booking "$B" "$(reserva rented 20000 "outro-$CL" "$INI" "$FIM")"
espera 42501 "operador estica as datas contratadas" \
  "$C" booking "$B" "$(reserva rented 20000 "$CL" "$INI" "$OUTRO")"
espera ok "operador marca um trabalho novo" \
  "$C" booking "novo-$B" "$(jq -nc --arg id "novo-$B" --arg c "$CL" \
      --arg i "$OUTRO" --arg f "$(date -u -d '+6 days' +%Y-%m-%dT18:00:00Z)" \
    '{id:$id, customerId:$c, machineIds:[], startsAt:$i, endsAt:$f,
      status:"request", expectedValueCents:15000,
      collaboratorResponsibleId:null, companyId:"local-company",
      customerNameSnapshot:"Casa Ferreira", collaboratorNameSnapshot:"",
      notes:"pedido por telefone"}')"

echo
echo "── recebimento ──────────────────────────────────────────────────"
recibo() { # <valor> <metodo>
  jq -nc --arg id "$R" --argjson v "$1" --arg m "$2" --arg c "$CL" --arg b "$B" \
    '{id:$id, date:(now|todate), amountCents:$v, customerId:$c, bookingId:$b,
      method:$m, note:"", recordedByCollaboratorId:null, archived:false}'
}
espera ok    "operador cobra 200,00 € em dinheiro" "$C" receipt "$R" "$(recibo 20000 cash)"
espera 42501 "operador reduz o recebido para 50 €" "$C" receipt "$R" "$(recibo 5000 cash)"
espera 42501 "operador troca o método"             "$C" receipt "$R" "$(recibo 20000 transfer)"

echo
echo "── o que continua livre ─────────────────────────────────────────"
lead() { jq -nc --arg id "$L" --arg s "$1" \
  '{id:$id, name:"Sr. Antunes", phone:"969000000", status:$s, source:"phone",
    createdAt:(now|todate), summary:"quer giratória", collaboratorResponsibleId:null,
    convertedCustomerId:null, bookingId:null}'; }
espera ok "operador cria a lead"    "$C" lead "$L" "$(lead newLead)"
espera ok "operador trabalha a lead" "$C" lead "$L" "$(lead contacted)"

despesa() { jq -nc --arg id "$D" --argjson v "$1" \
  '{id:$id, date:(now|todate), amountCents:$v, category:"fuel", status:"pending",
    note:"gasóleo", description:"Gasóleo", machineId:null, archived:false}'; }
espera ok "operador lança a despesa dele" "$C" expense "$D" "$(despesa 4500)"
espera ok "operador corrige a despesa dele" "$C" expense "$D" "$(despesa 4700)"

echo
echo "── o gestor não é travado por nada disto ────────────────────────"
espera ok "gestor sobe o preço por dia" \
  "$G" machine "$M" "$(maquina rented 7500 900000 REF-1 'Giratória 3T' 'Óleo a meio')"
espera ok "gestor arquiva o cliente" "$G" customer "$CL" "$(cliente 913111111 true)"

echo
echo "── ficha antiga sem o campo novo (ausente ≠ alteração) ──────────"
espera ok "gestor grava máquina antiga, sem purchasePriceCents" \
  "$G" machine "velha-$M" "$(jq -nc --arg id "velha-$M" \
    '{id:$id, name:"Martelo", reference:"REF-V", category:"Martelos",
      status:"available", dailyRateCents:3000, notes:"", photoPaths:[],
      archived:false}')"
espera ok "operador entrega-a com purchasePriceCents:null" \
  "$C" machine "velha-$M" "$(jq -nc --arg id "velha-$M" \
    '{id:$id, name:"Martelo", reference:"REF-V", category:"Martelos",
      status:"rented", dailyRateCents:3000, acquiredOn:null,
      purchasePriceCents:null, notes:"", photoPaths:[], archived:false}')"

echo
printf '%s\n' "───────────────────────────────────────────────────────────────"
printf 'passaram %d, falharam %d\n' "$ok" "$mau"
[[ $mau -eq 0 ]]

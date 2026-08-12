#!/usr/bin/env bash
# Vigia das cópias de segurança do Punho.
#
# ## Porquê isto existe
#
# A cadeia de cópia está provada e agendada, e mesmo assim tinha um buraco: o
# cron escreve para ~/copias/punho.log e ninguém lê ficheiros de registo. Uma
# cópia que comece a falhar às 04:40 fica a falhar até alguém tropeçar nela —
# e provavelmente tropeça no dia em que precisa dela.
#
# ## Porquê no terminal e não no Grafana
#
# O i9 tem Prometheus e Grafana a correr, e o instinto era mandar uma métrica
# para lá. Fui ver: **zero regras de alerta e o receptor de notificações é o
# `empty`**. Uma métrica no Grafana seria exactamente o mesmo defeito noutro
# sítio — um painel que ninguém abre em vez de um registo que ninguém lê.
#
# O sítio por onde o César passa todos os dias é o terminal do i9. Portanto o
# aviso aparece aí, ao abrir a shell, e só quando há alguma coisa errada. A
# métrica escreve-se na mesma (dá história e gráfico se um dia houver alertas
# a sério), mas quem avisa é o banner.
#
# ## Uso
#
#   ./scripts/vigia_de_copias.sh            diz como estão as cópias
#   ./scripts/vigia_de_copias.sh --banner   só fala se houver problema (perfil)
#   ./scripts/vigia_de_copias.sh --metricas  só escreve o .prom
#
# Sai com 0 se está tudo bem, 1 se há alguma coisa a precisar de atenção.

set -Eeuo pipefail

DESTINO="${PUNHO_COPIAS:-${HOME}/copias/punho}"
readonly MARCA_COPIA="${DESTINO}/.ultima_copia"
readonly MARCA_PROVA="${DESTINO}/.ultima_prova"
readonly PROM="${PUNHO_PROM:-/var/lib/prometheus/node-exporter/copia_punho.prom}"

# A cópia é diária às 04:40: 36 horas dá folga para uma noite falhada sem
# gritar, e apanha duas noites seguidas. A prova é semanal ao domingo: 9 dias
# deixa passar um domingo em que a máquina esteve desligada, não dois.
readonly HORAS_ATE_QUEIXA=36
readonly DIAS_ATE_QUEIXA_DA_PROVA=9

modo=humano
case "${1:-}" in
  --banner)   modo=banner ;;
  --metricas) modo=metricas ;;
  -h|--help)  sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  '') ;;
  *) echo "Argumento desconhecido: $1" >&2; exit 2 ;;
esac

agora="$(date +%s)"

# Idade em segundos do que a marca disser, ou vazio se a marca não existir.
idade_de() {
  local marca="$1"
  [[ -f "$marca" ]] || return 1
  local quando
  quando="$(head -1 "$marca" 2>/dev/null || true)"
  [[ "$quando" =~ ^[0-9]+$ ]] || return 1
  echo $(( agora - quando ))
}

problemas=()
idade_copia=""
idade_prova=""

if idade_copia="$(idade_de "$MARCA_COPIA")"; then
  if (( idade_copia > HORAS_ATE_QUEIXA * 3600 )); then
    problemas+=("a última cópia da base tem $(( idade_copia / 3600 ))h — devia ter menos de ${HORAS_ATE_QUEIXA}h")
  fi
else
  idade_copia=""
  problemas+=("nunca houve uma cópia bem sucedida, ou a marca desapareceu ($MARCA_COPIA)")
fi

if idade_prova="$(idade_de "$MARCA_PROVA")"; then
  if (( idade_prova > DIAS_ATE_QUEIXA_DA_PROVA * 86400 )); then
    problemas+=("a última cópia provada tem $(( idade_prova / 86400 )) dias — devia ter menos de ${DIAS_ATE_QUEIXA_DA_PROVA}")
  fi
else
  idade_prova=""
  problemas+=("nenhuma cópia foi alguma vez provada, ou a marca desapareceu ($MARCA_PROVA)")
fi

# Espaço: uma cópia diária que encha o disco não falha sozinha, leva o resto
# atrás.
livre_pct=""
if livre="$(df --output=pcent "$DESTINO" 2>/dev/null | tail -1 | tr -dc '0-9')"; then
  livre_pct=$(( 100 - livre ))
  if (( livre_pct < 10 )); then
    problemas+=("só ${livre_pct}% de disco livre em $DESTINO")
  fi
fi

if [[ "$modo" != banner ]]; then
  # A métrica escreve-se se houver onde. Não é ela que avisa — ver o cabeçalho.
  if [[ -d "$(dirname "$PROM")" && -w "$(dirname "$PROM")" ]]; then
    tmp="$(mktemp)"
    {
      echo "# HELP punho_copia_idade_segundos Idade da última cópia bem sucedida da base do Punho."
      echo "# TYPE punho_copia_idade_segundos gauge"
      [[ -n "$idade_copia" ]] && echo "punho_copia_idade_segundos $idade_copia"
      echo "# HELP punho_copia_prova_idade_segundos Idade da última cópia provada por restauro."
      echo "# TYPE punho_copia_prova_idade_segundos gauge"
      [[ -n "$idade_prova" ]] && echo "punho_copia_prova_idade_segundos $idade_prova"
      echo "# HELP punho_copia_problemas Quantos problemas a vigia encontrou."
      echo "# TYPE punho_copia_problemas gauge"
      echo "punho_copia_problemas ${#problemas[@]}"
    } > "$tmp"
    # chmod antes do mv: o node_exporter lê como outro utilizador, e um .prom
    # a 600 fica invisível sem dar erro nenhum. Já aconteceu com o speedtest.
    chmod 644 "$tmp"
    mv "$tmp" "$PROM"
  fi
fi

[[ "$modo" == metricas ]] && exit 0

if (( ${#problemas[@]} == 0 )); then
  if [[ "$modo" == humano ]]; then
    echo "✓ cópias do Punho em ordem"
    echo "   última cópia:  há $(( idade_copia / 3600 ))h"
    echo "   última prova:  há $(( idade_prova / 86400 )) dias"
    [[ -n "$livre_pct" ]] && echo "   disco livre:   ${livre_pct}%"
  fi
  exit 0
fi

# O banner é para ser visto de relance por cima do ombro, não lido.
echo
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  AS CÓPIAS DE SEGURANÇA DO PUNHO PRECISAM DE ATENÇÃO                 ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
for p in "${problemas[@]}"; do
  echo "  · $p"
done
echo
echo "  Ver:      tail -40 ${DESTINO%/punho}/punho.log"
echo "  Tentar:   ~/punho/scripts/copia_de_seguranca.sh"
echo
exit 1

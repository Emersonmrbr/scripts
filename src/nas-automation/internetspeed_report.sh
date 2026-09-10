#!/bin/bash

#------------------------------------------------------------------------------
# VARIABLES
#------------------------------------------------------------------------------
MINDOWNLOAD="" MINUPLOAD="" MAXLATENCY="" MAXJITTER="" AVERAGEDOWNLOAD="" AVERAGEUPLOAD="" AVERAGELATENCY="" AVERAGEJITTER="" AVERAGEPACKETLOSS="" STARTDATE="" ENDDATE="" YEAR="" MONTH="" TOTALMEASUREMENTS=""
DB_HOST="" DB_PORT="" DB_USER="" DB_PASSWORD="" DB_NAME=""

TODAY=$(date +%Y-%m-01)
LASTDAYLASTMONTH=$(date -d "$TODAY -1 day" +%Y-%m-%d)
FIRSTDAYLASTMONTH=$(date -d "$(date -d "$LASTDAYLASTMONTH" +%Y-%m-01)" +%Y-%m-%d)

MONTHYEAR=$(date -d "$LASTDAYLASTMONTH" +%m/%Y)
STARTDATE=$(date -d "$FIRSTDAYLASTMONTH" +%d/%m/%Y)
ENDDATE=$(date -d "$LASTDAYLASTMONTH" +%d/%m/%Y)
MONTHFILE=$(date -d "$LASTDAYLASTMONTH" +%Y_%m)

EMPRESA="Núcleo MAP - Máquinas, Automação e Programação"
CNPJ="30.945.466/0001-20"
RESPONSAVEL_TECNICO="Emerson Martins Brito"
CARGO="Especialista em software"
CONTATO="emerson@nucleomap.com.br"

TEMPLATE_PATH="./template_relatorio.md"
OUTPUT_DIR="/volume1/Reports"
ACTUAL_DATE=$(date +%d/%m/%Y)

CONTRACTED_SPEED_MBPS=1000
MINIMUM_ACCEPTABLE_MBPS_DOWNLOAD=$(echo "$CONTRACTED_SPEED_MBPS * 0.4" | bc)  # 40% of the contractored speed
MINIMUM_ACCEPTABLE_MBPS_UPLOAD=$(echo "$CONTRACTED_SPEED_MBPS * 0.2" | bc)  # 20% of the contractored speed
AVERAGE_ACCEPTABLE_MBPS_DOWNLOAD=$(echo "$CONTRACTED_SPEED_MBPS * 0.8" | bc)  # 80% of the contractored speed
AVERAGE_ACCEPTABLE_MBPS_UPLOAD=$(echo "$CONTRACTED_SPEED_MBPS * 0.4" | bc)  # 40% of the contractored speed
MAXIMUM_ACCEPTABLE_PING_MS=40
MONTHLY_TECHNICAL_ANALYSIS=""

ANALYSIS=""
TOOL=""

# Backup Configuration
readonly LOG_FILE="/volume1/logs/speedtest.log"

#------------------------------------------------------------------------------
# COLORS AND OUTPUT FUNCTIONS
#------------------------------------------------------------------------------

# Colors for logs (removed in cron, but useful for manual testing)
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  NC=''
fi

# Enhanced logging function
log() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  echo "[$timestamp] [$level] [PID:$$] $message" >> "$LOG_FILE"

  # If running in terminal, also show on screen
  if [ -t 1 ]; then
    case "$level" in
      "ERROR") echo -e "${RED}[$level]${NC} $message" ;;
      "SUCCESS") echo -e "${GREEN}[$level]${NC} $message" ;;
      "WARNING") echo -e "${YELLOW}[$level]${NC} $message" ;;
      *) echo -e "${BLUE}[$level]${NC} $message" ;;
    esac
  fi
}

# Function to display colored messages
print_status() {
  log "INFO" "$1"
}

print_success() {
  log "SUCCESS" "$1"
}

print_warning() {
  log "WARNING" "$1"
}

print_error() {
  log "ERROR" "$1"
}

#------------------------------------------------------------------------------
# CONFIGURATION SECTION
#------------------------------------------------------------------------------

load_configuration() {
  readonly ENV_FILE="/home/Emerson/.secrets.env"

  if [[ ! -f "$ENV_FILE" ]]; then
    print_error "Environment file $ENV_FILE not found. Please create it with the required variables."
    exit 1
  fi
  # Database Configuration
  DB_HOST=$(grep '^DB_HOST=' "$ENV_FILE" | cut -d "=" -f2-) || {
    print_error "DB_HOST not found. Please set environment variable or create $ENV_FILE"
    exit 1
  }
  DB_PORT=$(grep '^DB_PORT=' "$ENV_FILE" | cut -d '=' -f2-) || {
    print_error "DB_PORT not found. Please set environment variable or create $ENV_FILE"
    exit 1
  }
  DB_USER=$(grep '^DB_USER=' "$ENV_FILE" | cut -d '=' -f2-) || {
    print_error "DB_USER not found. Please set environment variable or create $ENV_FILE"
    exit 1
  }
  DB_PASSWORD=$(grep '^DB_PASSWORD=' "$ENV_FILE" | cut -d '=' -f2-) || {
    print_error "DB_PASSWORD not found. Please set environment variable or create $ENV_FILE"
    exit 1
  }
  DB_NAME=$(grep '^DB_NAME=' "$ENV_FILE" | cut -d '=' -f2-) || {
    print_error "DB_NAME not found. Please set environment variable or create $ENV_FILE"
    exit 1
  }

  print_success "Configuration loaded successfully"
  return 0

}

psql_config() {
  local -a docker_cmd=(docker)
  [[ "$(id -u)" -ne 0 ]] && docker_cmd=(sudo docker)
  "${docker_cmd[@]}" exec -i -e PGPASSWORD="$DB_PASSWORD" postgres-18 \
    psql --username="$DB_USER" --dbname="$DB_NAME" "$@"
}

# Check system dependencies
check_dependencies() {
  print_status "Checking system dependencies..."

  local -a missing_deps=()
  local -ar required_deps=("curl" "jq" "tar" "find" "docker")

  for dep in "${required_deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing_deps+=("$dep")
    fi
  done

  if [[ ${#missing_deps[@]} -ne 0 ]]; then
    print_error "Missing dependencies: ${missing_deps[*]}"
    print_status "Install with: apkg install ${missing_deps[*]}"
    return 1
  fi

  print_success "All dependencies satisfied"
  return 0
}

read_from_database() {
  print_status "Reading data from database..."
  read -r -d '' query <<SQL
SELECT
  MIN(download) AS MINDOWNLOAD,
  MIN(upload) AS MINUPLOAD,
  MAX(latency) AS MAXLATENCY,
  MAX(jitter) AS MAXJITTER,
  ROUND(AVG(download), 2) AS AVERAGEDOWNLOAD,
  ROUND(AVG(upload), 2) AS AVERAGEUPLOAD,
  ROUND(AVG(latency), 2) AS AVERAGELATENCY,
  ROUND(AVG(jitter), 2) AS AVERAGEJITTER,
  ROUND(AVG(packetloss), 2) AS AVERAGEPACKETLOSS,
  TO_CHAR(CURRENT_DATE - INTERVAL '1 month', 'YYYY-MM-01') AS STARTDATE,
  (DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month') + INTERVAL '1 month' - INTERVAL '1 day')::date AS ENDDATE,
  TO_CHAR(CURRENT_DATE, 'YYYY') AS YEAR,
  TO_CHAR(CURRENT_DATE, 'MM') AS MONTH,
  COUNT(*) AS TOTALMEASUREMENTS,
  tool AS TOOL
FROM results
WHERE datetime >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
AND datetime < DATE_TRUNC('month', CURRENT_DATE)
AND tool = '$1'
GROUP BY tool;
SQL
  dados=$(psql_config -tA -F $'\t' -c "$query") || {
    print_error "Failed to execute query: $query"
    exit 1
  }
  if [[ -z "$dados" ]]; then
    print_warning "No data found for the specified date range."
    exit 0
  fi
  IFS=$'\t' read -r MINDOWNLOAD MINUPLOAD MAXLATENCY MAXJITTER AVERAGEDOWNLOAD AVERAGEUPLOAD AVERAGELATENCY AVERAGEJITTER AVERAGEPACKETLOSS STARTDATE ENDDATE YEAR MONTH TOTALMEASUREMENTS TOOL <<<"$dados"
  print_success "Data retrieved successfully"

  echo "Minimum Download: $MINDOWNLOAD Mbps"
  echo "Minimum Upload: $MINUPLOAD Mbps"
  echo "Maximum Latency: $MAXLATENCY ms"
  echo "Maximum Jitter: $MAXJITTER ms"
  echo "Average Download: $AVERAGEDOWNLOAD Mbps"
  echo "Average Upload: $AVERAGEUPLOAD Mbps"
  echo "Average Latency: $AVERAGELATENCY ms"
  echo "Average Jitter: $AVERAGEJITTER ms"
  echo "Average Packet Loss: $AVERAGEPACKETLOSS %"
  echo "Date Range: $STARTDATE to $ENDDATE"
  echo "Total Measurements: $TOTALMEASUREMENTS"
  echo "Tool: $TOOL"
  echo "Year: $YEAR, Month: $MONTH"
}

generate_technical_analysis() {
    local alert_count=0

    ANALYSIS+=$(cat <<'EOF'
Durante o período avaliado, os indicadores de desempenho apresentaram comportamento compatível com o perfil do serviço monitorado.
EOF
    )

    if [[ -n "$MINDOWNLOAD" ]] && awk -v a="$MINDOWNLOAD" -v b="$MINIMUM_ACCEPTABLE_MBPS_DOWNLOAD" 'BEGIN{exit !(a<b)}'; then
        ANALYSIS+=$(cat <<EOF
\n**Alerta:** Velocidade mínima de download abaixo do esperado (${MINDOWNLOAD} Mbps).\n
EOF
        )
        alert_count=$((alert_count + 1))
    fi

    if [[ -n "$MINUPLOAD" ]] && awk -v a="$MINUPLOAD" -v b="$MINIMUM_ACCEPTABLE_MBPS_UPLOAD" 'BEGIN{exit !(a<b)}'; then
        ANALYSIS+=$(cat <<EOF
\n**Alerta:** Velocidade mínima de upload abaixo do esperado (${MINUPLOAD} Mbps).\n
EOF
        )
        alert_count=$((alert_count + 1))
    fi

    if [[ -n "$AVERAGEDOWNLOAD" ]] && awk -v a="$AVERAGEDOWNLOAD" -v b="$AVERAGE_ACCEPTABLE_MBPS_DOWNLOAD" 'BEGIN{exit !(a<b)}'; then
        ANALYSIS+=$(cat <<EOF
\n**Alerta:** Média mensal de download abaixo do esperado (${AVERAGEDOWNLOAD} Mbps).\n
EOF
        )
        alert_count=$((alert_count + 1))
    fi

    if [[ -n "$AVERAGEUPLOAD" ]] && awk -v a="$AVERAGEUPLOAD" -v b="$AVERAGE_ACCEPTABLE_MBPS_UPLOAD" 'BEGIN{exit !(a<b)}'; then
        ANALYSIS+=$(cat <<EOF
\n**Alerta:** Média mensal de upload abaixo do esperado (${AVERAGEUPLOAD} Mbps).
EOF
        )
        alert_count=$((alert_count + 1))
    fi

    if [[ -n "$MAXLATENCY" ]] && awk -v a="$MAXLATENCY" -v b="$MAXIMUM_ACCEPTABLE_PING_MS" 'BEGIN{exit !(a>b)}'; then
        ANALYSIS+=$(cat <<EOF
\n**Alerta:** Latência máxima registrada acima do aceitável (${MAXLATENCY} ms).
EOF
        )
        alert_count=$((alert_count + 1))
    fi

    if [[ $alert_count -eq 0 ]]; then
        ANALYSIS+=$(cat <<EOF
\nNão foram observadas degradações persistentes que comprometessem a qualidade da conexão durante o mês de referência.
EOF
        )
    fi

    return 0
}

report_markdown(){
  if ! cp "$TEMPLATE_PATH" "$OUTPUT_DIR/$1_$MONTHFILE.md"; then
    echo "Erro ao copiar o template para o diretório de saída."
    return 1
  fi
  local analysis_sed
  analysis_sed=$(printf '%s' "$ANALYSIS" | sed ':a;N;$!ba;s/\n/\\\n/g')
  sed -i "s/{ANALISE_TECNICA_MENSAL}/$analysis_sed/g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s/{EMPRESA}/$EMPRESA/g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s#{CNPJ}#$CNPJ#g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s/{RESPONSAVEL_TECNICO}/$RESPONSAVEL_TECNICO/g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s/{CONTATO}/$CONTATO/g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s/{CARGO}/$CARGO/g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s/{TOOL}/$TOOL/g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s#{DATA_EMISSAO}#$ACTUAL_DATE#g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s/{MIN_DOWNLOAD}/$MINDOWNLOAD/g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s/{MIN_UPLOAD}/$MINUPLOAD/g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s/{MAX_LATENCY}/$MAXLATENCY/g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s/{MAX_JITTER}/$MAXJITTER/g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s/{MEDIA_DOWNLOAD}/$AVERAGEDOWNLOAD/g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s/{MEDIA_UPLOAD}/$AVERAGEUPLOAD/g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s/{MEDIA_PING}/$AVERAGELATENCY/g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s/{MEDIA_JITTER}/$AVERAGEJITTER/g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s/{MEDIA_PERDA}/$AVERAGEPACKETLOSS/g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s#{DATA_INICIO}#$STARTDATE#g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s#{DATA_FIM}#$ENDDATE#g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s/{TOTAL_MEDICOES}/$TOTALMEASUREMENTS/g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s/{MES}/$MONTH/g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
  sed -i "s/{ANO}/$YEAR/g" "$OUTPUT_DIR/$1_$MONTHFILE.md"
}

hash_generator(){
  local file="$1"
  if [[ -z "$file" ]]; then
    echo "Usage: hash_generator <file>"
    return 1
  fi
  if [[ ! -f "$file" ]]; then
    echo "File not found: $file"
    return 1
  fi
  sha256sum "$file" > "$file.sha256"
}

#------------------------------------------------------------------------------
# MAIN EXECUTION
#------------------------------------------------------------------------------

main() {
  load_configuration || exit 1
  check_dependencies || exit 1
  read_from_database "speedtest" || exit 1
  generate_technical_analysis || exit 1
  report_markdown "SPEEDTEST_REPORT" || exit 1
  hash_generator "$OUTPUT_DIR/SPEEDTEST_REPORT_$MONTHFILE.md" || exit 1
}

main "$@"

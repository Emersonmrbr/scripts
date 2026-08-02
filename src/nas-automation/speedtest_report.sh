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
CARGO="Especialista em automação"
CONTATO="emerson@nucleomap.com.br"

TEMPLATE_PATH="template_relatorio.md"
OUTPUT_DIR="/volume1/Reports"

CONTRACTED_SPEED_MBPS=1000
MINIMUM_ACCEPTABLE_MBPS_DOWNLOAD=$(echo "$CONTRACTED_SPEED_MBPS * 0.4" | bc)  # 40% of the contractored speed
MINIMUM_ACCEPTABLE_MBPS_UPLOAD=$(echo "$CONTRACTED_SPEED_MBPS * 0.2" | bc)  # 20% of the contractored speed
AVERAGE_ACCEPTABLE_MBPS_DOWNLOAD=$(echo "$CONTRACTED_SPEED_MBPS * 0.8" | bc)  # 80% of the contractored speed
AVERAGE_ACCEPTABLE_MBPS_UPLOAD=$(echo "$CONTRACTED_SPEED_MBPS * 0.4" | bc)  # 40% of the contractored speed
MAXIMUM_ACCEPTABLE_PING_MS=40
MONTHLY_TECHNICAL_ANALYSIS=""

ANALYSIS=""

# Backup Configuration
readonly LOG_FILE="/volume1/logs/speedtest.log"

#------------------------------------------------------------------------------
# COLORS AND OUTPUT FUNCTIONS
#------------------------------------------------------------------------------

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No color

# Logging function
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to display colored messages
print_status() {
  echo -e "${BLUE}[INFO]${NC} $1"
  log "INFO: $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
  log "SUCCESS: $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
  log "WARNING: $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
  log "ERROR: $1"
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

mysql_config() {
  mysql \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --user="$DB_USER" \
    --password="$DB_PASSWORD" \
    "$DB_NAME" "$@"
}

# Check system dependencies
check_dependencies() {
  print_status "Checking system dependencies..."

  local -a missing_deps=()
  local -ar required_deps=("curl" "jq" "tar" "find" "mysql")

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
  read -r -d '' query <<'SQL'
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
  DATE_FORMAT(CURRENT_DATE - INTERVAL 1 MONTH, '%Y-%m-01') AS STARTDATE,
  DATE_FORMAT(CURRENT_DATE, '%Y-%m-01') AS ENDDATE,
  DATE_FORMAT(CURRENT_DATE, '%Y') AS YEAR,
  DATE_FORMAT(CURRENT_DATE, '%m') AS MONTH,
  COUNT(*) AS TOTALMEASUREMENTS
FROM results
WHERE datetime >= DATE_FORMAT(CURRENT_DATE - INTERVAL 1 MONTH, '%Y-%m-01')
AND datetime < DATE_FORMAT(CURRENT_DATE, '%Y-%m-01');
SQL
  dados=$(mysql_config -N -e "$query") || {
    print_error "Failed to execute query: $query"
    exit 1
  }
  if [[ -z "$dados" ]]; then
    print_warning "No data found for the specified date range."
    exit 0
  fi
  IFS=$'\t' read -r MINDOWNLOAD MINUPLOAD MAXLATENCY MAXJITTER AVERAGEDOWNLOAD AVERAGEUPLOAD AVERAGELATENCY AVERAGEJITTER AVERAGEPACKETLOSS STARTDATE ENDDATE YEAR MONTH TOTALMEASUREMENTS <<<"$dados"
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
  echo "Year: $YEAR, Month: $MONTH"
}

generate_technical_analysis() {

    ANALYSIS+=$(cat <<'EOF'
Durante o período avaliado, os indicadores de desempenho
        apresentaram comportamento compatível com o perfil do serviço monitorado.
EOF
    )

    if [[ -n "$MINDOWNLOAD" && "$MINDOWNLOAD" -lt "$MINIMUM_ACCEPTABLE_MBPS_DOWNLOAD" ]]; then
        ANALYSIS+=$(cat <<EOF
**Alerta:** Velocidade mínima de download abaixo do esperado (${MINDOWNLOAD} Mbps).
EOF
        )
    fi

    if [[ -n "$MINUPLOAD" && "$MINUPLOAD" -lt "$MINIMUM_ACCEPTABLE_MBPS_UPLOAD" ]]; then
        ANALYSIS+=$(cat <<EOF
**Alerta:** Velocidade mínima de upload abaixo do esperado (${MINUPLOAD} Mbps).
EOF
        )
    fi

    if [[ -n "$AVERAGEDOWNLOAD" && "$AVERAGEDOWNLOAD" -lt "$AVERAGE_ACCEPTABLE_MBPS_DOWNLOAD" ]]; then
        ANALYSIS+=$(cat <<EOF
**Alerta:** Média mensal de download abaixo do esperado (${AVERAGEDOWNLOAD} Mbps).
EOF
        )
    fi

    if [[ -n "$AVERAGEUPLOAD" && "$AVERAGEUPLOAD" -lt "$AVERAGE_ACCEPTABLE_MBPS_UPLOAD" ]]; then
        ANALYSIS+=$(cat <<EOF
**Alerta:** Média mensal de upload abaixo do esperado (${AVERAGEUPLOAD} Mbps).
EOF
        )
    fi

    if [[ -n "$MAXLATENCY" && "$MAXLATENCY" -gt "$MAXIMUM_ACCEPTABLE_PING_MS" ]]; then
        ANALYSIS+=$(cat <<EOF
**Alerta:** Latência máxima registrada acima do aceitável (${MAXLATENCY} ms).
EOF
        )
    fi

    if [[ ${#ANALYSIS[@]} -eq 1 ]]; then
        ANALYSIS+=$(cat <<EOF
Não foram observadas degradações persistentes que comprometessem a qualidade da conexão durante o mês de referência.
EOF
        )
    fi

    return 0
}

#------------------------------------------------------------------------------
# MAIN EXECUTION
#------------------------------------------------------------------------------

main() {
  load_configuration || exit 1
  check_dependencies || exit 1
  read_from_database || exit 1
}

main "$@"

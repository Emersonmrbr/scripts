#! /bin/bash

# Reset the output file with reachable hosts for the current run.
rm -f "$HOME/Documents/reachable/reachable_hosts.txt"

# Limit the number of concurrent ping jobs to avoid overwhelming the system.
MAX_JOBS=50
TOTAL=0
TOTALSCAN=$(mktemp)
TOTALFOUND=$(mktemp)
TMPCOUNT=$(mktemp)
TMPFOUND=$(mktemp)
echo 0 > "$TOTALSCAN"
echo 0 > "$TOTALFOUND"
echo 0 > "$TMPCOUNT"
echo 0 > "$TMPFOUND"
STARTTIME=$(date +%s)


echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "► Starting ping scan at $(date +"%d/%m/%Y %H:%M:%S")"
echo "  Max concurrent jobs: $MAX_JOBS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

trap 'rm -f "$TMPCOUNT" "$TMPFOUND" "$TOTALFOUND" "$TOTALSCAN"' EXIT

if [ ! -d "$HOME/Documents/reachable" ]; then
  mkdir -p "$HOME/Documents/reachable"
fi

# Probe a single host, safely update shared counters, and refresh the progress display.
ping_host() {
    local ip="$1"
    local current found pct filled empty_count bar empty_bar

    if ping -c 1 -w 1 "$ip" > /dev/null 2>&1; then
        flock "$TMPFOUND" -c "valfound=\$(cat '$TMPFOUND'); echo \$((valfound + 1)) > '$TMPFOUND'"
        flock "$TOTALFOUND" -c "valtotal=\$(cat '$TOTALFOUND'); echo \$((valtotal + 1)) > '$TOTALFOUND'"
        echo "$ip" >> "$HOME/Documents/reachable/reachable_hosts.txt"
        echo -e "\n[+] Host $ip is reachable!"
    fi

    flock "$TMPCOUNT" -c "valcount=\$(cat '$TMPCOUNT'); echo \$((valcount + 1)) > '$TMPCOUNT'"
    flock "$TOTALSCAN" -c "valscan=\$(cat '$TOTALSCAN'); echo \$((valscan + 1)) > '$TOTALSCAN'"

    # Read counters defensively and fall back to zero if reads fail temporarily.
    current=$(cat "$TMPCOUNT" 2>/dev/null); current=${current:-0}
    found=$(cat "$TMPFOUND" 2>/dev/null);   found=${found:-0}

    # Ensure values are numeric before performing arithmetic.
    [[ "$current" =~ ^[0-9]+$ ]] || current=0
    [[ "$found"   =~ ^[0-9]+$ ]] || found=0

    pct=$(( current * 100 / TOTAL ))
    filled=$(( pct / 2 ))
    [ "$filled" -gt 50 ] && filled=50
    empty_count=$(( 50 - filled ))

    bar=$(head -c "$filled" /dev/zero | tr '\0' '#')
    empty_bar=$(head -c "$empty_count" /dev/zero | tr '\0' '-')

    printf "\r[%s%s] %3d%% (%d/%d) — ativos: %d" \
        "$bar" "$empty_bar" "$pct" "$current" "$TOTAL" "$found"
}

# Cap the amount of concurrent background jobs to keep resource usage predictable.
throttle(){
  while [ "$(jobs -r | wc -l)" -ge "$MAX_JOBS" ]; do
    sleep 0.1
  done
}
  
# Determine the total number of scan targets from the provided IP pattern.
calc_total() {
    local o1="$1" o2="$2" o3="$3" o4="$4"
    if   [ -n "$o1" ] && [ -n "$o2" ] && [ -z "$o3" ] && [ -z "$o4" ]; then
        TOTAL=$((255 * 255))   # /16 range
    elif [ -n "$o1" ] && [ -n "$o2" ] && [ -n "$o3" ] && [ -z "$o4" ]; then
        TOTAL=255              # /24 range
    else
        TOTAL=1                # single host
    fi
}

validate_octet(){
  local oct="$1"
  [[ "$oct" =~ ^[0-9]{1,3}$ ]] && [ "$oct" -ge 0 ] && [ "$oct" -le 255 ]
}

# Convert seconds to a "M.D" minutes string without relying on bc.
secs_to_min() {
  local s="$1"
  printf "%d.%d" $(( s / 60 )) $(( (s % 60) * 10 / 60 ))
}

    # Run a scan for a /16, /24, or single-host target, based on input granularity.
test_address() {
  local o1="$1" o2="$2" o3="$3" o4="$4"
  local EST_SECS EST_MIN STARTCYCLE
  echo 0 > "$TMPCOUNT"
  echo 0 > "$TMPFOUND"
  STARTCYCLE=$(date +%s)
  calc_total "$o1" "$o2" "$o3" "$o4"
  EST_SECS=$(( TOTAL / MAX_JOBS ))
  EST_MIN=$(secs_to_min "$EST_SECS")


  echo -e "\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "► Start cycle : ${o1}.${o2}.${o3:-*}.${o4:-*}"
  echo "► Start cycle time  : $(date +"%d/%m/%Y %H:%M:%S")"
  echo "► Total hosts: $TOTAL"
  echo "► Jobs       : $MAX_JOBS"
  echo "► Estimated  : ~${EST_SECS}s (~${EST_MIN} min) (100ms~1s/ping, $MAX_JOBS parallel)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # If only two octets were provided (e.g., 192.168), scan a /16 range.
  if [ -n "$o1" ] && [ -n "$o2" ] && [ -z "$o3" ] && [ -z "$o4" ]; then
    if validate_octet "$o1" && validate_octet "$o2"; then
      for i in {0..254}; do
        for j in {0..254}; do
          ping_host "${o1}.${o2}.$i.$j" &
          throttle
        done
      done
    else
      echo "Invalid IP address format: ${o1}.${o2}.*.*"
      exit 1
    fi
  # If three octets were provided (e.g., 192.168.1), scan a /24 range.
  elif [ -n "$o1" ] && [ -n "$o2" ] && [ -n "$o3" ] && [ -z "$o4" ]; then
    if validate_octet "$o1" && validate_octet "$o2" && validate_octet "$o3"; then
      for i in {0..254}; do
        ping_host "${o1}.${o2}.${o3}.$i" &
        throttle
      done
    else
      echo "Invalid IP address format: ${o1}.${o2}.${o3}.*"
      exit 1
    fi
  # If a full IP address was provided, test only that single host.
  elif [ -n "$o1" ] && [ -n "$o2" ] && [ -n "$o3" ] && [ -n "$o4" ]; then
    if validate_octet "$o1" && validate_octet "$o2" && validate_octet "$o3" && validate_octet "$o4"; then
        ping_host "${o1}.${o2}.${o3}.${o4}"
    else
        echo "Invalid IP address format: ${o1}.${o2}.${o3}.${o4}"
        exit 1
    fi
  else
      echo "Invalid IP address format."
      exit 1
  fi

  wait
  ELAPSEDSEC=$(( $(date +%s) - STARTCYCLE ))
  ELAPSEDMIN=$(secs_to_min "$ELAPSEDSEC")
  echo -e "\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "► Cycle finished — $(cat "$TMPFOUND") host(s) found in ${ELAPSEDSEC}s (~${ELAPSEDMIN} min)."
  echo "► End cycle time  : $(date +"%d/%m/%Y %H:%M:%S")"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

}

if [ -z "$1" ]; then
  if [ ! -f "$HOME/.local/lib/.pingplus/ip_address.txt" ]; then
  mkdir -p "$HOME/.local/lib/.pingplus"
cat > "$HOME/.local/lib/.pingplus/ip_address.txt" << 'EOF'
192.168.0
192.168.1
192.168.2
192.168.3
192.168.10
192.168.100
192.168.250
10.0.0
10.0.1
10.1.1
10.10.1
10.10.10
172.16.0
172.16.1
172.16.10
169.254.0
169.254.1
EOF
    echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Creating new IP address list at $HOME/.local/lib/.pingplus/ip_address.txt"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  else
    echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Using existing IP address list from $HOME/.local/lib/.pingplus/ip_address.txt"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi

  # Without a CLI argument, load target patterns from the configured address list file.
  mapfile -t ADDRESSLIST < "$HOME/.local/lib/.pingplus/ip_address.txt"
  for ENTRY in "${ADDRESSLIST[@]}"; do
  ENTRY="${ENTRY//[$' \t\r\n']/}"  # Trim whitespace and newlines
  [[ -z "$ENTRY" || "$ENTRY" =~ ^# ]] && continue  # Skip empty lines and comments
    IFS='.' read -ra OCT <<< "$ENTRY"
    test_address "${OCT[0]}" "${OCT[1]}" "${OCT[2]}" "${OCT[3]}"
  done
else
  # With a CLI argument, scan only the supplied target pattern.
  IFS='.' read -ra OCT <<< "$1"
  test_address "${OCT[0]}" "${OCT[1]}" "${OCT[2]}" "${OCT[3]}"
fi

TOTALSEC=$(( $(date +%s) - STARTTIME ))
TOTALMIN=$(secs_to_min "$TOTALSEC")
echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "► End ping scan — $(cat "$TOTALFOUND") host(s) found in ${TOTALSEC}s (~${TOTALMIN} min)."
echo "► End ping scan  : $(date +"%d/%m/%Y %H:%M:%S")"
echo "► Total hosts scanned: $(cat "$TOTALSCAN")"
echo "► Total reachable hosts: $(cat "$TOTALFOUND")"
echo "► Reachable hosts saved to: $HOME/Documents/reachable/reachable_hosts.txt"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
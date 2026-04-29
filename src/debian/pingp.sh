#! /bin/bash

# Reset the output file with reachable hosts for the current run.
rm -f reachable_hosts.txt

# Limit the number of concurrent ping jobs to avoid overwhelming the system.
MAX_JOBS=50
TOTAL=0
TMPCOUNT=$(mktemp)
TMPFOUND=$(mktemp)
echo 0 > "$TMPCOUNT"
echo 0 > "$TMPFOUND"

trap 'rm -f "$TMPCOUNT" "$TMPFOUND"' EXIT

ping_host() {
    local ip="$1"
    local current found pct filled empty_count bar empty_bar

    if ping -c 1 -w 1 "$ip" > /dev/null 2>&1; then
        flock "$TMPFOUND" -c "val=\$(cat '$TMPFOUND'); echo \$((val + 1)) > '$TMPFOUND'"
        echo "$ip" >> reachable_hosts.txt
        echo -e "\n[+] Host $ip is reachable!"
    fi

    flock "$TMPCOUNT" -c "val=\$(cat '$TMPCOUNT'); echo \$((val + 1)) > '$TMPCOUNT'"

    # Leitura protegida com valor default
    current=$(cat "$TMPCOUNT" 2>/dev/null); current=${current:-0}
    found=$(cat "$TMPFOUND" 2>/dev/null);   found=${found:-0}

    # Garante que são números antes de qualquer aritmética
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

throttle(){
  while [ "$(jobs -r | wc -l)" -ge "$MAX_JOBS" ]; do
    sleep 0.1
  done
}
  
calc_total() {
    local o1="$1" o2="$2" o3="$3" o4="$4"
    if   [ -n "$o1" ] && [ -n "$o2" ] && [ -z "$o3" ] && [ -z "$o4" ]; then
        TOTAL=$((255 * 255))   # /16
    elif [ -n "$o1" ] && [ -n "$o2" ] && [ -n "$o3" ] && [ -z "$o4" ]; then
        TOTAL=255              # /24
    else
        TOTAL=1                # host único
    fi
}

test_address() {
  local o1="$1" o2="$2" o3="$3" o4="$4"
  echo 0 > "$TMPCOUNT"
  echo 0 > "$TMPFOUND"
  calc_total "$o1" "$o2" "$o3" "$o4"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "► Start scan: ${o1}.${o2}.${o3:-*}.${o4:-*}"
  echo "  Total hosts : $TOTAL"
  echo "  Jobs: $MAX_JOBS"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # If only two octets were provided (e.g., 192.168), scan a /16 range.
  if [ -n "$o1" ] && [ -n "$o2" ] && [ -z "$o3" ] && [ -z "$o4" ]; then
    for i in {0..254}; do
      for j in {0..254}; do
        ping_host "${o1}.${o2}.$i.$j" &
        throttle
      done
    done
  # If three octets were provided (e.g., 192.168.1), scan a /24 range.
  elif [ -n "$o1" ] && [ -n "$o2" ] && [ -n "$o3" ] && [ -z "$o4" ]; then
    for i in {0..254}; do
      ping_host "${o1}.${o2}.${o3}.$i" &
      throttle
    done
  # If a full IP address was provided, test only that single host.
  elif [ -n "$o1" ] && [ -n "$o2" ] && [ -n "$o3" ] && [ -n "$o4" ]; then
      ping_host "${o1}.${o2}.${o3}.${o4}"
  else
      echo "Invalid IP address format."
      exit 1
  fi

  wait
  echo -e "\n► Scan concluído — $(cat "$TMPFOUND") host(s) encontrado(s)."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

}

if [ -z "$1" ]; then
 mapfile -t ADDRESSLIST < "$HOME/.local/bin/ip_address.txt"
  for ENTRY in "${ADDRESSLIST[@]}"; do
    IFS='.' read -ra OCT <<< "$ENTRY"
    test_address "${OCT[0]}" "${OCT[1]}" "${OCT[2]}" "${OCT[3]}"
  done
else
  IFS='.' read -ra OCT <<< "$1"
  test_address "${OCT[0]}" "${OCT[1]}" "${OCT[2]}" "${OCT[3]}"
fi
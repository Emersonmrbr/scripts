#! /bin/bash

# Reset the output file with reachable hosts for the current run.
rm -f reachable_hosts.txt

# Limit the number of concurrent ping jobs to avoid overwhelming the system.
MAX_JOBS=50
TOTAL=0
TMPCOUNT=$(mktemp)
TMPFOUND=$(mktemp)
STARTTIME=$(date +%s)
echo 0 > "$TMPCOUNT"
echo 0 > "$TMPFOUND"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "► Starting ping scan at $(date +"%d/%m/%Y %H:%M:%S")"
echo "  Max concurrent jobs: $MAX_JOBS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

trap 'rm -f "$TMPCOUNT" "$TMPFOUND"' EXIT

# Probe a single host, safely update shared counters, and refresh the progress display.
ping_host() {
    local ip="$1"
    local current found pct filled empty_count bar empty_bar

    if ping -c 1 -w 1 "$ip" > /dev/null 2>&1; then
        flock "$TMPFOUND" -c "val=\$(cat '$TMPFOUND'); echo \$((val + 1)) > '$TMPFOUND'"
        echo "$ip" >> "$HOME/Documents/reachable/reachable_hosts.txt"
        echo -e "\n[+] Host $ip is reachable!"
    fi

    flock "$TMPCOUNT" -c "val=\$(cat '$TMPCOUNT'); echo \$((val + 1)) > '$TMPCOUNT'"

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

    # Run a scan for a /16, /24, or single-host target, based on input granularity.
test_address() {
  local o1="$1" o2="$2" o3="$3" o4="$4"
  local EST_SECS EST_MIN
  echo 0 > "$TMPCOUNT"
  echo 0 > "$TMPFOUND"
  calc_total "$o1" "$o2" "$o3" "$o4"
  EST_SECS=$(echo "scale=0; $TOTAL * 1 / $MAX_JOBS" | bc)  # 100ms = ~1s por job em paralelo
  EST_MIN=$(echo "scale=1; $EST_SECS / 60" | bc)


  echo -e "\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "► Start cycle : ${o1}.${o2}.${o3:-*}.${o4:-*}"
  echo "► Start cycle time  : $(date +"%d/%m/%Y %H:%M:%S")"
  echo "► Total hosts: $TOTAL"
  echo "► Jobs       : $MAX_JOBS"
  echo "► Estimated  : ~${EST_SECS}s (~${EST_MIN} min) (100ms/ping, $MAX_JOBS parallel)"
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
  ELAPSEDSEC=$((($(date +%s) - STARTTIME) *1))
  ELAPSEDMIN=$(echo "scale=1; $ELAPSEDSEC / 60" | bc)
  echo -e "\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "► Cycle finished — $(cat "$TMPFOUND") host(s) found in ${ELAPSEDSEC}s (~${ELAPSEDMIN} min)."
  echo "► End cycle time  : $(date +"%d/%m/%Y %H:%M:%S")"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

}

if [ -z "$1" ]; then

  if [ ! -f "$HOME/.local/lib/pingplus/ip_address.txt" ]; then
    echo "192.168.0
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
    169.254.1" > "$HOME/.local/lib/pingplus/ip_address.txt"  # Example target; replace with actual targets as needed.
    echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Creating new IP address list at $HOME/.local/lib/pingplus/ip_address.txt"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  else
    echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Using existing IP address list from $HOME/.local/lib/pingplus/ip_address.txt"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi

  # Without a CLI argument, load target patterns from the configured address list file.
  mapfile -t ADDRESSLIST < "$HOME/.local/lib/pingplus/ip_address.txt"
  for ENTRY in "${ADDRESSLIST[@]}"; do
    IFS='.' read -ra OCT <<< "$ENTRY"
    test_address "${OCT[0]}" "${OCT[1]}" "${OCT[2]}" "${OCT[3]}"
  done
else
  # With a CLI argument, scan only the supplied target pattern.
  IFS='.' read -ra OCT <<< "$1"
  test_address "${OCT[0]}" "${OCT[1]}" "${OCT[2]}" "${OCT[3]}"
fi

TOTALSEC=$((($(date +%s) - STARTTIME) *1))
TOTALMIN=$(echo "scale=1; $TOTALSEC / 60" | bc)
echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "► End ping scan — $(cat "$TMPFOUND") host(s) found in ${TOTALSEC}s (~${TOTALMIN} min)."
echo "► End ping scan  : $(date +"%d/%m/%Y %H:%M:%S")"
echo "► Total hosts scanned: $TOTAL"
echo "► Total reachable hosts: $(cat "$TMPFOUND")"
echo "► Reachable hosts saved to: $HOME/Documents/reachable/reachable_hosts.txt"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
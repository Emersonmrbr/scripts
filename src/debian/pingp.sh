#! /bin/bash

rm -f reachable_hosts.txt

ADDRESS[0]=$(cut -d "." -f 1 <<< "$1")
ADDRESS[1]=$(cut -d "." -f 2 <<< "$1")
ADDRESS[2]=$(cut -d "." -f 3 <<< "$1")
ADDRESS[3]=$(cut -d "." -f 4 <<< "$1")

if [ -z "${ADDRESS[2]}" ] && [ -z "${ADDRESS[3]}" ]; then
  for i in {0..254}; do
    for j in {0..254}; do
      if sudo ping -c 1 -f -i 0.1 "${ADDRESS[0]}.${ADDRESS[1]}.$i.$j" > /dev/null 2>&1; then
        echo "Host ${ADDRESS[0]}.${ADDRESS[1]}.$i.$j is reachable."
        echo "${ADDRESS[0]}.${ADDRESS[1]}.$i.$j" >> reachable_hosts.txt
      else
        echo "Host ${ADDRESS[0]}.${ADDRESS[1]}.$i.$j is not reachable."
      fi
    done
  done
fi

if [ -n "${ADDRESS[0]}" ] && [ -n "${ADDRESS[1]}" ] && [ -n "${ADDRESS[2]}" ] && [ -z "${ADDRESS[3]}" ]; then
  for i in {0..254}; do
    if sudo ping -c 1 -f -i 0.1 "${ADDRESS[0]}.${ADDRESS[1]}.${ADDRESS[2]}.$i" > /dev/null 2>&1; then
      echo "Host ${ADDRESS[0]}.${ADDRESS[1]}.${ADDRESS[2]}.$i is reachable."
      echo "${ADDRESS[0]}.${ADDRESS[1]}.${ADDRESS[2]}.$i" >> reachable_hosts.txt
    else
      echo "Host ${ADDRESS[0]}.${ADDRESS[1]}.${ADDRESS[2]}.$i is not reachable."
    fi
  done
fi

if ping -c 1 -i 0.1 "${1}" > /dev/null 2>&1; then
    echo "Host ${1} is reachable."
    exit 0
else
    echo "Host ${1} is not reachable."
    exit 1
fi
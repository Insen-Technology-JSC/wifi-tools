#!/bin/bash

# type definitions
MACHINE_MACOS=1
MACHINE_LINUX=2
MACHINE_WINDOW=3

check_os() {
  if [ "$(uname)" == "Darwin" ]; then
      echo "Machine is Mac, currently not support"
      machine_os=$MACHINE_MACOS
      exit 1
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
      echo "Machine is Linux"
      machine_os=$MACHINE_LINUX
    elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
      echo "Machine is Window, currently not support"
      machine_os=$MACHINE_WINDOW
      exit 1
    else
      echo "Unsupported operating system"
      exit 1
    fi
}

check_packages() {
  if command -v iwconfig &>/dev/null; then
    echo "iwconfig: installed"
  else
    echo "iwconfig command not found"
    echo "Please install: sudo apt install wireless-tools"
    exit 1
  fi
}

read_interval() {
  read -p "Enter data collection interval (seconds): " interval
  if ! [[ "$interval" =~ ^[0-9]+$ ]] || [ "$interval" -lt 1 ]; then
    echo "Invalid input. Interval must be a positive integer."
    read_interval
  fi
}

main_loop() {
  read_interval
  echo "date, rssi (dBm), LQI" >> $filename
  echo "date, rssi (dBm), LQI"
  while true; do
    current_time=$(date "+%Y-%m-%d %H:%M:%S")
    # Get Link Quality and Signal Level using iwconfig
    iwconfig_output=$(iwconfig "$interface")
    # Extract Link Quality and Signal Level using awk
    link_quality=$(echo "$iwconfig_output" | awk -F'Quality=' '/Link Quality/{print $2}' | awk '{print $1}')
    signal_level=$(echo "$iwconfig_output" | awk -F'Signal level=' '/Signal level/{print $2}' | awk '{print $1}')
    echo "$current_time, $signal_level, $link_quality" >> $filename
    echo -n "$current_time, $signal_level, $link_quality    "
    for ((i = -100; i <= 0; i += 1)); do
      if [ "$signal_level" -ge "$i" ]; then
        echo -n "#"
      else
        echo -n "-"
      fi
    done
    echo ""
    sleep $interval
  done
}

# check os
check_os
echo "machine: $machine_os"

# check package
check_packages

# create file with timestamp
timestamp=$(date "+%Y%m%d%H%M%S")
filename="wifi_stats_${timestamp}.csv"

# Get a list of wireless interfaces
wireless_interfaces=$(iwconfig 2>/dev/null | grep 'IEEE 802.11' | awk '{print $1}')

# Check the number of wireless interfaces
num_interfaces=$(echo "$wireless_interfaces" | wc -w)

if [ "$num_interfaces" -eq 0 ]; then
    echo "No wireless interfaces found."
    exit 1
elif [ "$num_interfaces" -eq 1 ]; then
    interface="$wireless_interfaces"
    echo "Wi-Fi connected on interface: $interface"
    iwconfig "$interface"
    main_loop
else
    echo "Choose interface:"
    select interface in $wireless_interfaces; do
        if [[ ! -z "$interface" ]]; then
            echo "Wi-Fi connected on interface: $interface"
            iwconfig "$interface"
            main_loop
            break
        else
            echo "Invalid selection. Please choose a valid interface."
        fi
    done
fi

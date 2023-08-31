# Script: wifi_collector.sh
# Tool: Wi-Fi Statistics Collector
# Description: Collects Wi-Fi statistics (Link Quality and Signal Level) over time.
# Author: ImSentecs develop team.
# Date: 2023-09-02
# Company: InSentecs

#!/bin/bash

# add libs
. common/color.sh
. common/insentecs.sh

echo -e ${header}

# type definitions
MACHINE_MACOS=1
MACHINE_LINUX=2
MACHINE_WINDOW=3

# default interval = 2s
INTERVAL=2
# default measurement time = 5m
MEASUREMENT_TIME=5

# config max/min 
RSSI_MAX=0
RSSI_MIN=-100
RSSI_GREEN_MAX=0
RSSI_GREEN_MIN=-50
RSSI_YELLOW_MAX=-50 
RSSI_YELLOW_MIN=-70
RSSI_RED_MAX=-70
RSSI_RED_MIN=-85
RSSI_CYAN_MAX=-85
RSSI_CYAN_MIN=-100

# create file with timestamp
timestamp=$(date "+%Y%m%d%H%M%S")
FILENAME="data_${timestamp}.csv"

# @func: check current os
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

# @func: check packagas
check_packages() {
  if command -v iwconfig &>/dev/null; then
    echo "iwconfig: installed"
  else
    echo "iwconfig command not found"
    echo "Please install: sudo apt install wireless-tools"
    exit 1
  fi
}

# @func: read interval in seconds
read_interval() {
  read -p "Enter interval (seconds) [$INTERVAL]: " interval
  if [[ -z "$interval" ]]; then
    interval=$INTERVAL
  elif ! [[ "$interval" =~ ^[0-9]+$ ]] || [ "$interval" -lt 1 ]; then
    echo "Invalid input. Interval must be a positive integer."
    read_interval
  fi
}

# @func: read measurement time in minutes
read_measurement_time() {
  read -p "Enter measurement time (minutes) [$MEASUREMENT_TIME]: " measurement_time
  if [[ -z "$measurement_time" ]]; then
    measurement_time=$MEASUREMENT_TIME
  elif  ! [[ "$measurement_time" =~ ^[0-9]+$ ]] || [ "$measurement_time" -lt 1 ]; then
    echo "Invalid input. Interval must be a positive integer."
    read_measurement_time
  fi
  measurement_time=$((measurement_time*60))
  # echo "$measurement_time in seconds"
}

# @func: read filename
read_filename() {
  read -p "Enter filename [$FILENAME]: " filename
  if [[ -z "$filename" ]]; then
    filename=$FILENAME
  elif [[ "$filename" != *".csv" ]]; then
    filename="${filename}.csv"
  fi
}

# @func: get statistics 
get_wifi_stats() {
  # Get current time
  current_time=$(date "+%Y-%m-%d %H:%M:%S")
  
  # Get Link Quality and Signal Level using iwconfig
  iwconfig_output=$(iwconfig "$interface")

  # Extract Link Quality using awk
  link_quality=$(echo "$iwconfig_output" | awk -F'Quality=' '/Link Quality/{print $2}' | awk '{print $1}')
  # Split the link_quality string into parts using the slash delimiter
  IFS='/' read -ra link_quality_parts <<< "$link_quality"
  # Get the values of xx and yy
  xx="${link_quality_parts[0]}"
  yy="${link_quality_parts[1]}"
  link_quality_percent=$((100*xx/yy))

  # Extract Signal Level using awk
  signal_level=$(echo "$iwconfig_output" | awk -F'Signal level=' '/Signal level/{print $2}' | awk '{print $1}')

  # signal level color
  if [ $RSSI_GREEN_MIN -lt $signal_level ] && [ $signal_level -le $RSSI_GREEN_MAX ] ; then 
    print_color=$Green
  elif [ $RSSI_YELLOW_MIN -lt $signal_level ] && [ $signal_level -le $RSSI_YELLOW_MAX ] ; then
    print_color=$Yellow
  elif [ $RSSI_RED_MIN -lt $signal_level ] && [ $signal_level -le $RSSI_RED_MAX ] ; then
    print_color=$Red
  elif [ $RSSI_CYAN_MIN -lt $signal_level ] && [ $signal_level -le $RSSI_CYAN_MAX ] ; then
    print_color=$Cyan
  else
    print_color=$Color_Off
  fi

  # save to file
  echo "$current_time, $xx, $yy, $signal_level" >> $filename

  # log info
  printf "%-38s" "$current_time, LQI=$xx/$yy($link_quality_percent%), "
  printf "%-13s" "[rssi=$signal_level]  "
  echo -ne "[-100dBm "
  # draw rssi
  for ((ii=RSSI_MIN; ii <= $RSSI_MAX; ii += 2)); do
    if [ "$signal_level" -ge "$ii" ]; then
      echo -ne "$print_color|$Color_Off"
    else
      echo -ne "-"
    fi
  done
  echo -ne " 0dBm] "
}

# Main
main_loop() {
  read_interval
  read_measurement_time
  read_filename
  read_times=$((measurement_time/interval))
  echo "Read in $measurement_time seconds with interval $interval seconds: $read_times times"
  echo "date, LQI, LQI MAX, rssi (dBm)" >> $filename
  echo "Realtime data:"
  local i=1
  for ((; i <= read_times; i += 1)); do
    get_wifi_stats
    echo -ne " [i=$i/$read_times]"
    echo ""
    sleep $interval
  done
}

# check os
check_os
# echo "machine: $machine_os"

# check package
check_packages

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
  iwconfig $interface
  main_loop
else
  echo "Choose interface:"
  select interface in $wireless_interfaces; do
    if [[ ! -z "$interface" ]]; then
      echo "Wi-Fi connected on interface: $interface"
      iwconfig $interface
      main_loop
      break
    else
      echo "Invalid selection. Please choose a valid interface."
    fi
  done
fi

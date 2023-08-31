#!/bin/bash

# Wi-Fi interface name
interface_name="wlp3s0"

# Get Link Quality and Signal Level using iwconfig
iwconfig_output=$(iwconfig "$interface_name")

# Extract Link Quality and Signal Level using awk
link_quality=$(echo "$iwconfig_output" | awk '/Link Quality/{print $2}')
signal_level=$(echo "$iwconfig_output" | awk '/Signal level/{print $4}')

# Print the results
echo "Link Quality: $link_quality"
echo "Signal Level: $signal_level"
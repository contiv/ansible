#!/bin/bash
set -e
IFS="
"
rules_file="/etc/contiv/rules.conf"
if [ -f "$rules_file" ]; then
    while read line; do
        eval iptables -w 10 $line
    done < $rules_file
else 
    mkdir -p "/etc/contiv"
    touch $rules_file 
    iptables -S | sed '/contiv/!d;s/^-A/-I/' > $rules_file
fi

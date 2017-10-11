#!/bin/bash
set -e
IFS="
"
rules_file="/etc/contiv/rules.conf"
if [ -f "$rules_file" ]
then
    while read line; do
        eval iptables $line
    done < $rules_file
else 
    mkdir -p "/etc/contiv"
    touch $rules_file 
    iptables -S | grep "contiv" > $rules_file
fi

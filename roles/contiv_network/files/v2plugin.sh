#!/bin/bash

# Keep trying forever to "docker plugin enable" the contiv plugin

set -euxo pipefail
while [ true ]
do
        ID="$(docker plugin ls  | awk '/contiv/ {print $2}')"
        STATUS="$(docker plugin ls  | awk '{print $8}')"
        if [ $STATUS != true ]; then
                docker plugin enable $ID || sleep 1
        else
                break
        fi
done

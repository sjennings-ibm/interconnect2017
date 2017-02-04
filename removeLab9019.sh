#!/bin/bash
printf "IBMid:"
read userid
ns=`cf ic namespace get`
suffix=`echo -e $userid | tr -d '@_.-' | tr -d '[:space:]'` 

cf delete bluecompute-web-app-$suffix   -f

cf delete-service apic-refarch-$suffix        -f

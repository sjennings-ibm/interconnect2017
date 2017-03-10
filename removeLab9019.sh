#!/bin/bash
printf "IBMid:"
read userid
ns=`cf ic namespace get`
suffix=`echo -e $userid | tr -d '@_.-' | tr -d '[:space:]'` 

cf delete bluecompute-web-app-$suffix -f

apisrvnametmp=`cf services | grep "APIConnect" | awk -F 'APIConnect' '{print $1}'`
apisrvname=`echo $apisrvnametmp | sed 's/[ \t]*$//'`
cf delete-service "$apisrvname" -f

rm -rf /home/bmxuser/refarch-cloudnative-api
rm -rf /home/bmxuser/refarch-cloudnative-bff-socialreview
rm -rf /home/bmxuser/refarch-cloudnative-bluecompute-web

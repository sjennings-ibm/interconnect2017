#!/bin/bash
printf "IBMid:"
read userid
ns=`cf ic namespace get`
suffix=`echo -e $userid | tr -d '@_.-' | tr -d '[:space:]'`

# sgname=`cf services | grep SecureGateway | sed -e 's/\s\s.*$//'`
# cf delete-service $sgname -f

# wlpname=`cf apps | grep wlp-server | awk '{print $1;}'`
# cf delete $wlpname -f

apisrvnametmp=`cf services | grep "APIConnect" | awk -F 'APIConnect' '{print $1}'`
apisrvname=`echo $apisrvnametmp | sed 's/[ \t]*$//'`
cf delete-service "$apisrvname" -f

cf ic rm -f integration-$suffix

imgname=`cf ic images | grep todoic | awk '{print $1;}'`
cf ic rmi $imgname 

publicip=`cf ic ip list | grep -Eo "([0-9]{1,3}[\.]){3}[0-9]{1,3}"`
cf ic ip release $publicip

rm ToDoWebServicesService.wsdl

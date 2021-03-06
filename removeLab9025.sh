#!/bin/bash
printf "IBMid:"
read userid
ns=`cf ic namespace get`
suffix=`echo -e $userid | tr -d '@_.-' | tr -d '[:space:]'`

# sgname=`cf services | grep SecureGateway | sed -e 's/\s\s.*$//'`
# cf delete-service $sgname -f

# wlpname=`cf apps | grep wlp-server | awk '{print $1;}'`
# cf delete $wlpname -f

cf delete-service-key dataconnect-integration dc-credential -f
cf delete-service dataconnect-integration -f

cf delete-service-key cloudantToDo toDoCredential -f
cf delete-service cloudantToDo -f

cf ic stop integration-$suffix
sleep 5
cf ic rm -f integration-$suffix

sleep 10
imgname=`cf ic images | grep todoic | awk '{print $1;}'`
cf ic rmi $imgname 

publicip=`cf ic ip list | grep -Eo "([0-9]{1,3}[\.]){3}[0-9]{1,3}"`
cf ic ip release $publicip

sleep 20
echo "#############################################################################"
echo "#                 Remaining containers                                      #"
echo "#############################################################################"
echo ""
echo `cf ic ps -a`

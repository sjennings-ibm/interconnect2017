#!/bin/bash
printf "IBMid:"
read userid
ns=`cf ic namespace get`
suffix=`echo -e $userid | tr -d '@_.-' | tr -d '[:space:]'` 

cf delete inventory-bff-app-$suffix     -f

apisrvnametmp=`cf services | grep "APIConnect" | awk -F 'APIConnect' '{print $1}'`
apisrvname=`echo $apisrvnametmp | sed 's/[ \t]*$//'`
cf delete-service "$apisrvname" -f

cf delete-service cloudnative-autoscale-$suffix  -f

cf ic group rm micro-inventory-group-$suffix   
cf ic group rm zuul_cluster                         
cf ic group rm eureka_cluster                      

cf ic rm -f mysql-$suffix

sleep 10
cf ic rmi registry.ng.bluemix.net/$ns/inventoryservice-$suffix
cf ic rmi registry.ng.bluemix.net/$ns/eureka-$suffix                
cf ic rmi registry.ng.bluemix.net/$ns/zuul-$suffix                  
cf ic rmi registry.ng.bluemix.net/$ns/mysql-$suffix                 

rm -rf /home/bmxuser/refarch-cloudnative*

sleep 20
echo "#############################################################################"
echo "#                 Remaining containers                                      #"
echo "#############################################################################"
echo ""
echo `cf ic ps -a`

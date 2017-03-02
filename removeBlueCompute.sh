#!/bin/bash
printf "IBMid:"
read userid
ns=`cf ic namespace get`
suffix=`echo -e $userid | tr -d '@_.-' | tr -d '[:space:]'` 

cf delete bluecompute-web-app-$suffix   -f
cf delete inventory-bff-app-$suffix     -f
cf delete socialreview-bff-app-$suffix  -f

cf delete-service apic-refarch-$suffix        -f
cf delete-service cloudnative-autoscale-$suffix  -f
cf delete-service-key socialreviewdb-$suffix cred -f
cf delete-service socialreviewdb-$suffix       -f

cf ic group rm micro-socialreview-group-$suffix
cf ic group rm micro-inventory-group-$suffix   
cf ic group rm zuul_cluster                         
cf ic group rm eureka_cluster                      

cf ic rm -f mysql-$suffix

cf ic rmi registry.ng.bluemix.net/$ns/inventoryservice-$suffix
cf ic rmi registry.ng.bluemix.net/$ns/eureka-$suffix                
cf ic rmi registry.ng.bluemix.net/$ns/zuul-$suffix                  
cf ic rmi registry.ng.bluemix.net/$ns/mysql-$suffix                 
cf ic rmi registry.ng.bluemix.net/$ns/socialreviewservice-$suffix   

rm -rf /home/bmxuser/refarch-cloudnative*

#!/bin/bash

sgname=`cf services | grep SecureGateway | sed -e 's/\s\s.*$//'`
cf delete-service $sgname -f

wlpname=`cf apps | grep wlp-server | awk '{print $1;}'`
cf delete $wlpname -f

cf ic stop integration
sleep 5
cf ic rm integration
sleep 5
imgname=`cf ic images | grep todoic | awk '{print $1;}'`
cf ic rmi $imgname 

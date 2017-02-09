#!/bin/bash
# get login information
printf "Region: 1. US-South 2. Europe \n AP does not support Container\n"
read choice
printf "IBMid:"
read userid
printf "Password:" 
stty -echo
read password
stty echo

domreg=""
if [ $choice -eq 1 ]; then 
  region="ng"
  apicreg="us"
else 
  if [ $choice -eq 2 ]; then 
    region="eu-gb"
    apicreg="eu"
    domreg="eu-gb."
  else 
    region="ng"
    apicreg="us"
  fi
fi
dom="mybluemix.net"

IFS="@"
set -- $userid
if [ "${#@}" -ne 2 ];then
    echo "#####################################################"
    echo "Your IBMid is not in the format of an email"
    echo "This lab cannot be performed with this email address"
    echo "Ask a lab proctor for more information"
    echo "#####################################################"
    exit
fi
echo
echo "#######################################################################"
echo "# 1. Logging in to Bluemix "
# Run cf login
cf login -a api.$region.bluemix.net -u "$userid" -p "$password" | tee login.out
logerr=`grep FAILED login.out | wc -l`
rm login.out
if [ $logerr -eq 1 ]; then
  echo "#    Login failed... Exiting"
  exit
fi
orgtxt=`cf target | grep "Org:" | awk '{print $2}'`
spctxt=`cf target | grep "Space:" | awk '{print $2}'`

echo "#    Logged in to Bluemix ...  "
echo "#######################################################################"


echo "#######################################################################"
echo "# 2. Clone repositories"
cd /home/bmxuser
git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-bff-socialreview
git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-api
git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-bluecompute-web


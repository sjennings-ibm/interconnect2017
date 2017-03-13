#!/bin/bash
# get login information
# printf "Region: 1. US-South 2. Europe \n AP does not support Container\n"
# read choice
choice=1
printf "IBMid:"
read userid
echo "User id is $userid"
printf "Password:" 
stty -echo
read password
echo "Password is $password"
stty echo

if [ $choice -eq 1 ]; then 
  region="ng"
else 
  if [ $choice -eq 2 ]; then 
    region="eu-gb"
  fi
fi
echo "Region is $region"

IFS="@"
set -- $userid
echo "Number is ${#@}"
if [ "${#@}" -ne 2 ];then
    echo "#####################################################"
    echo "Your IBMid is not in the format of an email"
    echo "This lab cannot be performed with this email address"
    echo "Ask a lab proctor for more information"
    echo "#####################################################"
    exit
fi
unset IFS
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

# get space and org info
orgtxt=`cf target | grep "Org:" | awk '{print $2}'`
spctxt=`cf target | grep "Space:" | awk '{print $2}'`
echo "#    Logged in to Bluemix ...  org=$orgtxt, space=$spctxt"
echo "#######################################################################"

# Run cf ic init
echo "#######################################################################"
echo "# 2. Initialize IBM Container Plugin "
initResult=`cf ic init`
err=`echo initResult | grep IC5076E | wc -l`
if [ $err -eq 1 ]; then
  echo "IBM Container namespace"
  echo "This namespace cannot be changed later"
  echo "Enter your namespace"
  read namespace
  cf ic namespace set $namespace > /dev/null
  cf ic init > /dev/null
fi
echo "#    IBM Container initialized ... "
echo "#######################################################################"

# deploy container
echo "#######################################################################"
echo "# 3. Setup a container acting as on-premises resource "
suffix=`echo -e $userid | tr -d '@_.-' | tr -d '[:space:]'`
ns=`cf ic namespace get`
cf ic cpi bluemixenablement/todoic17 registry.ng.bluemix.net/$ns/todoic17
cf ic run -m 512  --expose 5432 --expose 9080 --name integration-$suffix registry.ng.bluemix.net/$ns/todoic17
publicip=`cf ic ip request | grep obtained | grep -Eo "([0-9]{1,3}[\.]){3}[0-9]{1,3}"`
cf ic ip bind $publicip integration-$suffix
echo "#    Public IP for container is: $publicip"
echo "#    On-premises container initialized "
echo "#######################################################################"

# setup postgresql JDBC
echo "#######################################################################"
echo "# 4. Setting up Eclipse environment "
cd /home/bmxuser
git clone https://github.com/vbudi000/bluemix-integration-lab
unzip bluemix-integration-lab/wlp-server.zip
cd /home/bmxuser
eclipse/eclipse -data ./workspace > /dev/null 2>1 &
echo "#    Preparation done - your public IP is: $publicip"
echo "#######################################################################"

#!/bin/sh
# get login information
printf "Region: 1. US-South 2. Europe \n AP does not support Container\n"
read choice
printf "IBMid:"
read userid
printf "Password:" 
stty -echo
read password
stty echo

if [ $choice -eq 1 ]; then 
  region="ng"
else 
  if [ $choice -eq 2 ]; then 
    region="eu-gb"
  fi
fi
echo
echo "#######################################################################"
echo "# 1. Logging in to Bluemix "
# Run cf login
cf login -a api.$region.bluemix.net -u "$userid" -p "$password" -o "$userid" -s dev | tee login.out
logerr=`grep FAILED login.out | wc -l`
rm login.out
if [ $logerr -eq 1 ]; then
  echo "#    VBD00111E Login failed... Try again"
  exit
fi
echo "#    Logged in to Bluemix ... "
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
ns=`cf ic namespace get`
cf ic cpi bluemixenablement/todoic registry.ng.bluemix.net/$ns/todoic
cf ic run -m 512 --expose 5432 --name integration registry.ng.bluemix.net/$ns/todoic
publicip=`cf ic ip request | grep obtained | grep -Po '(?<=\").*(?=\")'`
cf ic ip bind $publicip integration
echo "#    Public IP for container is: $publicip"
echo "#    On-premises container initialized "
echo "#######################################################################"

# setup postgresql JDBC
echo "#######################################################################"
echo "# 4. Setting up Eclipse environment "
cd /home/bmxuser
git clone https://github.com/vbudi000/bluemix-integration-lab
wget -O wlp-javaee7-8.5.5.6.zip https://repo1.maven.org/maven2/com/ibm/websphere/appserver/runtime/wlp-javaee7/8.5.5.6/wlp-javaee7-8.5.5.6.zip
wget https://jdbc.postgresql.org/download/postgresql-9.4.1212.jar
unzip wlp-javaee7-8.5.5.6.zip
unzip bluemix-integration-lab/wlp-server.zip
mv postgresql-9.4.1212.jar /home/bmxuser/wlp/usr/shared/resources/
cd /home/bmxuser
eclipse/eclipse -data ./workspace > /dev/null 2>1 &
echo "#    Preparation done - your public IP is: $publicip"
echo "#######################################################################"

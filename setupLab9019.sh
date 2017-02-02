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
starttime=`date`

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
dom="$domreg$dom"

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
cf login -a api.$region.bluemix.net -u "$userid" -p "$password" -o "$userid" -s dev | tee login.out
logerr=`grep FAILED login.out | wc -l`
rm login.out
if [ $logerr -eq 1 ]; then
  echo "#    Login failed... Exiting"
  exit
fi
# get space and org info
orgid=`cf ic info | grep Org |  grep -Po '(?<=\().*(?=\))'`
spaceid=`cf ic info | grep Space | grep -Po '(?<=\().*(?=\))'`
echo "#    Logged in to Bluemix ...  org=$orgid, space=$spaceid"
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
ns=`cf ic namespace get`
suffix=`echo -e $userid | tr -d '@_.-' | tr -d '[:space:]'` 
echo "#    IBM Container initialized ... "
echo "#######################################################################"

# deploy social review - eureka - zuul - bff - apic 
echo "################################################################r#######"
echo "# 3a. Setup mysql container  "
cf ic cpi vbudi/refarch-mysql registry.$region.bluemix.net/$ns/mysql-$suffix
cf ic run -m 256 --name mysql-$suffix -p 3306:3306 -e MYSQL_ROOT_PASSWORD=Pass4Admin123 -e MYSQL_USER=dbuser -e MYSQL_PASSWORD=Pass4dbUs3R -e MYSQL_DATABASE=inventorydb registry.$region.bluemix.net/$ns/mysql-$suffix
echo "Waiting for mysql container to start ..."  
sqlok=`cf ic ps | grep mysql | grep unning | wc -l`
until [  $sqlok -ne 0 ]; do
    sleep 10         
    sqlok=`cf ic ps | grep mysql | grep unning | wc -l`
    sqlerr=`cf ic ps | grep mysql | wc -l`
    if [ $sqlerr -eq 0 ]; then 
        echo "Cannot run the MySQL container. Exiting ..."
        exit
    fi
done

echo "cf ic exec -it mysql-$suffix sh load-data.sh"
"cf ic exec -it mysql-$suffix sh load-data.sh"

mysqlIP=`cf ic inspect mysql-$suffix | grep -i ipaddr | head -n 1 | grep -Po '(?<="IPAddress": ")[^"]*' `

echo "# 3b. Create Cloudant database "
cf create-service cloudantNoSQLDB Lite socialreviewdb-$suffix
cf create-service-key socialreviewdb-$suffix cred
cloudantCred=`cf service-key socialreviewdb-$suffix cred`
cldurl=`echo -e $cloudantCred | grep url |  grep -Po '(?<=\"url\": \")[^"]*'`
cldhost=`echo -e $cloudantCred | grep host |  grep -Po '(?<=\"host\": \")[^"]*'`
cldusername=`echo -e $cloudantCred | grep username |  grep -Po '(?<=\"username\": \")[^"]*'`
cldpassword=`echo -e $cloudantCred | grep password |  grep -Po '(?<=\"password\": \")[^"]*'`

if [ $cldurl -eq "" ]; then
    echo "Cannot instantiate cloudant. Exiting ..."
    exit
else
    echo "Cloudant url: $cldurl"
fi
# get cred
echo "curl -X PUT https://$cldusername:$cldpassword@$cldhost/socialreviewdb"
"curl -X PUT https://$cldusername:$cldpassword@$cldhost/socialreviewdb"

echo "# 3c. Create eureka and zuul"
cf ic cpi vbudi/refarch-eureka  registry.$region.bluemix.net/$ns/eureka-$suffix
cf ic cpi vbudi/refarch-zuul  registry.$region.bluemix.net/$ns/zuul-$suffix
cf ic group create --name eureka_cluster --publish 8761 --memory 256 --auto --min 1 --max 3 --desired 1 -n netflix-eureka-$suffix -d $domreg$dom -e eureka.client.fetchRegistry=true -e eureka.client.registerWithEureka=true -e eureka.client.serviceUrl.defaultZone=http://netflix-eureka-$suffix.$domreg$dom/eureka/ -e eureka.instance.hostname=eureka-$suffix.$domreg$dom -e eureka.instance.nonSecurePort=80 -e eureka.port=80 registry.$region.bluemix.net/$ns/eureka-$suffix
cf ic group create --name zuul_cluster --publish 8080 --memory 256 --auto --min 1 --max 3 --desired 1 -n netflix-zuul-$suffix -d $domreg$dom -e eureka.client.serviceUrl.defaultZone="http://netflix-eureka-$suffix.$domreg$dom/eureka" -e eureka.instance.hostname=netflix-zuul-$suffix.$domreg$dom -e eureka.instance.nonSecurePort=80 -e eureka.instance.preferIpAddress=false -e spring.cloud.client.hostname=zuul-$suffix.$domreg$dom registry.$region.bluemix.net/$ns/zuul-$suffix

echo "Waiting for OSS to start ..."    
ossdone=`cf ic group list | grep "_cluster" | grep "CREATE_COMPLETE" | wc -l`
until [  $ossdone -eq 2 ]; do
    sleep 10         
    ossdone=`cf ic group list | grep "_cluster" | grep "CREATE_COMPLETE" | wc -l`
done
  
echo "# 3c. Create inventory microservices"
cf ic cpi vbudi/refarch-inventory registry.$region.bluemix.net/$ns/inventoryservice-$suffix
cf ic group create -p 8080 -m 256 --min 1 --desired 1 --auto --name micro-inventory-group-$suffix -e "spring.datasource.url=jdbc:mysql://$mysqlIP:3306/inventorydb" -n inventoryservice-$suffix -d $domreg$dom  -e "eureka.client.serviceUrl.defaultZone=http://netflix-eureka-$suffix.$domreg$dom/eureka/"  -e "spring.datasource.username=dbuser" -e "spring.datasource.password=Pass4dbUs3R" registry.$region.bluemix.net/$ns/inventoryservice-$suffix

echo "# 3d. Create socialreview microservices"
cf ic cpi vbudi/refarch-socialreview registry.$region.bluemix.net/$ns/socialreviewservice-$suffix
cf ic group create -p 8080 -m 256 --min 1 --desired 1 --auto --name micro-socialreview-group-$suffix -e "eureka.client.serviceUrl.defaultZone=http://netflix-eureka-$suffix.$domreg$dom/eureka/" -e "cloudant.username=$cldusername" -e "cloudant.password=$cldpassword" -e "cloudant.host=https://$cldhost" -n socialreviewservice-$suffix -d $domreg$dom  registry.$region.bluemix.net/$ns/socialreviewservice-$suffix 

echo "Waiting for microservices to start ..."  
msdone=`cf ic group list | grep "micro-" | grep "CREATE_COMPLETE" | wc -l`
until [  $msdone -eq 2 ]; do
    sleep 10         
    msdone=`cf ic group list | grep "micro-" | grep "CREATE_COMPLETE" | wc -l`
done  

echo "# 3e Clone repositories"
cd /home/bmxuser
git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-bff-inventory
git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-bff-socialreview
git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-api
git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-bluecompute-web

endtime=`date`
echo $starttime $endtime
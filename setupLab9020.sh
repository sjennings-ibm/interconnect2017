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

if [ $choice -eq 1 ]; then 
  region="ng"
else 
  if [ $choice -eq 2 ]; then 
    region="eu-gb"
  fi
fi

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
suffix=`echo -e $userid | tr -d '@_.-'` 
echo "#    IBM Container initialized ... "
echo "#######################################################################"

# deploy social review - eureka - zuul - bff - apic 
echo "################################################################r#######"
echo "# 3a. Setup mysql container  "
cf ic cpi vbudi/refarch-mysql registry.$region.bluemix.net/$ns/mysql-$suffix
cf ic run -m 256 --name mysql -p 3306:3306 -e MYSQL_ROOT_PASSWORD=Pass4Admin123 -e MYSQL_USER=dbuser -e MYSQL_PASSWORD=Pass4dbUs3R -e MYSQL_DATABASE=inventorydb registry.$region.bluemix.net/$ns/mysql-$suffix
sleep 10
cf ic exec -it mysql-$suffix sh load-data.sh 
cf ic inspect mysql-$suffix | grep -i ipaddr 

echo "# 3b. Create Cloudant database "
cf create-service cloudantNoSQLDB Lite socialreviewdb-$suffix
cf create-service-key socialreviewdb-$suffix cred
cloudant-cred=`cf service-key socialreviewdb-$suffix cred`
cldurl=`echo -e cloudant-cred | grep url | grep -Po '(?<=\:\").*(?=\")'`
cldhost=`echo -e cloudant-cred | grep host | grep -Po '(?<=\:\").*(?=\")'`
cldusername=`echo -e cloudant-cred | grep username | grep -Po '(?<=\:\").*(?=\")'`
cldpassword=`echo -e cloudant-cred | grep password | grep -Po '(?<=\:\").*(?=\")'`

# get cred
curl -X PUT $cldurl/socialreviewdb

echo "# 3c. Create eureka and zuul"
cf ic cpi vbudi/refarch-eureka  registry.$region.bluemix.net/$ns/eureka-$suffix
cf ic cpi vbudi/refarch-zuul  registry.$region.bluemix.net/$ns/zuul-$suffix
cf ic group create --name eureka_cluster --publish 8761 --memory 256 --auto \
  --min 1 --max 3 --desired 1 \
  --hostname netflix-eureka-$suffix \
  --domain $region.mybluemix.net \
  --env eureka.client.fetchRegistry=true \
  --env eureka.client.registerWithEureka=true \
  --env eureka.client.serviceUrl.defaultZone=http://eureka-$suffix.mybluemix.net/eureka/ \
  --env eureka.instance.hostname=eureka-$suffix.mybluemix.net \
  --env eureka.instance.nonSecurePort=80 \
  --env eureka.port=80 \
   registry.$region.bluemix.net/$ns/eureka-$suffix
cf ic group create --name zuul_cluster \
  --publish 8080 --memory 256 --auto --min 1 --max 3 --desired 1 \
  --hostname netflix-zuul-$suffix \
  --domain $region.mybluemix.net \
  --env eureka.client.serviceUrl.defaultZone="http://eureka-$suffix.mybluemix.net/eureka" \
  --env eureka.instance.hostname=netflix-zuul-$suffix.mybluemix.net \
  --env eureka.instance.nonSecurePort=80 \
  --env eureka.instance.preferIpAddress=false \
  --env spring.cloud.client.hostname=zuul-$suffix.mybluemix.net \
  registry.$region.bluemix.net/$ns/zuul-$suffix
  
  
echo "# 3c. Create inventory microservices"
cf ic cpi vbudi/refarch-inventory registry.$region.bluemix.net/$ns/inventoryservice-$suffix
cf ic group create -p 8080 -m 256 --min 1 --desired 1 \
 --auto --name micro-inventory-group-$suffix \
 -e "spring.datasource.url=jdbc:mysql://${ipaddr}:3306/inventorydb" \
 -e "eureka.client.serviceUrl.defaultZone=http://eureka-$suffix.mybluemix.net/eureka/" \
 -e "spring.datasource.username=dbuser" \
 -e "spring.datasource.password=Pass4dbUs3R" \
 -n inventoryservice-$suffix -d mybluemix.net \
 registry.$region.bluemix.net/$ns/inventoryservice-$suffix

echo "# 3d. Create socialreview microservices"
cf ic cpi vbudi/refarch-socialreview registry.$region.bluemix.net/$ns/socialservice-$suffix
cf ic group create -p 8080 -m 256 \
  --min 1 --desired 1 --auto \
  --name micro-socialreview-group \
  -n socialreviewservice-$suffix \
  -d mybluemix.net \
  -e "eureka.client.serviceUrl.defaultZone=http://eureka-$suffix.mybluemix.net/eureka/" \
  -e "cloudant.username=$cldusername" \
  -e "cloudant.password=$cldpassword " \
  -e "cloudant.host=https://$cldhost" \ 
  registry.$region.bluemix.net/$ns/socialreviewservice-$suffix 
  
  
echo "# 3e deploy BFFs"
cd /home/bmxuser
git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-bff-inventory
git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-bff-socialreview
git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-api
git clone https://github.com/ibm-cloud-architecture/refarch-cloudnative-bluecompute-web

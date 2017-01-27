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
echo
# Run cf login
cf login -a api.$region.bluemix.net -u $userid -p $password | tee login.out
logerr=`grep FAILED login.out | wc -l`
if [ $logerr -eq 1 ]; then
  echo "VBD00111E Login failed... Try again"
  rm login.out
  exit
fi

# Run cf ic init
initResult=`cf ic init`
err=`echo initResult | grep IC5076E | wc -l`
if [ $err -ne 1 ]; then
  echo "IBM Container namespace"
  echo "This namespace cannot be changed later"
  echo "Enter your namespace"
  read namespace
  cf ic namespace set $namespace
  cf ic init > /dev/null
fi

# deploy container
cf ic cpi bluemixenablement/todoic registry.ng.bluemix.net/${cf ic namespace get}/todoic
cf ic run -m 512 --name integration registry.ng.bluemix.net/$(cf ic namespace get)/todoic
publicip=`cf ic ip request | grep obtained | grep -Po '(?<=\").*(?=\")'`
cf ic ip bind $publicip integration
 
# get space and org info
orgid=`cf ic info | grep Org |  grep -Po '(?<=\().*(?=\))'`
spaceid=`cf ic info | grep Space | grep -Po '(?<=\().*(?=\))'`

# Create secure gateway service
cf create-service SecureGateway securegatewayplan sginstance

# Create Integration Gateway
authstr=`echo $userid:$password | base64`
gwjson=`curl -k -X POST -H "Authorization: Basic $authstr" -H "Content-Type: application/json" -d "{\"desc\":\"IntegrationGateway\", \"enf_tok_sec\":false, \"token_exp\":0}" https://sgmanager.ng.bluemix.net/v1/sgconfig?org_id=$orgid&space_id=$spaceid`
jwt=`echo $gwjson | sed -e 's/[{}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | grep jwt | grep -Po '(?<=\:\").*(?=\")'`
gwID=`echo $gwjson | sed -e 's/[{}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | grep \"_id | grep -Po '(?<=\:\").*(?=\")'`

# Create destination
destjson=`curl -k -X POST -H "Authorization: Bearer $jwt" -H "Content-Type: application/json" -d "{\"desc\":\"REST\", \"ip\":\"$publicip\", \"port\":9080}" https://sgmanager.ng.bluemix.net/v1/sgconfig/$gwID/destinations`
destHost=`echo $destjson | sed -e 's/[{}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | grep hostname | grep -Po '(?<=\:\").*(?=\")'`
destPort=`echo $destjson | sed -e 's/[{}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | grep \"port\" | grep -Po '(?<=\:).*$'`
# Connect to container
cf ic cp runsgclient.sh integration:/root/runsgclient.sh
cf ic cp acl.list integration:/root/acl.list
cf ic exec integration /root/runsgclient.sh $gwID

# work with eclipse
cd /home/bmxuser
git clone https://github.com/vbudi000/integration-lab-ic2017
eclipse/eclipse -data ./integration-lab-ic2017



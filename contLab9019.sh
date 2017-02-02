#!/bin/bash
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
suffix=`echo -e $userid | tr -d '@_.-' | tr -d '[:space:]'` 
dom="mybluemix.net"

echo "#######################################################################"
echo "# 4a Install BFFs"
cd /home/bmxuser/refarch-cloudnative-bff-inventory/inventory
/bin/bash set-zuul-proxy-url.sh -z netflix-zuul-$suffix.$domreg$dom
cf create-service Auto-Scaling free cloudnative-autoscale-$suffix
sed -i -e 's/autoscale/autoscale-'$suffix'/g' manifest.yml
# push
cf push inventory-bff-app-$suffix -d $domreg$dom -n inventory-bff-app-$suffix 

echo "#######################################################################"
echo "# 4b Install Social review BFFs"

cd /home/bmxuser/refarch-cloudnative-bff-socialreview/socialreview
/bin/bash set-zuul-proxy-url.sh -z netflix-zuul-$suffix.$domreg$dom

apic login -s $apicreg.apiconnect.ibmcloud.com -u $userid -p $password
apic config:set app=apic-app://$apicreg.apiconnect.ibmcloud.com/orgs/$suffix-dev/apps/socialreview-bff-app-$suffix
apic apps:publish
cf bs socialreview-bff-app-$suffix cloudnative-autoscale-$suffix
cf restage socialreview-bff-app-$suffix

sochost=`cf apps | grep socialreview-bff | awk '{ print $6;}'`

echo "#######################################################################"
echo "# 5 Update API definitions and publish APIs"

sed -i -e 's/inventory-bff-app.mybluemix.net/inventory-bff-app-'$suffix.$domreg$dom'/g' /home/bmxuser/refarch-cloudnative-api/inventory/inventory.yaml
sed -i -e 's/api.us.apiconnect.ibmcloud.com\/centusibmcom-cloudnative-dev\/bluecompute/api.'$apicreg'.apiconnect.ibmcloud.com\/'$suffix'-dev\/bluecompute-'$suffix'/g' /home/bmxuser/refarch-cloudnative-bff-socialreview/socialreview/definitions/socialreview.yaml
sed -i -e 's/apiconnect-243ab119-1c05-402c-a74c-6125122c9273.centusibmcom-cloudnative-dev.apic.mybluemix.net/'$sochost'/g' /home/bmxuser/refarch-cloudnative-bff-socialreview/socialreview/definitions/socialreview.yaml

apic config:set catalog=apic-catalog://$apicreg.apiconnect.ibmcloud.com/orgs/$suffix-dev/catalogs/bluecompute-$suffix

cd /home/bmxuser/refarch-cloudnative-api/inventory/
apic publish inventory-product_0.0.1.yaml

cd /home/bmxuser/refarch-cloudnative-bff-socialreview/socialreview/definitions/
apic publish socialreview-product.yaml

echo "#######################################################################"
echo "# 6 prepare Web application"

cd /home/bmxuser/refarch-cloudnative-bluecompute-web/StoreWebApp
sed -i -e 's/mybluemix.net/'$domreg$dom'/g' manifest.yml
sed -i -e 's/bluecompute-web-app/bluecompute-web-app-'$suffix'/g' manifest.yml

sed -i -e 's/api.us.apiconnect.ibmcloud.com/api.'$apicreg'.apiconnect.ibmcloud.com/g' config/default.json
sed -i -e 's/centusibmcom-cloudnative/'$suffix'/g' config/default.json
sed -i -e 's/bluecompute/bluecompute-'$suffix'/g' config/default.json
sed -i -e 's/3f1b4cc8-78dc-450e-9461-edf377105c7a/'$clientid'/g' config/default.json

cf push 

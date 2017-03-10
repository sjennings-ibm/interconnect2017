#!/bin/bash
cd /opt/ibm/securegateway/client
node lib/secgwclient.js --F /root/acl.list $1&

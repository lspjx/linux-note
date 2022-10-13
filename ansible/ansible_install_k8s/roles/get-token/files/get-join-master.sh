#!/bin/bash

token=`cat /tmp/token/join-token.sh`
key=`tail -1 /tmp/token/certificate-key`

echo "$token --control-plane --certificate-key $key"  > /tmp/token/master-join-token.sh

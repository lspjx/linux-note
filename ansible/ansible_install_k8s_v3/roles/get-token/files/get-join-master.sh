#!/bin/bash

if test -f /tmp/token/join-token.sh;then
    token=`cat /tmp/token/join-token.sh`
else
    exit 1
fi

if test -f /tmp/token/certificate-key;then
    key=`tail -1 /tmp/token/certificate-key`
else
    exit 1
fi

echo "$token --control-plane --certificate-key $key"  > /tmp/token/master-join-token.sh

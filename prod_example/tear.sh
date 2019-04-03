#!/bin/bash

helm delete --purge ca kafka-hlf example1 example2 mainorg-couchdb1 peer1

kubectl delete pvc -n cas data-ca-postgresql-0

kubectl delete pvc -n mainorg-dev data-kafka-hlf-zookeeper-0 data-kafka-hlf-zookeeper-1 data-kafka-hlf-zookeeper-2 datadir-kafka-hlf-0 datadir-kafka-hlf-1 datadir-kafka-hlf-2 datadir-kafka-hlf-3 

kubectl delete secret -n mainorg-dev hlf--ord-admincert hlf--ord-adminkey hlf--ord-ca-cert hlf--genesis hlf--ord1-idcert hlf--ord2-idcert hlf--ord1-idkey hlf--ord2-idkey

kubectl delete secret -n mainorg-peer hlf--peer-admincert  hlf--peer-adminkey hlf--peer-ca-cert hlf--channel hlf--peer1-idcert hlf--peer1-idkey

rm -rf ./config/*MSP ./config/genesis.block ./config/example-channel.tx
kubectl delete ns cas mainorg-dev mainorg-peer

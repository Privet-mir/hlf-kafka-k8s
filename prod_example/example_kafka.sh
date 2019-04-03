#!/bin/bash

echo -e "\e[34m Complete Deployment takes 15-20 min\e[0m"

echo -e "\e[34m Creating Namespaces\e[0m"
kubectl create ns cas
kubectl create ns mainorg-dev
kubectl create ns mainorg-peer

echo -e "\e[34m Install CA\e[0m"
helm install stable/hlf-ca -n ca --namespace cas -f ./helm_values/ca.yaml
echo -e "\e[34m Please be Patient CA is getting installed it migth take upto 1-2 min\e[0m"
sleep 80
CA_POD=$(kubectl get pods -n cas -l "app=hlf-ca,release=ca" -o jsonpath="{.items[0].metadata.name}")
kubectl logs -n cas $CA_POD | grep "Listening on"

echo -e "\e[34m Enroll admin for CA \e[0m"
kubectl exec -n cas $CA_POD -- bash -c 'fabric-ca-client enroll -d -u http://$CA_ADMIN:$CA_PASSWORD@$SERVICE_DNS:7054'

CA_INGRESS=$(kubectl get ingress -n cas -l "app=hlf-ca,release=ca" -o jsonpath="{.items[0].spec.rules[0].host}")

echo -e "\e[34m Curl CAINFO\e[0m"
curl https://$CA_INGRESS/cainfo

#exit 1
echo -e "\e[34m Register admin identiy for orderer on CA\e[0m"
kubectl exec -n cas $CA_POD -- fabric-ca-client register --id.name ord-admin --id.secret OrdAdm1nPW --id.attrs 'admin=true:ecert'

echo -e "\e[34m Register peer identiy on CA\e[0m"
kubectl exec -n cas $CA_POD -- fabric-ca-client register --id.name peer-admin --id.secret PeerAdm1nPW --id.attrs 'admin=true:ecert'

echo -e "\e[34m Enroll admin identiy orderer on CA\e[0m"
FABRIC_CA_CLIENT_HOME=./config fabric-ca-client enroll -u https://ord-admin:OrdAdm1nPW@$CA_INGRESS -M ./OrdererMSP
mkdir -p ./config/OrdererMSP/admincerts
cp ./config/OrdererMSP/signcerts/* ./config/OrdererMSP/admincerts

echo -e "\e[34m Enroll peer organization admin identiy on CA\e[0m"
FABRIC_CA_CLIENT_HOME=./config fabric-ca-client enroll -u https://peer-admin:PeerAdm1nPW@$CA_INGRESS -M ./PeerMSP
mkdir -p ./config/PeerMSP/admincerts
cp ./config/PeerMSP/signcerts/* ./config/PeerMSP/admincerts

echo -e "\e[34m Create a secret to hold the admin certificate:Orderer Organisation\e[0m"
ORG_CERT=$(ls ./config/OrdererMSP/admincerts/cert.pem)
kubectl create secret generic -n mainorg-dev hlf--ord-admincert --from-file=cert.pem=$ORG_CERT
echo -e "\e[34m Create a secret to hold the admin key:Orderer Organisation\e[0m"
ORG_KEY=$(ls ./config/OrdererMSP/keystore/*_sk)
kubectl create secret generic -n mainorg-dev hlf--ord-adminkey --from-file=key.pem=$ORG_KEY
echo -e "\e[34m Create a secret to hold the admin key CA certificate:Orderer Organisation\e[0m"
CA_CERT=$(ls ./config/OrdererMSP/cacerts/*.pem)
kubectl create secret generic -n mainorg-dev hlf--ord-ca-cert --from-file=cacert.pem=$CA_CERT

echo -e "\e[34m Create a secret to hold the admincert:Peer Organisation\e[0m"
ORG_CERT=$(ls ./config/PeerMSP/admincerts/cert.pem)
kubectl create secret generic -n mainorg-peer hlf--peer-admincert --from-file=cert.pem=$ORG_CERT
echo -e "\e[34m Create a secret to hold the admin key:Peer Organisation\e[0m"
ORG_KEY=$(ls ./config/PeerMSP/keystore/*_sk)
kubectl create secret generic -n mainorg-peer hlf--peer-adminkey --from-file=key.pem=$ORG_KEY
echo -e "\e[34m Create a secret to hold the CA certificate:Peer Organisation\e[0m"
CA_CERT=$(ls ./config/PeerMSP/cacerts/*.pem)
kubectl create secret generic -n mainorg-peer hlf--peer-ca-cert --from-file=cacert.pem=$CA_CERT

echo -e "\e[34m Create Genesis and channel \e[0m"
cd ./config
configtxgen -profile ComposerOrdererGenesis -outputBlock ./genesis.block
configtxgen -profile exampleChannel -channelID example-channel -outputCreateChannelTx ./example-channel.tx
echo -e "\e[34m Save them as secret \e[0m"
kubectl create secret generic -n mainorg-dev hlf--genesis --from-file=genesis.block
kubectl create secret generic -n mainorg-peer hlf--channel --from-file=example-channel.tx
cd ..

echo -e "\e[34m Install Kafka chart \e[0m"
helm install incubator/kafka -n kafka-hlf --namespace mainorg-dev -f ./helm_values/kafka-hlf.yaml
echo -e "\e[34m Please be patient Kafka chart is getting install it migth take upto 10 min\e[0m"
sleep 500

echo -e "\e[34m Deploy Orderer1 \e[0m"
export NUM=1
kubectl exec -n cas $CA_POD -- fabric-ca-client register --id.name ord${NUM} --id.secret ord${NUM}_pw --id.type orderer

FABRIC_CA_CLIENT_HOME=./config fabric-ca-client enroll -d -u https://ord${NUM}:ord${NUM}_pw@$CA_INGRESS -M ord${NUM}_MSP
echo -e "\e[34m Save the Orderer certificate in a secret\e[0m"
NODE_CERT=$(ls ./config/ord${NUM}_MSP/signcerts/*.pem)
kubectl create secret generic -n mainorg-dev hlf--ord${NUM}-idcert --from-file=cert.pem=${NODE_CERT}
echo -e "\e[34m Save the Orderer private key in another secret \e[0m"
NODE_KEY=$(ls ./config/ord${NUM}_MSP/keystore/*_sk)
kubectl create secret generic -n mainorg-dev hlf--ord${NUM}-idkey --from-file=key.pem=${NODE_KEY}

echo -e "\e[34m Deploy Orderer1 helm chart \e[0m"
helm install -n example${NUM} ../example-ord/ --namespace mainorg-dev -f ./helm_values/ord${NUM}.yaml
sleep 30
ORD_POD=$(kubectl get pods --namespace mainorg-dev -l "app=orderer,release=example1" -o jsonpath="{.items[0].metadata.name}")
kubectl logs -n mainorg-dev $ORD_POD | grep 'Starting orderer'


echo -e "\e[34m Deploy Orderer2 \e[0m"
export NUM=2
kubectl exec -n cas $CA_POD -- fabric-ca-client register --id.name ord${NUM} --id.secret ord${NUM}_pw --id.type orderer

FABRIC_CA_CLIENT_HOME=./config fabric-ca-client enroll -d -u https://ord${NUM}:ord${NUM}_pw@$CA_INGRESS -M ord${NUM}_MSP
echo -e "\e[34m Save the Orderer certificate in a secret\e[0m"
NODE_CERT=$(ls ./config/ord${NUM}_MSP/signcerts/*.pem)
kubectl create secret generic -n mainorg-dev hlf--ord${NUM}-idcert --from-file=cert.pem=${NODE_CERT}
echo -e "\e[34m Save the Orderer private key in another secret \e[0m"
NODE_KEY=$(ls ./config/ord${NUM}_MSP/keystore/*_sk)
kubectl create secret generic -n mainorg-dev hlf--ord${NUM}-idkey --from-file=key.pem=${NODE_KEY}

echo -e "\e[34m Deploy Orderer2 helm chart \e[0m"
helm install -n example${NUM} ../example-ord/ --namespace mainorg-dev -f ./helm_values/ord${NUM}.yaml
sleep 30
ORD_POD=$(kubectl get pods --namespace mainorg-dev -l "app=orderer,release=example2" -o jsonpath="{.items[0].metadata.name}")
kubectl logs -n mainorg-dev $ORD_POD | grep 'Starting orderer'

echo -e "\e[34m Fabric Peer \e[0m"
export NUM=1
echo -e "\e[34m Install CouchDB chart \e[0m"
helm install -n mainorg-couchdb${NUM} ../example-couchdb/ --namespace mainorg-peer -f ./helm_values/cdb-peer${NUM}.yaml
sleep 70
CDB_POD=$(kubectl get pods -n mainorg-peer -l "app=couchdb,release=mainorg-couchdb1" -o jsonpath="{.items[*].metadata.name}")
kubectl logs -n mainorg-peer $CDB_POD | grep 'Apache CouchDB has started on'
#exit 1
echo -e "\e[34m Register peer with CA \e[0m"
kubectl exec -n cas $CA_POD -- fabric-ca-client register --id.name peer${NUM} --id.secret peer${NUM}_pw --id.type peer
FABRIC_CA_CLIENT_HOME=./config fabric-ca-client enroll -d -u https://peer${NUM}:peer${NUM}_pw@$CA_INGRESS -M peer${NUM}_MSP
echo -e "\e[34m Save the Peer certificate in a secret \e[0m"
NODE_CERT=$(ls ./config/peer${NUM}_MSP/signcerts/*.pem)
kubectl create secret generic -n mainorg-peer hlf--peer${NUM}-idcert --from-file=cert.pem=${NODE_CERT}
echo -e "\e[34m Save the Peer private key in another secret \e[0m"
NODE_KEY=$(ls ./config/peer${NUM}_MSP/keystore/*_sk)
kubectl create secret generic -n mainorg-peer hlf--peer${NUM}-idkey --from-file=key.pem=${NODE_KEY}

echo -e "\e[34m Install Fabric Peer Chart \e[0m"
helm install -n peer${NUM} ../example-peer --namespace mainorg-peer -f ./helm_values/peer${NUM}.yaml
sleep 60
PEER_POD=$(kubectl get pods --namespace mainorg-peer -l "app=example,release=peer1" -o jsonpath="{.items[0].metadata.name}")
kubectl logs -n mainorg-peer $PEER_POD | grep 'Starting peer'

echo -e "\e[34m Create Channel \e[0m"
kubectl exec -n mainorg-peer $PEER_POD -- peer channel create -o example1-orderer.mainorg-dev.svc.cluster.local:7050 -c example-channel -f /hl_config/channel/example-channel.tx
kubectl  exec -n mainorg-peer $PEER_POD -- peer channel fetch config /var/hyperledger/example-channel.block -c example-channel -o example1-orderer.mainorg-dev.svc.cluster.local:7050

echo -e "\e[34m Join Channel \e[0m"
kubectl  exec -n mainorg-peer $PEER_POD -- bash -c 'CORE_PEER_MSPCONFIGPATH=$ADMIN_MSP_PATH peer channel join -b /var/hyperledger/example-channel.block'

echo -e "\e[34m Install Sample Chaincode \e[0m"
kubectl exec -n mainorg-peer $PEER_POD -- bash -c 'mkdir example'
kubectl  exec -n mainorg-peer $PEER_POD -- bash -c 'cd example && wget https://raw.githubusercontent.com/hyperledger/fabric-samples/release-1.4/chaincode/chaincode_example02/node/chaincode_example02.js'
kubectl exec -n mainorg-peer $PEER_POD -- bash -c 'cd example && wget https://raw.githubusercontent.com/hyperledger/fabric-samples/release-1.4/chaincode/chaincode_example02/node/package.json'

echo -e "\e[34m Install Chaincode \e[0m"
kubectl exec -n mainorg-peer $PEER_POD -- bash -c 'CORE_PEER_MSPCONFIGPATH=/var/hyperledger/admin_msp/ peer chaincode install -n example -l node -v 1.0.0 -p example'
echo -e "\e[34m Instantiate Chaincode \e[0m"
kubectl exec -n mainorg-peer $PEER_POD -- bash -c "CORE_PEER_MSPCONFIGPATH=/var/hyperledger/admin_msp/ peer chaincode instantiate -o example1-orderer.mainorg-dev.svc.cluster.local:7050 -C example-channel -n example -l node -v 1.0.0 -c '{\"Args\":[\"init\",\"a\",\"100\",\"b\",\"200\"]}'"
sleep 20
echo -e "\e[34m Invoke Chaincode \e[0m"
kubectl exec -n mainorg-peer $PEER_POD -- bash -c "CORE_PEER_MSPCONFIGPATH=/var/hyperledger/admin_msp/ peer chaincode invoke -o example1-orderer.mainorg-dev.svc.cluster.local:7050 -C example-channel -n example  -c '{\"Args\":[\"invoke\",\"a\",\"b\",\"10\"]}'"
sleep 5
echo -e "\e[34m Query Chaincode \e[0m"
kubectl exec -n mainorg-peer $PEER_POD -- bash -c "CORE_PEER_MSPCONFIGPATH=/var/hyperledger/admin_msp/ peer chaincode query -C example-channel -n example  -c '{\"Args\":[\"query\",\"a\"]}'"

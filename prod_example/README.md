To install kafka cluster on kubernetes run
./example_kafka.sh

This script will also install Fabric CLI chart on kubernetes.
It will also download, install, instantiate and query chaincode on peer using Fabric CLI

before running this script make sure you have installed nginx-ingress controller, certmanager and cluster issuers on your kubernetes cluster 

To tear cluster run
./tear.sh

Please modify host in helm_values/ca.yaml

Follow Orignal repo

https://github.com/aidtechnology/hgf-k8s-workshop

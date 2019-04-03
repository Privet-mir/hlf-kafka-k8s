
Make sure you have installed nginx-ingress controller, certmanager and cluster issuers on your kubernetes cluster and your DNS is pointing to ingress external IP 

Please modify host in helm_values/ca.yaml

To install kafka cluster on kubernetes run

cd prod_example

./example_kafka.sh

This script will also install Fabric CLI chart on kubernetes.

It will also download, install, instantiate and query chaincode on peer using Fabric CLI

To tear cluster run

./tear.sh

NOTE: I haven't done house keeping of Fabric CLI chart so its very much messy and its a complete copy of peer chart in case you are not able to understand please follow orignal repo.


Follow Orignal repo

https://github.com/aidtechnology/hgf-k8s-workshop

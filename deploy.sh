#!/bin/sh
#Creating pv files
kubectl create -f pvmqa.yaml
kubectl create -f pvmqb.yaml
kubectl create -f pvmqc.yaml

#Creating a secret
kubectl create -f mq-secret.yaml

#Installing Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

#Adding Helm Repo
helm repo add ibm-charts https://raw.githubusercontent.com/IBM/charts/master/repo/stable

#Deploying mq mqb mqc
helm install mqa ibm-charts/ibm-mqadvanced-server-dev --version 4.0.0 --set license=accept,service.type=NodePort --set queueManager.dev.secret.name=mq-secret --set queueManager.dev.secret.adminPasswordKey=adminPassword --set security.initVolumeAsRoot=true

helm install mqb ibm-charts/ibm-mqadvanced-server-dev --version 4.0.0 --set license=accept,service.type=NodePort --set queueManager.dev.secret.name=mq-secret --set queueManager.dev.secret.adminPasswordKey=adminPassword --set security.initVolumeAsRoot=true

helm install mqc ibm-charts/ibm-mqadvanced-server-dev --version 4.0.0 --set license=accept,service.type=NodePort --set queueManager.dev.secret.name=mq-secret --set queueManager.dev.secret.adminPasswordKey=adminPassword --set security.initVolumeAsRoot=true

#creating a LB
kubectl create -f lb.yaml

#Exposing NodePorts for pods
kubectl expose pod mqa-ibm-mq-0 --port 1414 --name mqa-service --type=NodePort
kubectl expose pod mqb-ibm-mq-0 --port 1414 --name mqb-service --type=NodePort
kubectl expose pod mqc-ibm-mq-0 --port 1414 --name mqc-service --type=NodePort

#Exposing Nodeports to access ibmmq tool on web browser.
mqa=$(kubectl get services --output jsonpath='{.items[0].spec.ports[0].nodePort}' --field-selector metadata.name=mqa-ibm-mq)
mqb=$(kubectl get services --output jsonpath='{.items[0].spec.ports[0].nodePort}' --field-selector metadata.name=mqb-ibm-mq)
mqc=$(kubectl get services --output jsonpath='{.items[0].spec.ports[0].nodePort}' --field-selector metadata.name=mqc-ibm-mq)
lb=$(kubectl get services --output jsonpath='{.items[0].spec.ports[0].nodePort}' --field-selector metadata.name=lb)

#Enabling Firewalls to access on web browser
gcloud compute firewall-rules create mqa --allow tcp:$mqa
gcloud compute firewall-rules create mqb --allow tcp:$mqb
gcloud compute firewall-rules create mqc --allow tcp:$mqc
gcloud compute firewall-rules create lb --allow tcp:$lb

#Pausing for 120seconds.
read -p "Pause Time 120 seconds" -t 120
read -p "Continuing in 120 Seconds...." -t 120
echo "Continuing ...."

#mqa:
echo "alter QMGR CHLAUTH(DISABLED) CONNAUTH(' ')" | kubectl exec mqa-ibm-mq-0 -i -- /usr/bin/runmqsc
echo "alter qmgr CONNAUTH(' ')" | kubectl exec mqa-ibm-mq-0 -i -- /usr/bin/runmqsc
echo "define channel('SVRCONN') CHLTYPE(SVRCONN)" | kubectl exec mqa-ibm-mq-0 -i -- /usr/bin/runmqsc
echo "DEFINE QL(Q1) DEFPSIST(YES)" | kubectl exec mqa-ibm-mq-0 -i -- /usr/bin/runmqsc
echo "alter channel('SVRCONN') CHLTYPE(SVRCONN) SSLCAUTH(OPTIONAL)" | kubectl exec mqa-ibm-mq-0 -i -- /usr/bin/runmqsc
kubectl exec mqa-ibm-mq-0 -i -t -- setmqaut -m mqa -t q -n Q1 -p app +all

echo "ALTER QMGR REPOS(MQCLUSTER)" | kubectl exec mqa-ibm-mq-0 -i -- /usr/bin/runmqsc
echo "DEFINE CHANNEL('TO.mqa') CHLTYPE(CLUSRCVR) CLUSTER('MQCLUSTER') CONNAME('mqa-ibm-mq') TRPTYPE(TCP)" | kubectl exec mqa-ibm-mq-0 -i -- /usr/bin/runmqsc
echo "DEFINE CHANNEL('TO.mqb') CHLTYPE(CLUSSDR) CLUSTER('MQCLUSTER') CONNAME('mqb-ibm-mq') TRPTYPE(TCP)" | kubectl exec mqa-ibm-mq-0 -i -- /usr/bin/runmqsc
kubectl exec mqa-ibm-mq-0 -i -t -- rm -rf /var/mqm/qmgrs/mqa/qm.ini
kubectl cp ./mqa/qm.ini default/mqa-ibm-mq-0:/var/mqm/qmgrs/mqa/
kubectl exec mqa-ibm-mq-0 -it -- endmqm -r mqa

#mqb:
echo "alter QMGR CHLAUTH(DISABLED) CONNAUTH(' ')" | kubectl exec mqb-ibm-mq-0 -i -- /usr/bin/runmqsc
echo "alter qmgr CONNAUTH(' ')" | kubectl exec mqb-ibm-mq-0 -i -- /usr/bin/runmqsc
echo "define channel('SVRCONN') CHLTYPE(SVRCONN)" | kubectl exec mqb-ibm-mq-0 -i -- /usr/bin/runmqsc
echo "DEFINE QL(Q1) DEFPSIST(YES)" | kubectl exec mqb-ibm-mq-0 -i -- /usr/bin/runmqsc
echo "alter channel('SVRCONN') CHLTYPE(SVRCONN) SSLCAUTH(OPTIONAL)" | kubectl exec mqb-ibm-mq-0 -i -- /usr/bin/runmqsc
kubectl exec mqb-ibm-mq-0 -i -t -- setmqaut -m mqb -t q -n Q1 -p app +all

echo "ALTER QMGR REPOS(MQCLUSTER)" | kubectl exec mqb-ibm-mq-0 -i -- /usr/bin/runmqsc
echo "DEFINE CHANNEL('TO.mqb') CHLTYPE(CLUSRCVR) CLUSTER('MQCLUSTER') CONNAME('mqb-ibm-mq') TRPTYPE(TCP)" | kubectl exec mqb-ibm-mq-0 -i -- /usr/bin/runmqsc
echo "DEFINE CHANNEL('TO.mqa') CHLTYPE(CLUSSDR) CLUSTER('MQCLUSTER') CONNAME('mqa-ibm-mq') TRPTYPE(TCP)" | kubectl exec mqb-ibm-mq-0 -i -- /usr/bin/runmqsc
kubectl exec mqb-ibm-mq-0 -i -t -- rm -rf /var/mqm/qmgrs/mqb/qm.ini
kubectl cp ./mqb/qm.ini default/mqb-ibm-mq-0:/var/mqm/qmgrs/mqb/
kubectl exec mqb-ibm-mq-0 -it -- endmqm -r mqb

#mqc:
echo "alter QMGR CHLAUTH(DISABLED) CONNAUTH(' ')" | kubectl exec mqc-ibm-mq-0 -i -- /usr/bin/runmqsc
echo "alter qmgr CONNAUTH(' ')" | kubectl exec mqc-ibm-mq-0 -i -- /usr/bin/runmqsc
echo "define channel('SVRCONN') CHLTYPE(SVRCONN)" | kubectl exec mqc-ibm-mq-0 -i -- /usr/bin/runmqsc
echo "DEFINE QL(Q1) DEFPSIST(YES)" | kubectl exec mqc-ibm-mq-0 -i -- /usr/bin/runmqsc
echo "alter channel('SVRCONN') CHLTYPE(SVRCONN) SSLCAUTH(OPTIONAL)" | kubectl exec mqc-ibm-mq-0 -i -- /usr/bin/runmqsc
kubectl exec mqc-ibm-mq-0 -i -t -- setmqaut -m mqc -t q -n Q1 -p app +all

echo "ALTER QMGR REPOS(MQCLUSTER)" | kubectl exec mqc-ibm-mq-0 -i -- /usr/bin/runmqsc
echo "DEFINE CHANNEL('TO.mqc') CHLTYPE(CLUSRCVR) CLUSTER('MQCLUSTER') CONNAME('mqc-ibm-mq') TRPTYPE(TCP)" | kubectl exec mqc-ibm-mq-0 -i -- /usr/bin/runmqsc
echo "DEFINE CHANNEL('TO.mqb') CHLTYPE(CLUSSDR) CLUSTER('MQCLUSTER') CONNAME('mqb-ibm-mq') TRPTYPE(TCP)" | kubectl exec mqc-ibm-mq-0 -i -- /usr/bin/runmqsc
kubectl exec mqc-ibm-mq-0 -i -t -- rm -rf /var/mqm/qmgrs/mqc/qm.ini
kubectl cp ./mqc/qm.ini default/mqc-ibm-mq-0:/var/mqm/qmgrs/mqc/
kubectl exec mqc-ibm-mq-0 -it -- endmqm -r mqc

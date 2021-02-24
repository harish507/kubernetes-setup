#!/bin/sh
#Creating a master and worker1 node

gcloud config set project sample-golang-279703

gcloud compute instances create kube --image ubuntu-1804-bionic-v20200923 --image-project ubuntu-os-cloud --zone us-central1-a --machine-type n1-standard-2 --boot-disk-device-name kube --tags http --scopes https://www.googleapis.com/auth/cloud-platform --metadata-from-file startup-script=master.sh --zone us-central1-a


gcloud compute instances create worker1 --image ubuntu-1804-bionic-v20200923 --image-project ubuntu-os-cloud --zone us-central1-a --machine-type n1-standard-4 --boot-disk-device-name worker1 --tags http --scopes https://www.googleapis.com/auth/cloud-platform --metadata-from-file startup-script=worker.sh --zone us-central1-a

#gcloud compute ssh --project sample-golang-279703 --zone us-central1-a kube



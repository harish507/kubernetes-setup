#!/bin/sh
#sudo su
git clone https://github.com/navanith12/ibmmq-gcp-vm.git
git clone https://NavanithRao@bitbucket.org/msslabsresearch/ibmmq-gcp.git
sudo apt-get update
sudo apt-get install docker.io -y
sudo systemctl enable docker
sudo systemctl start docker
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add
sudo apt-get install curl
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
sudo apt-get install kubeadm kubelet kubectl -y
sudo apt-mark hold kubeadm kubelet kubectl
sudo swapoff -a
sudo hostnamectl set-hostname worker1

#Creating and Attaching a Persistent Disk
gcloud compute disks create ibm --size 10GB --type pd-standard --zone us-central1-a
gcloud compute instances attach-disk worker1 --disk ibm --zone us-central1-a
sudo mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/sdb

#Creating a directory and mounting it to the disk
sudo mkdir -p /datadrive/
sudo mount -o discard,defaults /dev/sdb /datadrive/
sudo chmod a+w /datadrive/
echo UUID=`sudo blkid -s UUID -o value /dev/sdb` /datadrive/ ext4 discard,defaults,nofail 0 2 | sudo tee -a /etc/fstab

#!/bin/bash

sudo apt update && sudo apt install podman -y &&\
sudo apt-get install -y apt-transport-https ca-certificates curl gpg &&\
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg &&\
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list &&\
sudo apt update && sudo apt install kubeadm kubelet -y &&\
sudo apt-mark hold kubeadm kubelet &&\
sudo systemctl enable --now kubelet


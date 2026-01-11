#!/bin/bash

TOKEN=$(curl -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 60" http://169.254.169.254/latest/api/token)
KEY=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/public-keys/" | awk '{print $1}')

if [[ $KEY == "cplane" ]]; then
  kctl=$(which kubectl | awk '{print $1}')
  if [[ -z $kctl ]]; then
    cat << EOF > ~/.ssh/config
Host jump
  HostName ${aws_instance.jump.private_ip}
  IdentityFile ~/.ssh/jump.pem
EOF
    cat << EOF > ~/.ssh/jump.pem
${jump_pem}    
EOF 
    echo "Control Plane not installed"
    ssh jump "sudo ansible-playbook -i cplane.yml main.yml -e @CPLANE.yml -t cplane"
  else
    cat <<EOF > /tmp/join-config.yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: JoinConfiguration
caCertPath: /etc/kubernetes/pki/ca.crt
discovery:
  bootstrapToken:
    apiServerEndpoint: "cplane.sovereignstack.com:6443"
    token: ${token} 
    discoveryTokenAPIServerHashes: ${discovery_sha}
    unsafeSkipCAVerification: false
  file:
    kubeConfigPath: ""
nodeRegistration:
  criSocket: ""
  imagePullPolicy: IfNotPresent
  name: ""
  paced: ""
  taints: null
EOF
    sudo kubeadm join --config /tmp/join-config.yaml
  fi
elif [[ $KEY == "workers" ]]; then
  cat <<EOF > /tmp/join-config.yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: JoinConfiguration
caCertPath: /etc/kubernetes/pki/ca.crt
discovery:
  bootstrapToken:
    apiServerEndpoint: "cplane.sovereignstack.com:6443"
    token: ${token} 
    discoveryTokenAPIServerHashes: ${discovery_sha}
    unsafeSkipCAVerification: false
  file:
    kubeConfigPath: ""
nodeRegistration:
  criSocket: ""
  imagePullPolicy: IfNotPresent
  name: ""
  paced: ""
  taints: null
EOF
  sudo kubeadm join --config /tmp/join-config.yaml  
fi
### This project aims to showcase a easy to use and deploy self-hosted (sovereign) kubernetes cluster while still being cost effective and compliant with most standards like HIPAA and ISO 27001.

### Flow of the project

```
1. Creating terraform module based template.
2. Ansible playbook to automate the Cplane setup.
3. Packer to create the AMI for the workers.
4. Helm chart to deploy application and monitoring.
```

### Completion Status

- [-] Terraform module based template.
  - [x] Network Module
  - [] LT + ASG (Control plane + Workers)
  - [] ALB Module 
  - [] RDS Module
  - [] S3 + CloudFront Module 
  - [] Route53 Module (With Application Recovery Controller)

- [] Ansible playbook to automate the Control Plane setup.
- [] Packer to create the AMI for the workers.
- [] Helm chart to deploy application and monitoring.
  - [] Calico
  - [] Nginx-Ingress
  - [] Cert-Manager
  - [] Karpenter
  - [] Metric Server
  - [] API (Python)
  - [] Jenkins
  - [] ArgoCD
  - [] Prometheus
  - [] Grafana
  - [] Alertmanager
  - [] Loki

### Setups steps ->

```
On local system
1. git clone git@github.com:sovereign-stack/sovereign-stack.git
2. cd sovereign-stack
3. ssh-keygen -t ed25519 -C "cplane" -f ~/.ssh/cplane.pem
4. cd terraform/env/
5. terragrunt run-all init
6. terragrunt run-all plan
7. terragrunt run-all apply

On AWS Jump server
8. Ansible run tag for cplane setup.
9. Helm setup for the cluster. (Repeat for all other environments.)
```
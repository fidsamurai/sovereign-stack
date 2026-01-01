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
  - [] LT + ASG + ALB Module (Cplane + Workers)
  - [] RDS Module
  - [] S3 + CloudFront Module 
  - [] Route53 Module

- [] Ansible playbook to automate the Cplane setup.
- [] Packer to create the AMI for the workers.
- [] Helm chart to deploy application and monitoring.
  - [] Calico
  - [] Nginx-Ingress
  - [] Cert-Manager
  - [] Karpenter
  - [] Metric Server
  - [] API
  - [] Jenkins
  - [] ArgoCD
  - [] Prometheus
  - [] Grafana
  - [] Alertmanager
  - [] Loki

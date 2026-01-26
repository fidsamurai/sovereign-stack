### This project aims to showcase a easy to use and deploy self-hosted (sovereign) kubernetes cluster while still being cost effective and compliant with most standards like HIPAA and ISO 27001.

### Flow of the project

```
1. Creating terraform module based template.
2. Ansible playbook to automate the Cplane setup.
3. Packer to create the AMI for the workers.
4. Helm chart to deploy application and monitoring.
```

### 🏗️ Architectural Summary & Trade-offs

To ensure the platform meets the high-availability and security requirements of regulated industries (FinTech/MedTech), the following design choices were made:

| Feature | Sovereign-Stack Choice | Why it beats the "Standard" | SRE Value |
| :--- | :--- | :--- | :--- |
| **Orchestration** | **Self-Hosted K8s** | Data Sovereignty & 0% EKS Management Fees | Control Plane Depth |
| **Runtime** | **Podman (CRI-O)** | Rootless & Daemon-less Security | HIPAA Hardening |
| **DR Strategy** | **Pilot Light** | Cross-Region Recovery at minimal standby cost | RTO/RPO Focus |
| **Node Scaling** | **Karpenter** | Intent-based scaling (Faster than standard ASG) | Cost Optimization |
| **Networking** | **3-Tier VPC** | Physical Database & App Tier Isolation | ISO 27001 Compliance |

### Completion Status

- [-] Terraform module based template.
  - [x] Network Module
  - [x] LT + ASG (Control plane + Workers)
  - [x] ALB Module (aws-load-balancer-controller via helm) 
  - [] RDS + Self-hosted Redis + Self Hosted Elasticsearch Module
  - [] S3 + CloudFront Module 
  - [] Route53 Module (With Application Recovery Controller) + Jump Server

- [] Ansible playbook to automate the Control Plane setup.
- [x] Packer to create the AMI with Podman and K8s for the workers.
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

- [x] Wrapper script in Go to automate the entire process end-end.

### Setups steps ->

-> Recommended setup ->

```
1. `git clone git@github.com:sovereign-stack/sovereign-stack.git`
2. cd sovereign-stack/
3. Move all the example-config-*.yaml to config-*.yaml #Enter all the values in the config-*.yaml file for the region and environment.
4. cd wrapper/
5. Download release for the your OS and architecture from https://github.com/fidsamurai/sovereign-stack/releases and extract it.
6. ./sov-cli prereqs #Ensure there are no errors in the output.
7. ./sov-cli infra --first-time=true #--first-time=true is ONLY for the first time deployment.
```

### Development Note This CLI was architected using Anti-gravity via 'vibe coding' patterns.
### Attribution is given to the Anti-gravity engine for the structural scaffolding.
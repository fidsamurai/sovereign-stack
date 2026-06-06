# Sovereign Stack

A self-hosted Kubernetes platform on AWS, built for regulated industries (FinTech / MedTech). It runs a full pilot light disaster recovery setup across two AWS regions, keeps your data inside your own infrastructure, and costs significantly less than managed EKS.

> **Pilot Light DR** means your DR region is always on but minimal — just the network and a dormant cluster skeleton. In a failover event, you scale it up. Recovery is fast, standby cost is low.

---

## Table of Contents

1. [What gets deployed](#what-gets-deployed)
2. [Architecture overview](#architecture-overview)
3. [Prerequisites](#prerequisites)
4. [AWS account setup](#aws-account-setup)
5. [Configuration files](#configuration-files)
6. [Deployment walkthrough](#deployment-walkthrough)
7. [CLI reference](#cli-reference)
8. [Project structure](#project-structure)
9. [Technology decisions](#technology-decisions)
10. [Completion status](#completion-status)
11. [Known issues (work in progress)](#known-issues-work-in-progress)

---

## What gets deployed

| Layer | What it is | Where |
| :--- | :--- | :--- |
| **VPC** | 3-tier network (public / private / database subnets) across 2 AZs | Both regions |
| **NAT** | NAT instance (dev, cheap) or NAT gateways (prod, HA) | Both regions |
| **Jump server** | Bastion host with Ansible + Git pre-installed, used to bootstrap the cluster | Both regions |
| **Control plane** | Self-hosted K8s control plane on EC2 (arm64, spot-capable) | Both regions |
| **Workers** | ASG-managed worker nodes running Podman/CRI-O + kubelet | Both regions |
| **OIDC endpoint** | S3 + CloudFront + ACM, serves the K8s service account public key for IRSA | Both regions |
| **ALB controller** | AWS Load Balancer Controller deployed via Helm, managed in Terraform state | Both regions |
| **Security groups** | Scoped per component: NAT, ALB, RDS (placeholder), control plane, workers, jump | Both regions |

The four environments this covers:

| Config file | Region | Purpose |
| :--- | :--- | :--- |
| `config-dev-primary.yaml` | eu-west-1 | Development — primary region |
| `config-dev-dr.yaml` | eu-west-2 | Development — disaster recovery region |
| `config-prod-primary.yaml` | eu-west-1 | Production — primary region |
| `config-prod-dr.yaml` | eu-west-2 | Production — disaster recovery region |

---

## Architecture overview

```
                      ┌─────────────────────────────────────────┐
                      │           PRIMARY REGION (eu-west-1)     │
                      │                                          │
   Internet ──────── ALB ──── Public Subnets ──── Jump Server   │
                      │              │                           │
                      │       Private Subnets                    │
                      │         ├── Control Plane (ASG)          │
                      │         └── Workers (ASG, Spot)          │
                      │                                          │
                      │   S3 + CloudFront (OIDC endpoint)        │
                      └─────────────────────────────────────────┘
                                       │
                              (Pilot Light DR)
                                       │
                      ┌─────────────────────────────────────────┐
                      │           DR REGION (eu-west-2)          │
                      │    (same structure, scaled to minimum)   │
                      └─────────────────────────────────────────┘
```

See `Docs/architecture.md` and `Docs/arch.svg` for a more detailed diagram.

**Key design choices at a glance:**

| Choice | Reason |
| :--- | :--- |
| Self-hosted K8s (not EKS) | No $73/month control plane fee. Full control over CNI, CSI, and runtime. |
| Podman + CRI-O | Rootless, daemonless container runtime. Required for HIPAA hardening. |
| Karpenter (not Cluster Autoscaler) | Just-in-time node provisioning, picks cheapest available instance type. |
| 3-tier VPC | Physical tier isolation between web, app, and database layers. ISO 27001. |
| OIDC via S3/CloudFront | Serverless, zero-cost OIDC discovery endpoint for IRSA (no dedicated IdP). |
| Spot workers | `price-capacity-optimized` strategy reduces worker node costs significantly. |
| NAT instance in dev | ~$5/month vs ~$35/month for a NAT gateway. Same egress function. |
| Go CLI wrapper | Type-safe, multi-region orchestration. Handles SSH key generation, config parsing, and module-granular Terraform operations. |

---

## Prerequisites

You need these tools installed on your local machine before running anything.

### Required tools

| Tool | Install guide | Min version |
| :--- | :--- | :--- |
| **AWS CLI v2** | [docs.aws.amazon.com/cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | v2.x |
| **Terragrunt** | [terragrunt.gruntwork.io](https://terragrunt.gruntwork.io/docs/getting-started/install/) | v0.55+ |
| **Terraform** | [developer.hashicorp.com/terraform](https://developer.hashicorp.com/terraform/install) | v1.6+ |
| **Packer** | [developer.hashicorp.com/packer](https://developer.hashicorp.com/packer/install) | v1.10+ |

> The `sov-cli` binary handles everything else (SSH key generation, config validation, Terragrunt orchestration). You do **not** need to install Ansible locally — it runs on the jump server.

### Check your tools are installed

```bash
aws --version
terragrunt --version
terraform --version
packer --version
```

---

## AWS account setup

You need **four AWS CLI profiles** configured before running the CLI. These map directly to the four environments.

```bash
# Primary dev account
aws configure --profile dev

# DR dev account (can be same account, different region is fine)
aws configure --profile dev-dr

# Primary prod account
aws configure --profile prod

# DR prod account
aws configure --profile prod-dr
```

Each profile needs credentials with permissions to manage EC2, VPC, IAM, S3, CloudFront, Route53, and ACM.

### Route53 domain

You must have a domain registered in Route53 **before deploying**. The OIDC endpoint and the K8s API server DNS record are created automatically, but the hosted zone must already exist.

```bash
# Verify your hosted zone exists
aws route53 list-hosted-zones --profile dev | grep your-domain.com
```

---

## Configuration files

The CLI reads YAML config files from the root of the repo. One file per environment.

### Step 1 — Copy the example files

```bash
cd sovereign-stack/

cp example-config-dev-primary.yaml  config-dev-primary.yaml
cp example-config-dev-dr.yaml       config-dev-dr.yaml
cp example-config-prod-primary.yaml config-prod-primary.yaml
cp example-config-prod-dr.yaml      config-prod-dr.yaml
```

> The `config-*.yaml` files are gitignored. Never commit them — they contain your AWS profile names and infrastructure sizing.

### Step 2 — Fill in the values

Open each config file and fill in the fields. Here is a fully annotated example using `config-dev-dr.yaml` as the reference (it has the most complete field set):

```yaml
# ── Identity ────────────────────────────────────────────────────────────────
env_prod: false          # true = production environment, false = dev
is_dr: true              # true = this is the DR region deployment
profile: "dev-dr"        # AWS CLI profile name (must exist in ~/.aws/credentials)
aws_region: "eu-west-2"  # AWS region to deploy into

# ── Networking ──────────────────────────────────────────────────────────────
# The VPC CIDR. Make sure it doesn't overlap with your other environments.
cidr_block: "192.168.0.0/16"

# Private subnets (control plane + workers live here — no direct internet access)
private_availability_zones: ["eu-west-2a", "eu-west-2b"]
private_cidr_blocks: ["192.168.1.0/24", "192.168.2.0/24"]

# Public subnets (jump server, NAT, ALB live here)
public_availability_zones: ["eu-west-2a", "eu-west-2b"]
public_cidr_blocks: ["192.168.3.0/24", "192.168.4.0/24"]

# NAT instance type (dev only — prod uses managed NAT gateways instead)
# t4g.micro is arm64, cheap (~$5/month), and sufficient for NAT traffic
nat_instance_type: "t4g.micro"

# ── Control Plane ASG ────────────────────────────────────────────────────────
# These are instance *requirements*, not a fixed instance type.
# AWS picks the best available arm64 instance that fits within these bounds.
asg-cplane-min-vcpu-count: 2
asg-cplane-max-vcpu-count: 4
asg-cplane-min-memory-mib: 2048   # 2 GB
asg-cplane-max-memory-mib: 4096   # 4 GB

# ── Worker ASG ───────────────────────────────────────────────────────────────
asg-workers-min-vcpu-count: 2
asg-workers-max-vcpu-count: 4
asg-workers-min-memory-mib: 2048
asg-workers-max-memory-mib: 4096

# ── DNS ──────────────────────────────────────────────────────────────────────
# Your Route53 root domain. The OIDC subdomain is created automatically.
# This hosted zone must already exist in Route53 before you deploy.
domain: "your-domain.com"
```

### Field reference

| Field | Module | Required | Notes |
| :--- | :--- | :--- | :--- |
| `env_prod` | root | yes | Drives prod vs dev behaviour across all modules |
| `is_dr` | root | yes | Marks this as a DR region deployment |
| `profile` | root | yes | Must match an `aws configure --profile` name |
| `aws_region` | root | yes | AWS region string, e.g. `eu-west-1` |
| `cidr_block` | network | yes | VPC CIDR, must not overlap across environments |
| `private_availability_zones` | network | yes | List of AZs for private subnets |
| `private_cidr_blocks` | network | yes | One CIDR per AZ in the list above |
| `public_availability_zones` | network | yes | List of AZs for public subnets |
| `public_cidr_blocks` | network | yes | One CIDR per AZ in the list above |
| `nat_instance_type` | network | yes | Used only when `env_prod: false` |
| `asg-cplane-*` | asg | yes | Min/max vCPU and memory for control plane instances |
| `asg-workers-*` | asg | yes | Min/max vCPU and memory for worker instances |
| `domain` | asg | yes | Root domain — must exist as a Route53 hosted zone |

---

## Deployment walkthrough

### 1. Clone the repo

```bash
git clone https://github.com/fidsamurai/sovereign-stack.git
cd sovereign-stack
```

### 2. Download the CLI binary

Go to the [Releases page](https://github.com/fidsamurai/sovereign-stack/releases) and download the binary for your OS and architecture.

```bash
# Example: Linux ARM64
curl -L https://github.com/fidsamurai/sovereign-stack/releases/latest/download/sov-cli-linux-arm64.tar.gz | tar xz
chmod +x sov-cli
```

Available builds: `linux-amd64`, `linux-arm64`, `darwin-amd64`, `darwin-arm64`, `windows-amd64`.

### 3. Create and fill in your config files

Follow the [Configuration files](#configuration-files) section above.

### 4. Build the worker AMI with Packer

The worker nodes need a pre-baked AMI with Podman and the K8s tooling installed. Run this once before the first deployment.

```bash
cd packer/
packer init workers.hcl
packer build workers.hcl
```

This creates an AMI named `workers` in the region defined in `workers.hcl` (default: `us-east-1`). Update the region in the file if you need it in a different one.

### 5. Run prereqs check

This validates your config files, checks your AWS CLI profiles, and generates the Terragrunt variable files.

```bash
cd wrapper/
./sov-cli prereqs --envs dev-primary,dev-dr,prod-primary,prod-dr
```

If you only want to deploy a subset of environments:

```bash
./sov-cli prereqs --envs dev-primary,dev-dr
```

A clean run looks like:

```
terragrunt is installed at /usr/local/bin/terragrunt
aws is installed at /usr/local/bin/aws
✅ AWS Profile 'dev' found
✅ AWS Profile 'dev-dr' found
📂 Written vars for module [network] to ../terraform/env/dev/primary/network/env_vars.yaml
📂 Written vars for module [asg] to ../terraform/env/dev/primary/asg/env_vars.yaml
📂 Written vars for module [root] to ../terraform/env/dev/primary/region.hcl
```

If you see a `missing required field` error, check that all fields in the config file use **hyphenated keys** (e.g., `asg-cplane-min-vcpu-count`, not `asg_cplane_min_vcpu_count`).

### 6. First deployment

```bash
./sov-cli infra --first-time=true
```

This runs `terragrunt init` then `terragrunt apply` across all modules in the correct order. It will apply without prompting — only use `--first-time=true` on a fresh deployment.

What happens under the hood:

1. Generates all SSH key pairs into `~/.ssh/` (nat, jump, cplane, worker keys for each env/region)
2. Runs `terragrunt init`
3. Applies the full stack: network → ASG (jump + control plane + workers) → ALB
4. The jump server boots, clones the repo, and installs Ansible
5. When the control plane ASG launches an instance, it SSHes through the jump to run the Ansible playbook
6. Ansible installs Podman, kubeadm, kubelet, starts the control plane, generates a join token, and uploads the OIDC JWKS to S3
7. Worker ASG instances boot and join the cluster using the token from the jump server

### 7. Subsequent updates (modular apply)

After the first deployment, use the modular format to update specific components:

```bash
# Update a single module
./sov-cli infra --modules dev-primary-network

# Update multiple modules
./sov-cli infra --modules dev-primary-asg,dev-dr-network

# Update everything
./sov-cli infra --modules all
```

For non-first-time runs, the CLI shows a plan and asks for confirmation before applying:

```
🔍 Running Plan for: dev-primary-network...
[... plan output ...]
❓ Plan successful for dev-primary-network. Type 'true' to apply:
```

Type `true` and press Enter to apply, or anything else to skip.

---

## CLI reference

All commands are run from the `wrapper/` directory.

### `prereqs`

Validates config files, checks AWS profiles, and generates Terragrunt variable files.

```bash
./sov-cli prereqs [--envs <env-list>]
```

| Flag | Default | Description |
| :--- | :--- | :--- |
| `--envs` | `all` | Comma-separated list: `dev-primary`, `dev-dr`, `prod-primary`, `prod-dr`, or `all` |

### `infra`

Deploys infrastructure. On first run, applies everything. On subsequent runs, shows a plan per module and prompts for approval.

```bash
./sov-cli infra [--first-time=true] [--modules <module-list>]
```

| Flag | Default | Description |
| :--- | :--- | :--- |
| `--first-time` | `false` | Set to `true` only on fresh deployments. Skips plan prompt and applies all modules. Also generates SSH keys and runs `terragrunt init`. |
| `--modules` | `all` | Comma-separated list of modules. Format: `<env>-<region>-<component>`, e.g. `dev-dr-network`, `prod-primary-asg`. Use `all` to target everything. |

### `validate`

Runs `terragrunt validate` against one or more modules.

```bash
./sov-cli validate [--modules <module-list>]
```

### `state-refresh`

Refreshes Terraform state against live AWS resources (useful after out-of-band changes).

```bash
./sov-cli state-refresh [--modules <module-list>]
```

### `destroy`

Destroys one or more modules. Shows a destroy plan and asks for confirmation.

```bash
./sov-cli destroy [--modules <module-list>]
```

> Be careful with `--modules all` — this will tear down all four environments.

---

## Project structure

```
sovereign-stack/
│
├── config-*.yaml              # Your environment configs (gitignored, created from examples)
├── example-config-*.yaml      # Example config files — copy and fill these in
│
├── wrapper/                   # Go CLI (sov-cli)
│   ├── cli.go                 # Entry point, subcommand routing
│   ├── infra/infra.go         # SSH key gen, terragrunt init/apply/destroy/validate
│   └── prereqs/prereqs.go     # Config validation, AWS profile check, var file generation
│
├── terraform/
│   ├── root.hcl               # Terragrunt root config (backend, provider generation)
│   ├── fallback.hcl           # Default region/profile if no region.hcl found
│   ├── env/                   # Generated by sov-cli prereqs — do not edit manually
│   │   └── <env>/<region>/
│   │       ├── region.hcl     # Region + profile locals
│   │       ├── network/env_vars.yaml
│   │       └── asg/env_vars.yaml
│   └── modules/
│       ├── network/           # VPC, subnets, NAT, security groups
│       ├── asg/               # Launch templates, ASGs, IAM, OIDC (S3+CloudFront)
│       └── alb/               # AWS Load Balancer Controller (Helm + IAM)
│
├── ansible/
│   ├── main.yml               # Top-level playbook (runs cplane then token roles)
│   ├── cplane.yml             # Dynamic inventory file (populated at runtime)
│   ├── group_vars/_all        # Shared variables (keyring path, S3 bucket name)
│   └── roles/
│       ├── cplane/tasks/      # Installs Podman, kubeadm, kubelet, kubectl
│       └── token/tasks/       # Creates join token, converts SA key to JWKS, uploads to S3
│
├── packer/
│   ├── workers.hcl            # Packer build definition (Ubuntu 24.04 arm64)
│   └── workers.sh             # Provisioner script: installs Podman + K8s tooling
│
├── helm/
│   └── calico.yaml            # Calico CNI manifest (ready to apply)
│
└── Docs/
    ├── architecture.md
    └── arch.svg
```

---

## Technology decisions

See [`Decisions.md`](Decisions.md) for the full rationale. Quick summary:

**Why self-hosted K8s instead of EKS?**
EKS charges $73/month per cluster just for the control plane. Self-hosted costs only the EC2 instances you run. For a 4-environment setup (dev + prod × primary + DR), that's a meaningful saving. You also get full control over the runtime, CNI, and CSI.

**Why Podman instead of Docker?**
Podman is rootless and daemonless — no root-owned daemon running permanently. This satisfies HIPAA's "least privilege" requirements for container runtimes and eliminates a whole class of daemon compromise scenarios.

**Why Karpenter instead of Cluster Autoscaler?**
Cluster Autoscaler reacts after a pod is pending. Karpenter provisions nodes in anticipation, using intent-based scheduling. It also picks the cheapest available instance across all families, not just the one you pre-configured.

**Why a Go CLI instead of shell scripts?**
The CLI manages four environments across two regions with cross-cutting concerns (SSH keys, profile validation, module-granular apply). Shell scripts at that complexity become unmaintainable. Go gives you type safety, real error handling, and a single cross-platform binary.

**Why IAM-based OIDC via S3/CloudFront?**
IRSA (IAM Roles for Service Accounts) needs an OIDC discovery endpoint. Running a dedicated IdP would cost money and require management. Hosting the static JWKS file on S3 behind CloudFront is serverless, free at this scale, and fully supported by AWS STS.

---

## Completion status

### Infrastructure (Terraform)
- [x] Network module — VPC, subnets, NAT, security groups
- [x] ASG module — jump server, control plane, workers, OIDC endpoint
- [x] ALB module — AWS Load Balancer Controller via Helm
- [ ] RDS module
- [ ] Self-hosted Redis module
- [ ] Self-hosted Elasticsearch module
- [ ] S3 + CloudFront module (for application assets)
- [ ] Route53 module with Application Recovery Controller (for DR failover)

### Cluster bootstrapping
- [x] Ansible — control plane setup (Podman, kubeadm, kubelet)
- [x] Ansible — join token generation and OIDC JWKS upload
- [x] Packer — worker AMI (Ubuntu 24.04, Podman, kubeadm, kubelet)

### In-cluster components (Helm)
- [x] Calico CNI manifest ready
- [ ] Nginx Ingress
- [ ] Cert-Manager
- [ ] Karpenter
- [ ] Metrics Server
- [ ] ArgoCD
- [ ] Jenkins
- [ ] Prometheus + Grafana + Alertmanager
- [ ] Loki

### CLI
- [x] `prereqs` — config validation, profile check, var file generation
- [x] `infra` — SSH key gen, init, modular plan/apply
- [x] `validate` — terragrunt validate per module
- [x] `state-refresh` — refresh-only plan/apply per module
- [x] `destroy` — plan/apply destroy per module

### CI/CD
- [x] GitHub Actions — builds cross-platform CLI binaries on version tag and publishes to GitHub Releases

---

## Known issues (work in progress)

These are active bugs in the codebase that have been identified and are being fixed:

**Ansible role task file structure** — Both `cplane` and `token` role task files have a spurious top-level `tasks:` key. Ansible expects the file to be a plain YAML list. This will cause playbook execution to fail.

**`cluster_join.tftpl` shell bugs** — The bootstrap script has several bash syntax errors (malformed variable assignments, unescaped awk field separators in SSH commands, unclosed quotes). The `kubeadm` join config also has a hardcoded API server endpoint that needs to be rendered from the `domain` template variable.

**`aws_nat_gateway_eip_association` resource** — This Terraform resource type does not exist in the AWS provider. The EIP is associated with a NAT gateway via the `allocation_id` argument on `aws_nat_gateway` directly. This causes `terraform validate` to fail for the network module.

**Private key in user data** — The jump server private key is currently written into EC2 user data inside `cluster_join.tftpl`. User data is retrievable via the instance metadata endpoint and the AWS console. This will be replaced with SSM Parameter Store.

**Terraform state is local** — `root.hcl` uses `backend = "local"`. For a multi-region team deployment this needs to be S3 + DynamoDB. This is a known limitation of the current state of the project.

**`go.mod` Go version** — The module declares `go 1.25.5` which does not exist. This should be `go 1.23` or `go 1.24`.

**Packer HCL structure** — The `provisioners` block is outside the `build` block in `workers.hcl`. Packer requires provisioners to be nested inside `build`. Also the source AMI filter targets `amd64` while the instance type `t4g.micro` is ARM64 — these are incompatible.

**Config file inconsistency** — `example-config-prod-primary.yaml` and `example-config-prod-dr.yaml` use underscore key names (`asg_cplane_min_vcpu_count`) instead of the hyphenated format (`asg-cplane-min-vcpu-count`) that the Go CLI struct tags and Terraform variables expect. Use `example-config-dev-dr.yaml` as the authoritative reference for key format.

**`prereqs.go` zero-value validation** — The config field validator treats Go zero values (`false` for bools, `0` for ints) as missing fields. This means `env_prod: false` and `is_dr: false` incorrectly fail validation. Fix in progress.

---

## Attribution

CLI architecture scaffolded with assistance from Anti-gravity (vibe coding patterns).

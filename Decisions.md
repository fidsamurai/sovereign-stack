### Creating this file to explain the decisions made in the project.

`Why not 2 branches for dev and prod?`
-> The rationale behind this decision was to make this setup as simple as possible while still achieving all the goals of the project.

`Self-Hosted instead of EKS`
-> First reason is cost, EKS has a flat fee of $73 per month and only for the Control Plane, worker nodes are charged at normal ec2 costs.
-> Second reason is more fine-grained control, we can choose our own CSIs, Network policies etc.

`Karpenter instead of ClusterAutoscaler`
-> ClusterAutoscaler doesn't support just-in-time scaling.
-> Karpenter is more cost-effective as it looks at the cheapest most available option.
-> Initially Karpenter didn't support self-hosted deployments, however we now have full support for it.

`Podman instead of Docker`
-> Security - Podman is more secure as it doesn't require root access.
-> Ease - SystemD integration is easier.
-> Zero overhead as there's no daemon running in the background.

`Installing the ALB controller via terraform helm chart`
-> Maintains a state for the controller itself in case we destroy the cluster and want to reapply it.

`Modular Go Wrapper vs Shell Scripts`
-> The Go wrapper provides a more robust and type-safe way to manage multi-region deployments, coordinate SSH keys, and handle granular module updates (plan/apply) across different environments (Dev/Prod).

`Dynamic Subnetting for HA/DR`
-> Hardcoded subnet counts are restrictive. Using dynamic lists for AZs and CIDRs allows the stack to adapt to regional availability and specific compliance requirements for tier isolation.

`IAM-based OIDC Provider via S3/CloudFront`
-> Provides a cost-effective, serverless OIDC discovery endpoint for Kubernetes Service Accounts to assume IAM roles without the overhead of managing a dedicated identity provider.
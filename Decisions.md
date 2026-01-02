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
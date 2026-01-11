resource "aws_iam_policy" "lbc_policy" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("iam_policy.json") # Downloaded from AWS
}

resource "aws_iam_role_policy_attachment" "lbc_attach" {
  role       = var.worker_node_iam_role_name
  policy_arn = aws_iam_policy.lbc_policy.arn
}

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = "sovereign-stack"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
}
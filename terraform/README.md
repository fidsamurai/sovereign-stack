We're looking to create a robust network architecture which would be compliant with GDPR, HIPAA, ISO 27001 and SOC2.

Network Module ->
```
Setup a new VPC with the following -
 - Dynamic private subnets (based on provided availability zones)
 - Dynamic public subnets (based on provided availability zones)
 - 1 internet gateway
 - NAT configuration:
    - Development: 1 NAT Instance for cost saving.
    - Production: 1 NAT Gateway per AZ (Primary) or 1 NAT Gateway (DR) for reliability.
 - Dynamic route tables and associations.
 - Configurable security groups for ALB, RDS, Cplane, Workers, and Jump Server.
```

LT + ASG + ALB Module ->
```
Setup a new LT with the following -
 - 3 LTs (Cplane, Workers, Jump)
 - 3 ASGs (Attribute based instances using Graviton spot instances)
 - 1 ALB (Tied with Nginx-Ingress)
 - Integrated OIDC Provider for IAM-based Service Accounts (via S3/CloudFront)
 - Jump Server for secure access and cluster orchestration.
```

RDS Module ->
```
Setup a new RDS instance with the following -
 - 1 RDS instance (with read replica in DR region)
```

S3 + CloudFront Module ->
```
Setup a new S3 bucket with the following -
 - 1 S3 bucket
 - 1 CloudFront distribution
```

Route53 Module ->
```
Setup a new Route53 record with the following -
 - 2 Route53 records (both will scan for health and point to healthy ALB)
```


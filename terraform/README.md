We're looking to create a robust network architecture which would be compliant with GDPR, HIPAA, ISO 27001 and SOC2.

Network Module ->
```
Setup a new VPC with the following -
 - 2 private subnets
 - 2 public subnets
 - 1 internet gateway
 - 1 NAT gateway (NAT Instance for cost saving on Development environment)
 - 2 route tables
 - 2 route table associations
 - 4 security groups (Can be expanded based on other microservices)
```

LT + ASG + ALB Module ->
```
Setup a new LT with the following -
 - 3 LTs
 - 3 ASGs (Attribute based instances using Graviton spot instances)
 - 1 ALB (Tied with Nginx-Ingress)
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


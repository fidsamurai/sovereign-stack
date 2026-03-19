output "private_subnet_ids" {
  value = [aws_subnet.private[0].id, aws_subnet.private[1].id]
}

output "public_subnet_ids" {
  value = [aws_subnet.public[0].id, aws_subnet.public[1].id]
}

output "cplane-sg-id" {
  value = aws_security_group.Cplane.id
}

output "workers-sg-id" {
  value = aws_security_group.workers.id
}

output "jump-sg-id" {
  value = aws_security_group.jump.id
}
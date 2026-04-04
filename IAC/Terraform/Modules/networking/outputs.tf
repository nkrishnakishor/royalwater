output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "List of subnet IDs"
  value       = aws_subnet.main[*].id
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.node[*].id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.node[*].public_ip
}

output "instance_cpu_count" {
  description = "No. of vCPUs"
  value       = aws_instance.node[*].vcpus
}


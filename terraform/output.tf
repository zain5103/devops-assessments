output "jenkins_master_url" {
  value       = "http://${aws_instance.jenkins_master.public_ip}:8080"
  description = "Access Jenkins Master Dashboard"
}

output "jenkins_agent_public_ip" {
  value       = aws_instance.jenkins_agent.public_ip
  description = "Public IP of Agent Node (Deployment Target)"
}

output "alb_dns_name" {
  value       = "http://${aws_lb.main.dns_name}"
  description = "Application Load Balancer URL"
}

output "s3_backup_bucket" {
  value       = aws_s3_bucket.app_backups.id
  description = "Backup S3 Bucket Name"
}

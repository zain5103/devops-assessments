variable "aws_region" {
  type        = string
  default     = "eu-north-1"
  description = "AWS Region for deployment"
}

variable "environment" {
  type        = string
  default     = "staging"
  description = "Environment name"
}

variable "domain_name" {
  type        = string
  default     = "thelyricsclub.com" # <-- Apna ACM Certificate wala domain likhein
  description = "Domain name for existing ACM SSL Certificate"
}

variable "instance_type" {
  type        = string
  default     = "t3.small"
  description = "EC2 Instance type for Agent Node"
}

variable "master_instance_type" {
  type        = string
  default     = "t3.small"
  description = "EC2 Instance type for Jenkins Master"
}

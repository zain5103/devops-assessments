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

variable "instance_type" {
  type        = string
  default     = "t3.small"
  description = "EC2 Instance type for Agent"
}

variable "master_instance_type" {
  type        = string
  default     = "t3.small"
  description = "EC2 Instance type for Jenkins Master"
}

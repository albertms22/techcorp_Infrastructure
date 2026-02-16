variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "my_ip" {
  description = "Your current IP address for SSH access to bastion (format: x.x.x.x/32)"
  type        = string
}

variable "key_pair_name" {
  description = "Name of the AWS EC2 key pair for SSH access"
  type        = string
}

variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
}

variable "web_instance_type" {
  description = "Instance type for web servers"
  type        = string
}

variable "db_instance_type" {
  description = "Instance type for database server"
  type        = string
}

variable "server_password" {
  description = "Password for techcorp user on servers (for SSH password authentication)"
  type        = string
  sensitive   = true
}

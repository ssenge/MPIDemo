variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "image_id" {
  description = "The id of the machine image (AMI) to use for the server"
  type        = string
  default     = "ami-00060fac2f8c42d30"
}

variable "user" {
  description = "User id for the used image"
  type        = string
  default     = "ec2-user"
}

variable "instance_count" {
  description = "No. of provisioned EC2 instances"
  type        = number
  default     = 1
}

variable "public_key" {
  description = "Path to public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "private_key" {
  description = "Path to private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "access_key_id" {
  description = "AWS access key id"
  type        = string
}

variable "secret_access_key" {
  description = "AWS secret key"
  type        = string
}










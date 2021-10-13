variable "profile" {
  description = "profile"
  type        = string
  default     = "userbilly2"
}

variable "region" {
  description = "region"
  type        = string
  default     = "eu-west-1"
}

variable "key_name" {
	description = "Key Name"
	type = string
	default = "billytest_key_pair_ire"
}

variable "availability_zone" {
	type = list
    default = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

# VPC configuration
variable "vpc_cidr_block" {
    default = "172.16.0.0/21"
}

variable "private_subnet_cidr_block" {
	type = list
    default = ["172.16.3.0/24", "172.16.4.0/24", "172.16.5.0/24"]
}

variable "public_subnet_cidr_block" {
	type = list
    default = ["172.16.0.0/24", "172.16.1.0/24", "172.16.2.0/24"]
}

variable "pavm_public_ip" {
    default = "false"
}

variable "pavm_instance_type" {
    default = "t2.micro"
}

variable "pavm_ami_id" {
    type = map
    default = {
        ap-southeast-1 = "ami-0f9acadd79384a225",
        eu-west-1 = "ami-0fa7c5d715808ffbe"
    }
}
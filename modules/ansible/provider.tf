provider "aws" {
  shared_credentials_files = ["${path.root}/../../config/aws-credentials"]
  shared_config_files      = ["${path.root}/../../config/aws-config"]
}


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.38.0"
    }
    ansible = {
      version = "~> 1.1.0"
      source  = "ansible/ansible"
    }
  }
}
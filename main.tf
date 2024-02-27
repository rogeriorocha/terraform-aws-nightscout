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

# Local vars
locals {
  tags = {
    env = "prd"
    app = "nightscout"
  }
}


# S3 Bucket for codedeploy/codepipeline
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket_prefix = "nightscout-codepipeline-"
  tags          = var.tags
}
resource "aws_s3_bucket_acl" "codepipeline_bucket_acl" {
  bucket = aws_s3_bucket.codepipeline_bucket.id
  acl    = "private"
}


# Nightscout config in SSM
module "ssm" {
  source = "./modules/ssm"
  port   = var.port
  tags   = local.tags
}


# IAM role & policy for EC2 to access SSM & S3
module "ec2_role" {
  source                  = "./modules/ec2_role"
  codepipeline_bucket_arn = aws_s3_bucket.codepipeline_bucket.arn
  tags                    = local.tags
}


# VPC, IG & Routing
module "vpc" {
  source = "./modules/vpc"
  tags   = local.tags
}

# EC2 instance to run Nightscout
module "ec2" {
  source = "./modules/ec2"

  vpc_id                = module.vpc.vpc_id
  public_subnet_id      = module.vpc.public_subnet_id
  ssh_public_key_path   = var.ec2_ssh_public_key_path
  your_ip_address       = var.my_ip
  instance_profile_name = module.ec2_role.instance_profile.name
  instance_type         = var.ec2_instance_type
  tags                  = local.tags
}


# CodeDeploy
module "codedeploy" {
  source = "./modules/codedeploy"
  tags   = local.tags
}

# CodePipeline to deploy from GitHub to EC2
module "codepipeline" {
  source              = "./modules/codepipeline"
  codedeploy_app_name = module.codedeploy.app_name
  git_owner           = var.git_owner
  git_repo            = var.git_repo
  artifact_bucket     = aws_s3_bucket.codepipeline_bucket
  tags                = local.tags
}

# Route53
module "route53" {
  source      = "./modules/route53"
  tags        = local.tags
  ip          = module.ec2.ec2_ip_address
  zone_name   = var.route53_zone_name
  record_name = var.route53_record_name
}

# Ansible
module "ansible" {
  ssh_private_key_path = var.ec2_ssh_private_key_path
  source               = "./modules/ansible"
  username             = "ec2-user"
  ip                   = module.ec2.ec2_ip_address
}

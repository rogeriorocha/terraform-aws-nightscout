#!/bin/sh

export TERM=xterm-256color
export CLICOLOR_FORCE=true
export RICHGO_FORCE_COLOR=1

export ENVIRONMENT=prd

default: prepare fmt init validate plan

prepare:
	MY_IP=$(shell wget -q "http://api.ipify.org" -O -) \
		envsubst  < ./config/template/terraform-${ENVIRONMENT}.tfvars > terraform-${ENVIRONMENT}.tfvars

init:
	terraform init

fmt:
	terraform fmt

validate:
	terraform validate

plan:
	terraform plan -input=false -var-file="terraform-${ENVIRONMENT}.tfvars" -out=create.tfplan

apply:
	terraform apply -input=false -auto-approve create.tfplan

destroy-plan:
	terraform plan -destroy -var-file="terraform-${ENVIRONMENT}.tfvars" -out destroy.tfplan

destroy: destroy-plan
	terraform apply destroy.tfplan

output:
	terraform output

infracost:
	infracost --usage-file=infracost-usage.yml --show-skipped --terraform-plan-flags="-var-file=terraform-${ENVIRONMENT}.tfvars" breakdown --path .


#all: validate plan apply
variable "port" {
  default     = 8080
  description = "Port to run webserver on"
}

variable "display_units" {
  description = "mg/dl or mmol/L"
  default     = "mmol"
  validation {
    condition = anytrue([
      var.display_units == "mmol",
      var.display_units == "mgl"
    ])
    error_message = "Must be a valid display units value. Either 'mg/dl' or 'mmol/L'."
  }
}

variable "ec2_ssh_public_key_path" {
  description = "Public key to install on EC2"  
  default = "config/nightscout-ec2-key.pub"
}


variable "ec2_instance_type" {
  type        = string
  default     = "t3a.micro"
  description = "AWS EC2 instance size to use"  
}


variable "my_ip" {
  description = "Your IP address to access the EC2 via SSH"
  default = "177.66.209.69"
}

variable "git_repo" {
  description = "The name of your Nightscout repository on GitHub, eg 'cgm-remote-monitor'"
  default = "cgm-remote-monitor"
}

variable "git_owner" {
  description = "Your GitHub username"
  default = "rogeriorocha"
}

variable "tags" {
  type = map(string)
  default = {
    env = "prd"
    app  = "nightscout"
  }
  description = "tags for all the resources, if any"
}

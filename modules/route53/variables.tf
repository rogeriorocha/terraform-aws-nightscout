variable "ip" {
  type        = string
  description = "ip"
}

variable "zone_name" {
  type        = string
  description = "zone name"
}

variable "record_name" {
  type        = string
  description = "record name name"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "tags for all the resources, if any"
}

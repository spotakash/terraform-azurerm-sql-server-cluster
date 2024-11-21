variable "prefix" {
  type   = string
  default = "sqlinfraonly"
}

variable "location" {
  type    = string
  default = "eastasia"
}

variable "vnets_ip_groups" {
  type = map(object({
    name     = string
    cidrs    = list(string)
    location = string
  }))
  description = "A map to create ipgroups for vnets"
}

variable "vnet_subnets" {
  type = map(object({
    name  = string
    cidrs = list(string)
  }))
  description = "A map to create subnets for vnets"
}
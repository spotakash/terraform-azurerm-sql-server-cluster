variable "prefix" {
  type    = string
  default = "sqlinfraonly"
}

variable "location" {
  type    = string
  default = "eastasia"
}

variable "vnet_address_space" {
  type = string
}

variable "vnet_subnets" {
  type = map(object({
    name  = string
    cidrs = list(string)
  }))
}

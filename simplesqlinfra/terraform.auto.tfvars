prefix             = "sqlfci"
location           = "eastasia"
vnet_address_space = "172.16.8.0/23"
vnet_subnets = {
  "dc" = {
    name  = "dc-subnet"
    cidrs = ["172.16.8.0/25"]
  },
  "bastion" = {
    name  = "bastion-subnet"
    cidrs = ["172.16.8.128/25"]
  },
  "lb" = {
    name  = "lb-subnet"
    cidrs = ["172.16.9.0/25"]
  },
  "db" = {
    name  = "db-subnet"
    cidrs = ["172.16.9.128/25"]
  }
}


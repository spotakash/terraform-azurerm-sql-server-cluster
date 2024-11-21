prefix = "sqlfci"
location = "eastasia"
vnet_ip_groups = {
  "fci-all-one-vnet" = {
    name     = "fci-all-one-vnet"
    cidrs    = ["172.16.8.0/23"]
    location = "eastasia"
  }
}
vnet_subnets = {
  "fci-all-one-vnet" = {
    name  = "dc-subnet"
    cidrs = ["172.16.8.0/25"]
  },
  "azure-bastion" = {
    name  = "azure-bastion"
    cidrs = ["172.16.8.128/25"]
  },
  "lb-subnet" = {
    name  = "lb-subnet"
    cidrs = ["172.16.9.0/25"]
  },
  "sql-subnet" = {
    name  = "sql-subnet"
    cidrs = ["172.16.9.128/25"]
  }
}
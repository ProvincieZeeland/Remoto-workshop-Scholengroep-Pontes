terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
    azapi = {
      source = "azure/azapi"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}
provider "azapi" {}

resource "azurerm_resource_group" "this" {
  name     = var.azure_rg_name
  location = var.azure_rg_location
}

resource "azurerm_virtual_network" "this" {
  name                = "remoto-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}
resource "azurerm_private_dns_zone" "this" {
  name                = "svc.remoto"
  resource_group_name = azurerm_resource_group.this.name
}
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "remoto-dns-vnet"
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id    = azurerm_virtual_network.this.id
  resource_group_name   = azurerm_resource_group.this.name
}

// Control subnet is bound to Container Workspace for Remoto and GuacD containers
resource "azurerm_subnet" "acae" {
  name                 = "asn-acae"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.0.0/23"]
}
resource "azapi_resource" "containerapp_environment" {
  type      = "Microsoft.App/managedEnvironments@2022-03-01"
  name      = "remoto-acae"
  parent_id = azurerm_resource_group.this.id
  location  = azurerm_resource_group.this.location

  body = jsonencode({
    properties = {
      vnetConfiguration = {
        internal               = true
        infrastructureSubnetId = azurerm_subnet.acae.id
      }
    }
  })
  depends_on = [
    azurerm_virtual_network.this
  ]
  response_export_values  = ["properties.defaultDomain", "properties.staticIp"]
  ignore_missing_property = true
}
resource "azapi_resource" "containerapp_control" {
  type      = "Microsoft.App/containerapps@2022-03-01"
  name      = "control"
  parent_id = azurerm_resource_group.this.id
  location  = azurerm_resource_group.this.location

  body = jsonencode({
    properties = {
      managedEnvironmentId = azapi_resource.containerapp_environment.id
      configuration = {
        ingress = {
          external : true,
          targetPort : 80
        }
      }
      template = {
        containers = [
          {
            image = "ghcr.io/timvosch/remoto:1.0"
            name  = "remoto-control"
            env = [
              {
                name : "REMOTO_GUACD_FQDN",
                value : "guacd.ecs.remoto"
              },
              {
                name : "REMOTO_SANDBOX_FQDN",
                value : "sandbox.remoto"
              },
              {
                name : "REMOTO_HTTP_ADDR",
                value : "0.0.0.0:80"
              },
              {
                name : "REMOTO_WORKSHOP_CODE",
                value : var.remoto_workshop_code
              },
              {
                name : "REMOTO_ADMIN_CODE",
                value : var.remoto_admin_code
              },
              {
                name : "REMOTO_REMOTE_PROTOCOL",
                value : "rdp"
              },
              {
                name : "REMOTO_REMOTE_PORT",
                value : "3389"
              },
              {
                name : "REMOTO_REMOTE_SERIAL_PORT",
                value : "5000"
              },
              {
                name : "REMOTO_REMOTE_USERNAME",
                value : "workshop"
              },
              {
                name : "REMOTO_REMOTE_PASSWORD",
                value : "workshop"
              },
              {
                name : "REMOTO_REMOTE_IGNORE_CERT",
                value : "true"
              },
              {
                name : "REMOTO_REMOTE_SECURITY",
                value : "any"
              },
              {
                name : "REMOTO_REMOTE_WIDTH",
                value : "1366"
              },
              {
                name : "REMOTO_REMOTE_HEIGHT",
                value : "768"
              }
            ]
            resources = {
              cpu    = 0.25
              memory = "0.5Gi"
            }
          }
        ]
        scale = {
          minReplicas = 1,
          maxReplicas = 1
        }
      }
    }
  })
  depends_on = [
    azapi_resource.containerapp_environment
  ]
}
resource "azapi_resource" "containerapp_guacd" {
  type      = "Microsoft.App/containerapps@2022-03-01"
  name      = "guacd"
  parent_id = azurerm_resource_group.this.id
  location  = azurerm_resource_group.this.location

  body = jsonencode({
    properties = {
      managedEnvironmentId = azapi_resource.containerapp_environment.id
      configuration = {
        ingress = {
          external : true,
          targetPort : 4822
        }
      }
      template = {
        containers = [
          {
            image = "docker.io/guacamole/guacd:1.4.0"
            name  = "remoto-guacd"
            resources = {
              cpu    = 2.0
              memory = "4Gi"
            }
          }
        ]
        scale = {
          minReplicas = 1,
          maxReplicas = 1
        }
      }
    }
  })
  depends_on = [
    azapi_resource.containerapp_environment
  ]
}
//resource "azurerm_container_group" "remoto" {
//  name                = "acg-remoto"
//  location            = azurerm_resource_group.this.location
//  resource_group_name = azurerm_resource_group.this.name
//  ip_address_type     = "Private"
//  network_profile_id  = azurerm_network_profile.control.id
//  //dns_name_label      = "remoto-control"
//  os_type             = "Linux"
//
//  container {
//    name   = "remoto-control"
//    image  = var.image_control
//    cpu    = "0.25"
//    memory = "0.5"
//
//    ports {
//      port     = 80
//      protocol = "TCP"
//    }
//
//    environment_variables = {
//      "REMOTO_GUACD_FQDN" : "guacd.ecs.remoto",
//      "REMOTO_SANDBOX_FQDN" : "sandbox.remoto",
//      "REMOTO_HTTP_ADDR" : "0.0.0.0:80",
//      "REMOTO_WORKSHOP_CODE" : var.remoto_workshop_code,
//      "REMOTO_ADMIN_CODE" : var.remoto_admin_code,
//      "REMOTO_REMOTE_PROTOCOL" : "rdp",
//      "REMOTO_REMOTE_PORT" : "3389",
//      "REMOTO_REMOTE_SERIAL_PORT" : "5000",
//      "REMOTO_REMOTE_USERNAME" : "workshop",
//      "REMOTO_REMOTE_PASSWORD" : "workshop",
//      "REMOTO_REMOTE_IGNORE_CERT" : "true",
//      "REMOTO_REMOTE_SECURITY" : "any",
//      "REMOTO_REMOTE_WIDTH" : "1366",
//      "REMOTO_REMOTE_HEIGHT" : "768",
//    }
//  }
//}

// Sandboxes subnet is for all the sandboxes that will be created
resource "azurerm_subnet" "sandboxes" {
  name                 = "sandboxes"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.2.0/24"]
}
resource "azurerm_network_interface" "sandboxes" {
  count               = var.remoto_sandbox_count
  name                = "remoto-sandboxes-nic-${count.index}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "sandboxes"
    subnet_id                     = azurerm_subnet.sandboxes.id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_private_dns_a_record" "sandbox" {
  name                = "sandbox"
  zone_name           = azurerm_private_dns_zone.this.name
  resource_group_name = azurerm_resource_group.this.name
  ttl                 = 300
  records             = azurerm_linux_virtual_machine.sandbox.*.private_ip_address
}
resource "azurerm_linux_virtual_machine" "sandbox" {
  count = var.remoto_sandbox_count

  name                = "remoto-sandbox-${count.index}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  size                = "Standard_B2s"
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.sandboxes[count.index].id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_pubkey
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    // Canonical:0001-com-ubuntu-server-focal:20_04-lts:20.04.202209200
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "20.04.202209200"
  }
}

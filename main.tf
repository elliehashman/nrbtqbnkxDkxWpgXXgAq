terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {}
}




resource "azurerm_resource_group" "GR-Ellie-TF" {
    name    = "GR-Ellie-TF"
    location = "East US"
  
}

resource "azurerm_virtual_network" "VN-Ellie-TF" {
    name    = "VN-Ellie-TF"
    address_space = ["10.21.0.0/16"]
    location = azurerm_resource_group.GR-Ellie-TF.location
    resource_group_name = azurerm_resource_group.GR-Ellie-TF.name
  
}

resource "azurerm_subnet" "Ellie-AGSubnet" {
    name = "Ellie-AGSubnet"
    virtual_network_name = azurerm_virtual_network.VN-Ellie-TF.name
    resource_group_name = azurerm_resource_group.GR-Ellie-TF.name
    address_prefixes = [ "10.21.0.0/24" ]
}
resource "azurerm_subnet" "Ellie-BackendSubnet" {
    name = "Ellie-myBackendSubnet"
    virtual_network_name = azurerm_virtual_network.VN-Ellie-TF.name
    resource_group_name = azurerm_resource_group.GR-Ellie-TF.name
    address_prefixes = [ "10.21.1.0/24" ]
}

resource "azurerm_public_ip" "IP-pub-TF" {
    name =  "IP-pub-TF"
    location = azurerm_resource_group.GR-Ellie-TF.location
    resource_group_name = azurerm_resource_group.GR-Ellie-TF.name
    allocation_method = "Static"
    sku = "Standard"

}

resource "azurerm_network_interface" "Interface_VM1-Ellie" {
    name = "Interface_VM1-Ellie"
    resource_group_name = azurerm_resource_group.GR-Ellie-TF.name
    location = azurerm_resource_group.GR-Ellie-TF.location
    ip_configuration {
      name = "Interface_VM1-Ellie-conf"
      subnet_id = azurerm_subnet.Ellie-BackendSubnet.id
      private_ip_address_allocation = "Dynamic"
    }
}

resource "azurerm_network_interface" "Interface_VM2-Ellie" {
    name = "Interface_VM2-Ellie"
    resource_group_name = azurerm_resource_group.GR-Ellie-TF.name
    location = azurerm_resource_group.GR-Ellie-TF.location
    ip_configuration {
      name = "Interface_VM2-Ellie-conf"
      subnet_id = azurerm_subnet.Ellie-BackendSubnet.id
      private_ip_address_allocation = "Dynamic"
    }
}


resource "azurerm_linux_virtual_machine" "VM1-Ellie-TF" {
    name =  "VM1-Ellie-TF"
    resource_group_name = azurerm_resource_group.GR-Ellie-TF.name
    location = azurerm_resource_group.GR-Ellie-TF.location
    size = "Standard_B1s"
    disable_password_authentication = false  
    admin_username = "azureuser"
    admin_password = "efrei@password7"
    os_disk {
      caching = "ReadWrite"
      storage_account_type = "Standard_LRS"
    }
    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }
    network_interface_ids = [azurerm_network_interface.Interface_VM1-Ellie.id]
  
}

resource "azurerm_linux_virtual_machine" "VM2-Ellie-TF" {
    name =  "VM2-Ellie-TF"
    resource_group_name = azurerm_resource_group.GR-Ellie-TF.name
    location = azurerm_resource_group.GR-Ellie-TF.location
    size = "Standard_B1s"
    disable_password_authentication = false  
    admin_username = "azureuser"
    admin_password = "efrei@password7"
    os_disk {
      caching = "ReadWrite"
      storage_account_type = "Standard_LRS"
    }
    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }
    network_interface_ids = [azurerm_network_interface.Interface_VM2-Ellie.id]
  
}


locals {
  backend_address_pool_name      = "${azurerm_virtual_network.VN-Ellie-TF.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.VN-Ellie-TF.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.VN-Ellie-TF.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.VN-Ellie-TF.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.VN-Ellie-TF.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.VN-Ellie-TF.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.VN-Ellie-TF.name}-rdrcfg"
}


resource "azurerm_application_gateway" "Ellie_AG" {
  name                = "Ellie_AG"
  resource_group_name = azurerm_resource_group.GR-Ellie-TF.name
  location            = azurerm_resource_group.GR-Ellie-TF.location

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
  }
  autoscale_configuration {
    min_capacity = 1
    max_capacity = 10 
  }

  waf_configuration{
    enabled = true
    firewall_mode = "Detection"
    rule_set_type = "OWASP"
    rule_set_version = 3.2
  }

  gateway_ip_configuration {
    name      = "Ellie-gateway-ip-configuration"
    subnet_id = azurerm_subnet.Ellie-AGSubnet.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.IP-pub-TF.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
    
    ip_addresses = [
      azurerm_network_interface.Interface_VM1-Ellie.private_ip_address,
      azurerm_network_interface.Interface_VM2-Ellie.private_ip_address
      ]
  }

  backend_http_settings {
    name                  = local.http_setting_name
    protocol              = "Http"
    port                  = 80
    cookie_based_affinity = "Disabled"
    request_timeout       = 20
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    priority                   = 10
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  
  
  }
}


resource "azurerm_virtual_machine_extension" "nginx_script1" {
  name                = "nginx_script1"
  virtual_machine_id  = azurerm_linux_virtual_machine.VM1-Ellie-TF.id
  publisher           = "Microsoft.Azure.Extensions"
  type                = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
      "fileUris": ["https://raw.githubusercontent.com/Azure/azure-docs-powershell-samples/master/application-gateway/iis/install_nginx.sh"],
      "commandToExecute": "./install_nginx.sh"
    }
SETTINGS
}

resource "azurerm_virtual_machine_extension" "nginx_script2" {
  name                = "nginx_script2"
  virtual_machine_id  = azurerm_linux_virtual_machine.VM2-Ellie-TF.id
  publisher           = "Microsoft.Azure.Extensions"
  type                = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
      "fileUris": ["https://raw.githubusercontent.com/Azure/azure-docs-powershell-samples/master/application-gateway/iis/install_nginx.sh"],
      "commandToExecute": "./install_nginx.sh"
    }
SETTINGS
}
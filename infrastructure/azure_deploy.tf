# locals {
#   safe_prefix  = replace(var.prefix, "-", "")
#   safe_postfix = replace(var.postfix, "-", "")
# }

# module "resource_group" {
#   source = "./modules/resource-group"

#   location = var.location
#   prefix   = var.prefix
#   postfix  = var.postfix
#   env      = var.environment
#   tags     = local.tags
# }

# module "container_registry" {
#   source = "./modules/container-registry"

#   rg_name  = module.resource_group.name
#   location = module.resource_group.location
#   prefix   = var.prefix
#   postfix  = var.postfix
#   env      = var.environment
#   tags     = local.tags
# }

# resource "random_password" "db_admin_password" {
#   length  = 16
#   special = true
# }

# resource "azurerm_postgresql_server" "db" {
#   name                = "psql-server-${local.safe_prefix}${local.safe_postfix}${var.environment}"
#   location            = module.resource_group.location
#   resource_group_name = module.resource_group.name

#   administrator_login          = var.db_admin_username
#   administrator_login_password = random_password.db_admin_password.result

#   # version                      = "11"
#   version                      = "12"
#   sku_name                     = "GP_Gen5_2"
#   storage_mb                   = 5120
#   backup_retention_days        = 7
#   geo_redundant_backup_enabled = false
#   auto_grow_enabled            = true

#   # public_network_access_enabled = false  # Disable public access
#   public_network_access_enabled = true  # Disable public access
#   ssl_enforcement_enabled       = true

#   tags = local.tags
# }

# resource "azurerm_postgresql_database" "db" {
#   name                = "backend_db"
#   resource_group_name = module.resource_group.name
#   server_name         = azurerm_postgresql_server.db.name
#   charset             = "UTF8"
#   collation           = "English_United States.1252"
# }

# resource "azurerm_container_app_environment" "aca-environment" {
#   name                       = "aca-environment-${local.safe_prefix}${local.safe_postfix}${var.environment}"
#   location                   = module.resource_group.location
#   resource_group_name        = module.resource_group.name
# }


# resource "azurerm_container_app" "backend" {
#   name                         = "backend-${local.safe_prefix}${local.safe_postfix}${var.environment}"
#   container_app_environment_id = azurerm_container_app_environment.aca-environment.id
#   resource_group_name          = module.resource_group.name
#   revision_mode                = "Single"

#   template {
#     container {
#       name   = "backend"
#       image  = "${module.container_registry.name}.azurecr.io/backend-${var.branch_name}@${var.image_digest}"
#       cpu    = 0.25
#       memory = "0.5Gi"

#       env {
#         name  = "DATABASE_HOST"
#         value = azurerm_postgresql_server.db.fqdn
#       }

#       env {
#         name  = "DATABASE_USER"
#         value = "${var.db_admin_username}@${azurerm_postgresql_server.db.name}"
#       }

#       env {
#         name  = "DATABASE_PASSWORD"
#         value = random_password.db_admin_password.result
#       }

#       env {
#         name  = "DATABASE_NAME"
#         value = azurerm_postgresql_database.db.name
#       }

#       env {
#         name  = "DATABASE_PORT"
#         value = "5432"
#       }

#       env {
#         name  = "PYTHONUNBUFFERED"
#         value = "1"
#       }

#       env {
#         name  = "IS_PROD"
#         value = "True"
#       }
#     }
#   }

#   secret {
#     name  = "container-registry-password"
#     value = module.container_registry.admin_password
#   }

#   registry {
#     server   = "${module.container_registry.name}.azurecr.io"
#     username = module.container_registry.admin_username
#     password_secret_name = "container-registry-password"
#   }

#   tags = local.tags
# }

# resource "azurerm_postgresql_firewall_rule" "allow_azure_ips" {
#   name                = "allow_azure_ips"
#   resource_group_name = module.resource_group.name
#   server_name         = azurerm_postgresql_server.db.name
#   start_ip_address    = "0.0.0.0"
#   end_ip_address      = "0.0.0.0"
# }








locals {
  safe_prefix  = replace(var.prefix, "-", "")
  safe_postfix = replace(var.postfix, "-", "")
}

module "resource_group" {
  source = "./modules/resource-group"
  location = var.location
  prefix   = var.prefix
  postfix  = var.postfix
  env      = var.environment
  tags     = local.tags
}

module "container_registry" {
  source = "./modules/container-registry"
  rg_name  = module.resource_group.name
  location = module.resource_group.location
  prefix   = var.prefix
  postfix  = var.postfix
  env      = var.environment
  tags     = local.tags
}


resource "azurerm_virtual_network" "vitual_network" {
  name                = "vnet-${local.safe_prefix}${local.safe_postfix}${var.environment}"
  address_space       = ["10.0.0.0/16"]
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
}


resource "azurerm_role_assignment" "acr_pull" {
  # scope                = azurerm_container_registry.container_registry.id
  scope                = module.container_registry.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.pgadmin.principal_id
}

resource "azurerm_role_assignment" "acr_push" {
  # scope                = azurerm_container_registry.container_registry.id
  scope                = module.container_registry.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.pgadmin.principal_id
}


resource "azurerm_subnet" "db" {
  name                 = "subnet-db-${local.safe_prefix}${local.safe_postfix}${var.environment}"
  resource_group_name  = module.resource_group.name
  virtual_network_name = azurerm_virtual_network.vitual_network.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "postgresqlDelegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_private_dns_zone" "db" {
  name                = "private.postgres.database.azure.com"
  resource_group_name = module.resource_group.name
}


resource "azurerm_private_dns_zone_virtual_network_link" "vnet_link" {
  name                  = "vnet-link-${local.safe_prefix}${local.safe_postfix}${var.environment}"
  private_dns_zone_name = azurerm_private_dns_zone.db.name
  resource_group_name   = module.resource_group.name
  virtual_network_id    = azurerm_virtual_network.vitual_network.id
}



resource "azurerm_postgresql_flexible_server" "db" {
  name                = "psql-flexible-server-${local.safe_prefix}${local.safe_postfix}${var.environment}"
  auto_grow_enabled   = true
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  delegated_subnet_id = azurerm_subnet.db.id
  private_dns_zone_id = azurerm_private_dns_zone.db.id
  sku_name            = "GP_Standard_D2s_v3"
  storage_mb          = 32768
  backup_retention_days  = 7
  version             = "12"

  public_network_access_enabled = false  # Disable public network access

  authentication {
    password_auth_enabled         = false
    active_directory_auth_enabled = true
    tenant_id                     = data.azurerm_client_config.current.tenant_id
  }

  lifecycle {
    ignore_changes = [
      zone,
      high_availability[0].standby_availability_zone
    ]
  }
}


resource "azurerm_postgresql_flexible_server_database" "db" {
  name       = "psql-flexible-database-${local.safe_prefix}${local.safe_postfix}${var.environment}"
  server_id  = azurerm_postgresql_flexible_server.db.id
  charset    = "UTF8"
  collation  = "en_US.utf8"
}

resource "azurerm_user_assigned_identity" "pgadmin" {
  name                = "pgadmin-identity"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "admin" {
  server_name         = azurerm_postgresql_flexible_server.db.name
  resource_group_name = module.resource_group.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = azurerm_user_assigned_identity.pgadmin.principal_id
  principal_name      = azurerm_user_assigned_identity.pgadmin.name
  principal_type      = "ServicePrincipal"
}

resource "azurerm_container_app_environment" "aca-environment" {
  name                       = "aca-environment-${local.safe_prefix}${local.safe_postfix}${var.environment}"
  location                   = module.resource_group.location
  resource_group_name        = module.resource_group.name
}

# resource "azurerm_container_app" "backend" {
#   name                         = "backend-${local.safe_prefix}${local.safe_postfix}${var.environment}"
#   container_app_environment_id = azurerm_container_app_environment.aca-environment.id
#   resource_group_name          = module.resource_group.name
#   revision_mode                = "Single"

#   template {
#     container {
#       name   = "backend"
#       image  = "${module.container_registry.name}.azurecr.io/backend-${var.branch_name}@${var.image_digest}"
#       cpu    = 0.25
#       memory = "0.5Gi"

#       env {
#         name  = "DB_USER"
#         value = azurerm_user_assigned_identity.pgadmin.name
#       }

#       env {
#         name  = "DB_FQDN"
#         value = azurerm_postgresql_flexible_server.db.fqdn
#       }

#       env {
#         name  = "DB_NAME"
#         value = "backend_db"
#       }

#       env {
#         name  = "AZURE_CLIENT_ID"
#         value = azurerm_user_assigned_identity.pgadmin.client_id
#       }
#     }
#   }

#   identity {
#     type         = "UserAssigned"
#     identity_ids = [azurerm_user_assigned_identity.pgadmin.id]
#   }

#   tags = local.tags
# }










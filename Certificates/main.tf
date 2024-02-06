terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.89.0"
    }
  }

}

provider "azurerm" {
  features {
    # key_vault {
    #   purge_soft_deleted_certificates_on_destroy = true
    #   recover_soft_deleted_certificates          = true
    # }
  }
}

# Required so that the tenant_id element can be dynamically added
data "azurerm_client_config" "current" {}

variable "certificate_name" {
  type    = string
  default = "myCertificate"
}

variable "subject_cn" {
  type    = string
  default = "example.com"
}

variable "root_object_id" {
  type    = string
  default = "Enter a valid user guid"
}

locals {
  kv_name = "the-keyv-testing"
  rg_name = "cert-testing"
  sku_name = "standard"
  location = "Australia Southeast"
}

resource "azurerm_key_vault" "the-keyv" {
  name = local.kv_name
  location = local.location
  resource_group_name = local.rg_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = local.sku_name

  # soft_delete_retention_days = 90
  # purge_protection_enabled   = true

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = ${var.root_object_id} # <<----- Can this be derived dynamically?

    key_permissions         = ["Create", "Get", "Delete", "List", "Update", "Import", "Backup", "Restore", "Recover"]
    secret_permissions      = ["Set", "Get", "Delete", "List", "Recover", "Backup", "Restore"]
    certificate_permissions = ["Create", "Delete", "Get", "List", "Purge", "Update", "ManageContacts", "GetIssuers", "ListIssuers", "SetIssuers", "DeleteIssuers"]

  }
}

resource "azurerm_key_vault_certificate" "cert-certificate" {
  name         = var.certificate_name
  key_vault_id = azurerm_key_vault.the-keyv.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_type   = "RSA"
      key_size   = 2048
      reuse_key  = false
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    x509_certificate_properties {
      # Adjust the subject, validity period, etc., as needed
      subject            = "CN=${var.subject_cn}"
      validity_in_months = 60

      key_usage = [
        "digitalSignature",
        "keyEncipherment",
        "cRLSign",
        "dataEncipherment",
        "keyAgreement",
        "keyCertSign"
      ]

      # serverAuth OID = 1.3.6.1.5.5.7.3.1
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]
    }
  }

  depends_on = [
    azurerm_key_vault.the-keyv,
  ]

}

# output "certificate_data" {
#   value = azurerm_key_vault_certificate.cert-certificate.certificate_data
# }

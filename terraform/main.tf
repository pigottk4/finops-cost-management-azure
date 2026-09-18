terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.primary_subscription_id
}

provider "azurerm" {
  alias           = "secondary"
  features {}
  subscription_id = var.secondary_subscription_id
}

# -----------------------------------------------------------------------------
# Management Group & Hierarchy
# -----------------------------------------------------------------------------
resource "azurerm_management_group" "finops_mg" {
  name         = "MG-FinOps"
  display_name = "MG-FinOps"
}

resource "azurerm_management_group_subscription_association" "primary_sub" {
  management_group_id = azurerm_management_group.finops_mg.id
  subscription_id     = "/subscriptions/${var.primary_subscription_id}"
}

resource "azurerm_management_group_subscription_association" "secondary_sub" {
  management_group_id = azurerm_management_group.finops_mg.id
  subscription_id     = "/subscriptions/${var.secondary_subscription_id}"
}

# -----------------------------------------------------------------------------
# Base Resources for Tagging Demonstration
# -----------------------------------------------------------------------------
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group
  location = var.location
  tags     = var.finops_tags
}

resource "random_id" "sa_name" {
  byte_length = 4
}

resource "azurerm_storage_account" "dummy_sa" {
  name                     = "safinops${random_id.sa_name.hex}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Granular tagging merging base tags with resource-specific tags
  tags = merge(var.finops_tags, {
    ResourceType = "ObjectStorage"
    Application  = "FinOpsDemonstration"
  })
}

# -----------------------------------------------------------------------------
# Azure Policy Definitions (Cost Control Guardrails)
# -----------------------------------------------------------------------------
resource "azurerm_policy_definition" "allowed_vm_skus" {
  name                = "policy-allowed-vm-skus"
  policy_type         = "Custom"
  mode                = "Indexed"
  display_name        = "Enforce Allowed Virtual Machine SKUs for Cost Control"
  management_group_id = azurerm_management_group.finops_mg.id

  metadata = <<METADATA
    {
      "category": "Cost Management"
    }
METADATA

  policy_rule = <<POLICY_RULE
    {
      "if": {
        "allOf": [
          {
            "field": "type",
            "equals": "Microsoft.Compute/virtualMachines"
          },
          {
            "not": {
              "field": "Microsoft.Compute/virtualMachines/sku.name",
              "in": "[parameters('listOfAllowedSKUs')]"
            }
          }
        ]
      },
      "then": {
        "effect": "deny"
      }
    }
POLICY_RULE

  parameters = <<PARAMETERS
    {
      "listOfAllowedSKUs": {
        "type": "Array",
        "metadata": {
          "description": "The list of size SKUs that can be specified for virtual machines.",
          "displayName": "Allowed Size SKUs"
        }
      }
    }
PARAMETERS
}

resource "azurerm_policy_definition" "allowed_storage_skus" {
  name                = "policy-allowed-storage-skus"
  policy_type         = "Custom"
  mode                = "Indexed"
  display_name        = "Enforce Allowed Storage Account SKUs for Cost Control"
  management_group_id = azurerm_management_group.finops_mg.id

  metadata = <<METADATA
    {
      "category": "Cost Management"
    }
METADATA

  policy_rule = <<POLICY_RULE
    {
      "if": {
        "allOf": [
          {
            "field": "type",
            "equals": "Microsoft.Storage/storageAccounts"
          },
          {
            "not": {
              "field": "Microsoft.Storage/storageAccounts/sku.name",
              "in": "[parameters('listOfAllowedSKUs')]"
            }
          }
        ]
      },
      "then": {
        "effect": "deny"
      }
    }
POLICY_RULE

  parameters = <<PARAMETERS
    {
      "listOfAllowedSKUs": {
        "type": "Array",
        "metadata": {
          "description": "The list of SKUs that can be specified for storage accounts.",
          "displayName": "Allowed SKUs"
        }
      }
    }
PARAMETERS
}

resource "azurerm_policy_definition" "require_tag" {
  name                = "policy-require-tag"
  policy_type         = "Custom"
  mode                = "Indexed"
  display_name        = "Require CostCenter tag on all resources"
  management_group_id = azurerm_management_group.finops_mg.id

  metadata = <<METADATA
    {
      "category": "Cost Management"
    }
METADATA

  policy_rule = <<POLICY_RULE
    {
      "if": {
        "field": "[concat('tags[', parameters('tagName'), ']')]",
        "exists": "false"
      },
      "then": {
        "effect": "deny"
      }
    }
POLICY_RULE

  parameters = <<PARAMETERS
    {
      "tagName": {
        "type": "String",
        "metadata": {
          "description": "Name of the tag, such as 'CostCenter'",
          "displayName": "Tag Name"
        }
      }
    }
PARAMETERS
}

# -----------------------------------------------------------------------------
# Azure Policy Assignments (At Management Group Scope)
# -----------------------------------------------------------------------------
resource "azurerm_management_group_policy_assignment" "assign_vm_skus" {
  name                 = "assign-vm-skus"
  management_group_id  = azurerm_management_group.finops_mg.id
  policy_definition_id = azurerm_policy_definition.allowed_vm_skus.id
  description          = "Assignment of Allowed VM SKUs"
  display_name         = "Assign Allowed VM SKUs"

  parameters = <<PARAMETERS
    {
      "listOfAllowedSKUs": {
        "value": ${jsonencode(var.allowed_vm_skus)}
      }
    }
PARAMETERS
}

resource "azurerm_management_group_policy_assignment" "assign_storage_skus" {
  name                 = "assign-storage-skus"
  management_group_id  = azurerm_management_group.finops_mg.id
  policy_definition_id = azurerm_policy_definition.allowed_storage_skus.id
  description          = "Assignment of Allowed Storage SKUs"
  display_name         = "Assign Allowed Storage SKUs"

  parameters = <<PARAMETERS
    {
      "listOfAllowedSKUs": {
        "value": ${jsonencode(var.allowed_storage_skus)}
      }
    }
PARAMETERS
}

resource "azurerm_management_group_policy_assignment" "assign_require_tag" {
  name                 = "assign-require-tag"
  management_group_id  = azurerm_management_group.finops_mg.id
  policy_definition_id = azurerm_policy_definition.require_tag.id
  description          = "Require CostCenter tag on resources"
  display_name         = "Assign Require Tag"

  parameters = <<PARAMETERS
    {
      "tagName": {
        "value": "CostCenter"
      }
    }
PARAMETERS
}

# -----------------------------------------------------------------------------
# Cost Alerts and Budgets
# -----------------------------------------------------------------------------
resource "azurerm_consumption_budget_management_group" "mg_budget" {
  name                = "budget-mg-finops"
  management_group_id = azurerm_management_group.finops_mg.id

  amount     = 1000
  time_grain = "Monthly"

  time_period {
    start_date = "2026-08-01T00:00:00Z"
    end_date   = "2027-08-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 50.0
    operator       = "GreaterThan"
    contact_emails = [var.alert_email_address]
  }

  notification {
    enabled        = true
    threshold      = 80.0
    operator       = "GreaterThan"
    contact_emails = [var.alert_email_address]
  }

  notification {
    enabled        = true
    threshold      = 100.0
    operator       = "GreaterThan"
    contact_emails = [var.alert_email_address]
  }
}

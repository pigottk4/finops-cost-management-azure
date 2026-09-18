variable "primary_subscription_id" {
  type        = string
  description = "The ID of the primary Azure Subscription"
}

variable "secondary_subscription_id" {
  type        = string
  description = "The ID of the secondary Azure Subscription"
}

variable "resource_group" {
  type        = string
  description = "The name of the Resource Group for the FinOps project"
}

variable "location" {
  type        = string
  description = "The Azure Region to deploy resources into"
}

variable "alert_email_address" {
  type        = string
  description = "The email address that will receive the Azure Budget alerts"
}

variable "allowed_vm_skus" {
  type        = list(string)
  description = "The list of permitted Virtual Machine sizes"
  default     = ["Standard_B2s", "Standard_D2s_v3"]
}

variable "allowed_storage_skus" {
  type        = list(string)
  description = "The list of permitted Storage Account SKUs"
  default     = ["Standard_LRS"]
}

variable "finops_tags" {
  type        = map(string)
  description = "Standard FinOps tags applied to the Management Group and Resource Group"
  default = {
    CostCenter  = "1049-Engineering"
    Department  = "Cloud Platform"
    Environment = "Production"
    Owner       = "FinOps-Team"
  }
}

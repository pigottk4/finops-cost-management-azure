# Sample outputs from terraform apply.
# Actual outputs might vary based on resource naming.
#
# budget_name = "budget-mg-finops"
# management_group_id = "/providers/Microsoft.Management/managementGroups/MG-FinOps"
# policy_assignment_require_tag_id = "/providers/Microsoft.Management/managementGroups/MG-FinOps/providers/Microsoft.Authorization/policyAssignments/assign-require-tag"
# policy_assignment_storage_skus_id = "/providers/Microsoft.Management/managementGroups/MG-FinOps/providers/Microsoft.Authorization/policyAssignments/assign-storage-skus"
# policy_assignment_vm_skus_id = "/providers/Microsoft.Management/managementGroups/MG-FinOps/providers/Microsoft.Authorization/policyAssignments/assign-vm-skus"
# resource_group_name = "rg-azure-finops"

output "management_group_id" {
  value       = azurerm_management_group.finops_mg.id
  description = "The ID of the deployed Management Group"
}

output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "The name of the Base Resource Group"
}

output "budget_name" {
  value       = azurerm_consumption_budget_management_group.mg_budget.name
  description = "The name of the Management Group Consumption Budget"
}

output "policy_assignment_vm_skus_id" {
  value       = azurerm_management_group_policy_assignment.assign_vm_skus.id
  description = "The ID of the VM SKU Policy Assignment"
}

output "policy_assignment_storage_skus_id" {
  value       = azurerm_management_group_policy_assignment.assign_storage_skus.id
  description = "The ID of the Storage SKU Policy Assignment"
}

output "policy_assignment_require_tag_id" {
  value       = azurerm_management_group_policy_assignment.assign_require_tag.id
  description = "The ID of the Require Tag Policy Assignment"
}

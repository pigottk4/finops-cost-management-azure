# <span style="color:red">🔧 8. Troubleshooting Guide</span> <span style="font-size: 14px; font-weight: normal;">[⬆️ Back to TOC](README.md#toc)</span>

This guide covers common errors encountered when configuring and managing Azure FinOps controls (Policies and Budgets) using Terraform.

### 🌐 8.1 Azure Policy Deny Errors

### 8.1.1 ❌ Error: `Deployment explicitly denied by Azure Policy (VM SKU)`
```text
Error: creating Linux Virtual Machine "vm-expensive-test" ... unexpected status 403 (403 Forbidden) with error: RequestDisallowedByPolicy: Resource 'vm-expensive-test' was disallowed by policy. Policy identifiers: '[{"policyAssignment":{"name":"assign-vm-skus","id":"/providers/Microsoft.Management/managementGroups/MG-FinOps/providers/Microsoft.Authorization/policyAssignments/assign-vm-skus"}}]'.
```
**Cause:** 
You attempted to deploy a Virtual Machine size that is not included in the `allowed_vm_skus` variable list. The Azure Policy guardrail intercepted the request and blocked it to prevent cost overruns.

**Solution:** 
Adjust your Terraform code or CLI command to use a cheaper, permitted VM size (e.g., `Standard_B2s`), or update the policy parameters in Terraform to authorize the expensive SKU.

**Before (Code causing the error in terminal):**
```bash
az vm create \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --name "vm-expensive-test" \
  --image Ubuntu2204 \
  --size "Standard_E2s_v3" \
  --generate-ssh-keys
```

**After (Corrected code):**
```bash
az vm create \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --name "vm-cheap-test" \
  --image Ubuntu2204 \
  --size "Standard_B2s" \
  --generate-ssh-keys
```

### 8.1.2 ❌ Error: `Deployment explicitly denied by Azure Policy (Missing Tag)`
```text
Error: creating Storage Account "satagtest123" ... unexpected status 403 (403 Forbidden) with error: RequestDisallowedByPolicy: Resource 'satagtest123' was disallowed by policy. Policy identifiers: '[{"policyAssignment":{"name":"assign-require-tag","id":"/providers/Microsoft.Management/managementGroups/MG-FinOps/providers/Microsoft.Authorization/policyAssignments/assign-require-tag"}}]'.
```
**Cause:** 
You attempted to deploy a resource without attaching the mandatory `CostCenter` tag. The FinOps policy blocked the deployment to ensure accurate cost allocation.

**Solution:** 
Ensure you pass the `--tags` parameter with the `CostCenter` key when deploying via CLI, or include the tag block in your Terraform resource.

**Before (Code causing the error in terminal):**
```bash
az storage account create \
  --name "satagtest${RANDOM}" \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --sku Standard_LRS
```

**After (Corrected code):**
```bash
az storage account create \
  --name "satagtest${RANDOM}" \
  --resource-group ${RESOURCE_GROUP_NAME} \
  --sku Standard_LRS \
  --tags CostCenter=1049-Engineering
```

### 🌐 8.2 Authorization & Management Group Errors

### 8.2.1 ❌ Error: `Insufficient Privileges to create Management Group`
```text
Error: creating Management Group "MG-FinOps": managementgroups.ManagementGroupsClient#CreateOrUpdate: Failure responding to request: StatusCode=403 -- Original Error: autorest/azure: Service returned an error. Status=403 Code="AuthorizationFailed" Message="The client 'user@example.com' with object id 'xyz' does not have authorization to perform action 'Microsoft.Management/managementGroups/write' over scope '/providers/Microsoft.Management/managementGroups/MG-FinOps'."
```
**Cause:** 
Your user account does not have the `Management Group Contributor` role at the Tenant Root Group level, which is required to deploy new Management Groups.

**Solution:** 
You must contact your Azure Tenant Administrator to grant you the necessary permissions, or deploy the FinOps controls (Policies/Budgets) at the Subscription level instead.

### 🌐 8.3 Terraform Syntax & Resource Scoping Errors

### 8.3.1 ❌ Error: `Unsupported argument 'contact_groups' in Management Group Budget`
```text
Error: Missing required argument
  on main.tf line 278, in resource "azurerm_consumption_budget_management_group" "mg_budget":
 The argument "contact_emails" is required, but no definition was found.

Error: Unsupported argument
  on main.tf line 282, in resource "azurerm_consumption_budget_management_group" "mg_budget":
 An argument named "contact_groups" is not expected here.
```
**Cause:** 
Unlike standard Subscription budgets, the `azurerm_consumption_budget_management_group` resource in Terraform does not support linking out to Azure Monitor Action Groups via the `contact_groups` argument.

**Solution:** 
Remove the unsupported `contact_groups` argument and the `azurerm_monitor_action_group` resource entirely. Instead, pass the email addresses directly into the budget using the `contact_emails` argument.

**Before (Code causing the error in `terraform/main.tf`):**
```hcl
  notification {
    enabled        = true
    threshold      = 50.0
    operator       = "GreaterThan"
    contact_groups = [azurerm_monitor_action_group.budget_ag.id]
  }
```

**After (Corrected code in `terraform/main.tf`):**
```hcl
  notification {
    enabled        = true
    threshold      = 50.0
    operator       = "GreaterThan"
    contact_emails = [var.alert_email_address]
  }
```

### 8.3.2 ❌ Error: `Policy Assignment Out of Scope`
```text
Error: creating Scoped Policy Assignment (Scope: "/providers/Microsoft.Management/managementGroups/MG-FinOps"
Policy Assignment Name: "assign-vm-skus"): unexpected status 400 (400 Bad Request) with error: InvalidCreatePolicyAssignmentRequest: The policy definition specified in policy assignment 'assign-vm-skus' is out of scope. Policy definitions should be specified only at or above the policy assignment scope.
```
**Cause:** 
By default, Terraform creates `azurerm_policy_definition` resources at the Subscription scope. However, you are attempting to assign the policy at the Management Group scope via `azurerm_management_group_policy_assignment`. Azure requires the definition to be saved at or above the level it is assigned.

**Solution:** 
Add the `management_group_id` argument to the `azurerm_policy_definition` block to save the definition at the Management Group level.

**Before (Code causing the error in `terraform/main.tf`):**
```hcl
resource "azurerm_policy_definition" "allowed_vm_skus" {
  name         = "policy-allowed-vm-skus"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Enforce Allowed Virtual Machine SKUs for Cost Control"
```

**After (Corrected code in `terraform/main.tf`):**
```hcl
resource "azurerm_policy_definition" "allowed_vm_skus" {
  name                = "policy-allowed-vm-skus"
  policy_type         = "Custom"
  mode                = "Indexed"
  display_name        = "Enforce Allowed Virtual Machine SKUs for Cost Control"
  management_group_id = azurerm_management_group.finops_mg.id
```

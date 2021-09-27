# Terraform Template Module

&nbsp;
## Table of Contents
- [Style Guide](#style-guide)
    - [General](#general)
    - [Variables](#variables)
    - [Outputs](#outputs)
    - [Resources & Data](#resources-and-data)
    - [Azure](#azure)
- [Code Snippets](#code-snippets)
    - [Azure](#azure)
        - [Resource Group](#resource-group)
        - [Private Endpoint](#private-endpoint)
        - [Diagnostic Settings](#diagnostic-settings)
- [Workarounds](#workarounds)
&nbsp;
## Style Guide
### General
* Every module has a terraform configuration like the following.
```hcl
terraform {
  experiments      = [module_variable_optional_attrs]
  required_version = ">=1.0.0"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">=3.1.0"
    }
  }
}
```
****
### Variables
* Every variable has description, tive and type set. If the pointed attribute is optional the default is null. Special case if block is required. See the bullet point for Dynamic blocks.
```hcl
variable "enabled" {
  description = "Enables the module to create any resources."
  type        = bool
  default     = true
  sensitive   = false
}
```
****
### Outputs
* Every attribute for resources is defined as output.
```hcl
output "name" {
  description = "The Name which should be used for this Resource Group. Changing this forces a new Resource Group to be created."
  value       = azurerm_resource_group.main[*].name
}
```
****
### Resources & Data
* Every argument for resources is defined and controlled via variables/dependencies.
* Every resource and data block has the url to the registry reference as comment.
```hcl
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "main" {

  count = var.enabled ? 1 : 0

  name     = var.naming
  location = var.location
  tags = var.tags
}
```
* Every resource or data block is controlled via a 'count' statement.
```hcl
  count = var.enabled ? 1 : 0
```
****
### Azure
* Every main resource is named like the following.
```hcl
  name = "resource-type-${var.naming}-${one(random_id.main[*].hex)}"
```
* Subresource like subnets are named like the following.
```hcl
  name = "resource-type-${parentresourcename}-${sum([count.index, 1])}"
```
&nbsp;
## Code Snippets
### Azure
*****
#### Resource Group
We use a data block to import the resource group, that is going to be used as deployment target. However you can use more data blocks to import other resource groups too.
```hcl
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group
data "azurerm_resource_group" "main" {

  count = var.enabled ? 1 : 0

  name = var.resourceGroupName

}
```
If the resource you want to build could be in a different resource group add a block like below. Even if your maybe build the same dependencie twice it's much easier to understand what happens and to debug.
```hcl
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group
data "azurerm_resource_group" "log_analytics_workspace" {

  count = var.enabled && length(tolist([var.logAnalyticsWorkspaceName])) != 0 ? 1 : 0

  name = var.logAnalyticsWorkspaceResourceGroupName != null ? var.logAnalyticsWorkspaceResourceGroupName : var.resourceGroupName

}
```
*****
#### Private Endpoint
Endpoints are defined through a list of objects. If this list is empty no private endpoints are going to be build.
```hcl
variable "privateEndpoints" {
  description = "Specify private endpoints for the IotHub."
  type        = list(object({
    resource_group_name  = optional(string)
    virtual_network_name = string
    subnet_name          = string
  }))
  default     = []
  sensitive   = false
}
```
To define the endpoints we need to get the subnets. First we check the object if resource groups are given for all private endpoints. If not we append the **main** resource group to the object. We pass a list of objects like **var.privateEndpoints** as local value with all attributes set.
```hcl
locals {
  result = [
    for endpoints in var.privateEndpoints[*] : {
      resource_group_name  = endpoints.resource_group_name == null ? one(data.azurerm_resource_group.main[*].name) : endpoints.resource_group_name
      virtual_network_name = endpoints.virtual_network_name
      subnet_name          = endpoints.subnet_name
    }
  ]
}
```
Get all resource groups from the defined **local.result**.
```hcl
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group
data "azurerm_resource_group" "private_endpoint" {

  count = var.enabled && var.privateEndpoints != null ? length(local.result) : 0

  name = lookup(element(local.result, count.index), "resource_group_name")
}
```
Get all virutal networks from the defined **local.result**.
```hcl
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network
data "azurerm_virtual_network" "private_endpoint" {

  count = var.enabled && var.privateEndpoints != null ? length(local.result) : 0

  name                = lookup(element(local.result, count.index), "virtual_network_name")
  resource_group_name = data.azurerm_resource_group.private_endpoint[count.index].name
}
```
Get all subnets from the defined **local.result**.
```hcl
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet
data "azurerm_subnet" "private_endpoint" {

  count = var.enabled && var.privateEndpoints != null ? length(var.privateEndpoints) : 0

  name                 = lookup(element(local.result, count.index), "subnet_name")
  resource_group_name  = data.azurerm_resource_group.private_endpoint[count.index].name
  virtual_network_name = data.azurerm_virtual_network.private_endpoint[count.index].name
}
```
Build all private endpoints. You need to specify the subresource name for every resource type that needs a private endpoint. If you configure private endpoints for different resource types in your module: Remember that you need to add everything again with different Terraform-Object names.
```hcl
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint
resource "azurerm_private_endpoint" "main" {

  count = var.enabled && var.privateEndpoints != null ? length(var.privateEndpoints) : 0

  name                = "private-endpoint-${one(azurerm_iothub.main[*].name)}-${sum([count.index, 1])}"
  resource_group_name = one(data.azurerm_resource_group.main[*].name)
  location            = one(data.azurerm_resource_group.main[*].location)
  subnet_id           = data.azurerm_subnet.private_endpoint[count.index].id
  tags                = var.tags

  private_service_connection {
    name                              = "private-endpoint-${one(azurerm_iothub.main[*].name)}-${sum([count.index, 1])}"
    private_connection_resource_id    = one(azurerm_iothub.main[*].id)
    is_manual_connection              = false
    subresource_names                 = ["default"]
  }

  lifecycle {
    ignore_changes = [
      private_dns_zone_group
    ]
  }
}
```
*****
#### Diagnostic Settings
Declare the variable in your module to enable or disable Log Analytics.
```hcl
variable "logAnalyticsEnabled" {
  description = "Enable or disable Log Analytics for your resources."
  type        = bool
  default     = false
  sensitive   = false
}
```
Declare variables to reference your Log Analytics workspace.
```hcl
variable "logAnalyticsWorkspaceName" {
  description = "The name of your Log Analytics workspace."
  type        = string
  default     = null
  sensitive   = false
}

variable "logAnalyticsWorkspaceResourceGroup" {
  description = "The name of your the resource group where your Log Analytics workspace is deployed."
  type        = string
  default     = null
  sensitive  = false
}
```
Configure your diagnostic Settings. Used on all resources in the module.
```hcl
variable "logRetentionDays" {
  description = "Number of days to retain the logs."
  type        = number
  default     = 30
  sensitive   = false
}

variable "metricRetentionDays" {
  description = "Number of days to retain the metrics."
  type        = number
  default     = 30
  sensitive   = false
}
```
Import the Log Analytics workspace with data blocks.
```hcl
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group
data "azurerm_resource_group" "log_analytics" {

  count = var.enabled ? 1 : 0

  name = var.logAnalyticsWorkspaceResourceGroup == null ? one(data.azurerm_resource_group.main[*].name) : var.logAnalyticsWorkspaceResourceGroup 
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/log_analytics_workspace
data "azurerm_log_analytics_workspace" "main" {

  count = var.enabled && var.logAnalyticsEnabled ? 1 : 0

  name                = var.logAnalyticsWorkspaceName
  resource_group_name = one(data.azurerm_resource_group.log_analytics[*].name)
}
```
Append this for every resource type you use in your module.
```hcl
module "azure-diagnostics-settings" {

  source  = "app.terraform.io/e113/azure-diagnostics-settings/module"
  version = "1.1.0"

  enabled             = var.logAnalyticsEnabled

  resourceGroupName   = one(data.azurerm_resource_group.main[*].name)
  naming              = var.naming
  logRetentionDays    = var.logRetentionDays
  metricRetentionDays = var.metricRetentionDays

  logAnalyticsWorkspaceName          = one(data.azurerm_log_analytics_workspace.main[*].name)
  logAnalyticsWorkspaceResourceGroup = one(data.azurerm_resource_group.log_workspace[*].name)

  resourceID = azuererm_example.example[*].id
}
```
## Workarounds
List of some workarounds to make your code work.
### Target error
Sometimes Terraform is throwing an error when working with inherited dependencies.  
&nbsp;  
**Error:**
```
The "count" value depends on resource attributes that cannot be determined
until apply, so Terraform cannot predict how many instances will be
reated. To work around this, use the -target argument to first apply only
the resources that the count depends on.
```
**Fix:**
```hcl
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group
data "azurerm_resource_group" "log_analytics_workspace" {

  count = var.enabled && length(tolist([var.logAnalyticsWorkspaceName])) != 0 ? 1 : 0

  name = var.logAnalyticsWorkspaceResourceGroupName != null ? var.logAnalyticsWorkspaceResourceGroupName : var.resourceGroupName

}
```
You need to add the variable name you count on to a list and then check the length of the list. After that Terraform itself doens't know the name is inherited. In order to check this use "terraform graph -draw-cycles".
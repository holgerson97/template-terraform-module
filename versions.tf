terraform {
  experiments      = [module_variable_optional_attrs]
  required_version = ">=1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=2.77.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">=3.1.0"
    }
  }
}

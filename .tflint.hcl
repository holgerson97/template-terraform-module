plugin "azurerm" {
    enabled = true
    version = "0.10.0"
    source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
plugin "google" {
    enabled = true
    version = "0.9.0"
    source  = "github.com/terraform-linters/tflint-ruleset-google"
}
plugin "aws" {
    enabled = true
    version = "0.4.1"
    source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
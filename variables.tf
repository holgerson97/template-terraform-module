#################### General ####################
variable "enabled" {
  description = "Enables the module to create any resources."
  type        = bool
  default     = true
  sensitive   = false
}

variable "naming" {
  description = "Naming conventions applied on resources deployed by this module."
  type        = string
  default     = "default"
  sensitive   = false
}

variable "tags" {
  description = "Tags applied on all resources created by this module."
  type        = map(any)
  default     = null
  sensitive   = false
}

################## Dependencies #################
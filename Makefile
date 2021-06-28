GOVERSION		 ?= $(shell git describe --tags --always --dirty --match=v* 2> /dev/null || cat $(PWD)/.version 2> /dev/null || echo v0)
GOPACKAGES		 ?= $(shell go list ./...)
GOFILES		     ?= $(shell find . -type f -name '*.go' -not -path "./vendor/*")
TERRAFORMVERSION ?= $(shell terraform version)

.ONESHELL: #
.DEFAULT: help

.PHONY: help
help:
	@echo 'Makefile for "Terraform Modules"'
	@echo ''
	@echo '  env                - Displays useful environment variables for golang and Terraform.'
	@echo '  go-fmt             - Formats your golang code.'‚
	@echo '  go-vet             - Checks your golang code for broken packages.'
	@echo '  go-test            - Runs all terratests.'
	@echo '  go-all             - Runs all golang commands from this Makefile.'
	@echo '  terra-init         - Runs Terraform init in "examples" folder.'
	@echo '  terra-fmt          - Fomtats your Terraform code.'
	@echo '  terra-lint         - Lints your Terraform code.'
	@echo '  terra-validate     - Checks if your Terraform configuration is valid.'
	@echo '  terra-build        - Checks if your module can be build succesfully.'
	@echo '  terra-all          - Runs all terra commands from this Makefile.'
	@echo '  clean              - Clean all temporary files.'


.PHONY: env
env:  ## Print env vars
	echo $(GOVERSION)
	echo $(GOPACKAGES)
	echo $(GOVERSION)
	echo $(TERRAFORMVERSION)

.PHONY: go-fmt
go-fmt:  ## format the go source files
	go fmt ./...
	goimports -w $(GOFILES)

.PHONY: go-vet
go-vet:  ## run go vet on the source files
	go vet ./...

.PHONY: go-test
go-test:
	cd teratests/ && go test -v -timeout 60m

.PHONY: go-all
go-all: go-fmt go-vet go-test

.PHONY: terra-init
terra-init:
	cd examples/
	terraform init

.PHONY: terra-fmt
terra-fmt:  ## format terrafrom source files
	terraform fmt -recursive

.PHONY: terra-lint
terra-lint: ## lint terraform source files
	tflint .
	tflint examples/

.PHONY: terra-validate
terra-validate: ## valdiate terraform configuration
	cd examples/
	terraform init
	terraform validate

.PHONY: terra-build
terra-build: ## Init, Apply and Destroy Terraform configuration
	cd examples
	terraform init
	terraform apply --auto-approve
	terraform destroy --auto-approve

.PHONY: terra-all
terra-all: terrafmt terralint terravalidate terra-build

.PHONY: clean
clean:
	go clean
	find -name "*hcl" -delete
	find -type d -name ".terraform" -exec rm -rf {} +
	find -name "*tfstate" -delete
	find -name "*tfstate.backup" -delete
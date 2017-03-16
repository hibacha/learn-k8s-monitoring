SHELL = bash

CI_BUILD_NUMBER ?= $(USER)-snapshot
VERSION ?= $(CI_BUILD_NUMBER)

PUBLISH_TAG := "mup.cr/training/meetmon:$(VERSION)"

CLUSTER ?= training-sandbox
ZONE ?= us-east1-b
PROJECT ?= meetup-dev

DATE=$(shell date +%Y-%m-%dT%H_%M_%S)
ENDPOINT_REVISION=2017-03-15r0

NAMESPACE ?= $(USER)

help:
	@echo Public targets:
	@grep -E '^[^_][^_][a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo "Private targets: (use at own risk)"
	@grep -E '^__[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[35m%-20s\033[0m %s\n", $$1, $$2}'

__package: ## Creates the artifact only.
	docker build -t $(PUBLISH_TAG) .

package: __package __component-test ## Create artifact and run component tests.

__component-test: ## Run component-test only.
	$(PWD)/component/test-runner.sh $(PUBLISH_TAG)

publish: package ## Invokes package & component-test, then pushes to registry.
	docker push $(PUBLISH_TAG)

deploy-endpoint:
	@mkdir -p target
	@NAMESPACE=$(NAMESPACE) \
		PROJECT=$(PROJECT) \
		envtpl < infra/openapi.yaml > target/openapi.yaml
	gcloud service-management deploy --project $(PROJECT) target/openapi.yaml

deploy: ## Deploy project to existing kubectl context.
	@NAMESPACE=$(NAMESPACE) \
		envtpl < infra/ns.yaml | kubectl apply -f -
	@NAMESPACE=$(NAMESPACE) \
		envtpl < infra/meetmon-svc.yaml | kubectl apply -f -
	@NAMESPACE=$(NAMESPACE) \
		PUBLISH_TAG=$(PUBLISH_TAG) \
		DATE=$(DATE) \
		PROJECT=$(PROJECT) \
		ENDPOINT_REVISION=$(ENDPOINT_REVISION) \
		envtpl < infra/meetmon-dply.yaml | kubectl apply -f -

publish-tag: ## Display the build's publishing tag.
	@echo $(PUBLISH_TAG)

set-ns: ## Set namespace for current kubectl context.
	kubectl config set-context $$(kubectl config current-context) \
		--namespace $(NAMESPACE)

get-endpoint: ## Print the endpoint for our service.
	@echo "http://$$(kubectl get svc webserver --namespace $(NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[*].ip}')"

get-credentials: ## Set kubectl to our training cluster.
	gcloud container clusters get-credentials \
		--project $(PROJECT) \
		--zone $(ZONE) \
		$(CLUSTER)

prep: ## Verify dependencies are installed for course.
	@echo "=== Checking gcloud"
	@echo
	@gcloud version
	@echo
	@echo "=== Checking kubectl"
	@echo
	@kubectl version
	@echo
	@echo "=== Checking docker"
	@echo
	@docker --version
	@docker pull hello-world
	@docker run hello-world
	@echo
	@echo "=== Checking envtpl"
	@echo
	@type envtpl || (echo; echo "envtpl not found, check PREP.md for install details."; echo; false)
	@echo
	@echo "=== Checking siege"
	@echo
	@siege --version || (echo; echo "Siege not found, check PREP.md for install details."; echo; false)
	@echo
	@echo "=== You're ready for this course!"
	@echo

#-*- mode: makefile; -*-

DOCKERHUB_TOKEN ?= $(shell cat ~/.ssh/dockerhub-amazon-api.token)
DOCKERHUB_USER  ?= $(shell id -nu)
REPO            ?= $(DOCKERHUB_USER)/amazon-api

DOCKERFILE_DOCKERHUB = Dockerfile.dockerhub

.PHONY: amazon-api-image
amazon-api-image: $(TARBALL) $(DOCKERFILE_DOCKERHUB)
	docker build \
		-f $(DOCKERFILE_DOCKERHUB) \
		--build-arg AMAZON_API_VERSION=$(VERSION) \
		-t $(REPO):$(VERSION) \
		-t $(REPO):latest \
		.

.PHONY: publish-image
publish-image: 
	$(NO_ECHO)printf '%s\n' "$(DOCKERHUB_TOKEN)" | \
	docker login -u $(DOCKERHUB_USER) --password-stdin
	docker push $(REPO):$(VERSION)
	docker push $(REPO):latest

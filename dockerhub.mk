#-*- mode: makefile; -*-

DOCKERHUB_TOKEN ?= $(shell cat ~/.ssh/dockerhub-amazon-api.token)
DOCKERHUB_USER  ?= $(shell id -nu)
REPO            ?= $(DOCKERHUB_USER)/amazon-api

DOCKERFILE_DOCKERHUB = Dockerfile.dockerhub

.PHONY: amazon-api-image
amazon-api-image: $(DOCKERFILE_DOCKERHUB)
	printf '%s\n' "$(DOCKERHUB_TOKEN)" | \
		docker login -u $(DOCKERHUB_USER) --password-stdin
	docker build -f $< . \
		-t $(REPO):$(VERSION) \
		-t $(REPO):latest
	docker push $(REPO):$(VERSION)
	docker push $(REPO):latest

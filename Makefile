TAG ?=v$(shell date +%m%d%Y)-$(shell git rev-parse --short HEAD)
REGISTRY ?= ss104301

IMAGE = ${REGISTRY}/kubemark-performance-tests-on-azure

.PHONY: run
run:
	./automation/main.sh

.PHONY: build-kubemark-image
build-kubemark-image:
	./scripts/build-kubemark.sh

.PHONY: push-kubemark-image
push-kubemark-image:
	sudo docker tag staging-k8s.gcr.io/kubemark:latest ${REGISTRY}/kubemark:${TAG}
	sudo docker push ${REGISTRY}/kubemark:${TAG}

.PHONY: build
build:
	sudo docker build -t ${IMAGE}:${TAG} .

.PHONY: push
push:
	sudo docker push ${IMAGE}:${TAG}
	sudo docker tag ${IMAGE}:${TAG} ${IMAGE}:latest
	sudo docker push ${IMAGE}:latest

.PHONY: release
release: build push

.DELETE_ON_ERROR:

.SHELLFLAGS := -e -u

.PHONY: run
run:
	./automation/main.sh

.PHONY: build-kubemark-image
build-kubemark-image:
	./scripts/build-kubemark-.sh

.PHONY: push-kubemark-image
push-kubemark-image:
	docker tag staging-k8s.gcr.io/kubemark:latest ${REGISTRY}/kubemark:${TAG}
	docker push ${REGISTRY}/kubemark:${TAG}

TAG?=latest
NAMESPACE?=functions
.PHONY: build

build:
	./build.sh $(TAG)

charts:
	cd chart && helm package kafka-connector/
	mv chart/*.tgz docs/
	helm repo index docs --url https://openfaas-incubator.github.io/kafka-connector/ --merge ./docs/index.yaml

ci-armhf-build:
	./build.sh $(TAG)

ci-armhf-push:
	./build.sh $(TAG)

push:
	./push.sh $(TAG)




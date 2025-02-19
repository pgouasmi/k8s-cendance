GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

all: rm-token up ssh-server

install-deps:
	@echo "${YELLOW}Installing dependencies...${NC}"

	@echo "${YELLOW}Installing kind...${NC}"
	@if [ $$(uname -m) = x86_64 ]; then \
		curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64; \
	fi
	chmod +x ./kind
	@echo "${GREEN}kind installed${NC}"

	@echo "${YELLOW}Installing kubectl...${NC}"
	curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
	chmod +x ./kubectl
	@echo "${GREEN}kubectl installed${NC}"

	@echo "${GREEN}Dependencies installed${NC}"

setup-kind-cluster:
	@echo "${YELLOW}Setting up the kind cluster${NC}"
	./kind create cluster --config kind-config.yml
	@echo "${GREEN}Kind cluster setup${NC}"

down:
	@echo "${YELLOW}Turning off the VM..${NC}."
	@vagrant halt
	@echo "${GREEN}VM turned off${NC}"

clean: rm-token
	@echo "${YELLOW}Cleaning up the VMs...${NC}"
	@vagrant destroy -f
	@echo "${GREEN}VMs destroyed${NC}"

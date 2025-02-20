GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

all: install-deps setup-kind-cluster setup-ingress setup-ssl setup-postgres-credentials setup-services wait-for-services display-url


help:
	@echo "${GREEN}Kubernetes Local Environment Makefile Help${NC}"
	@echo ""
	@echo "${YELLOW}Available commands:${NC}"
	@echo ""
	@echo "${GREEN}make all${NC}             - Set up complete environment:"
	@echo "                    • Install dependencies (kind, kubectl)"
	@echo "                    • Set up kind cluster"
	@echo "                    • Configure ingress controller"
	@echo "                    • Set up SSL certificates" 
	@echo "                    • Configure PostgreSQL credentials"
	@echo "                    • Deploy all services"
	@echo "                    • Display access URL"
	@echo ""
	@echo "${GREEN}make down${NC}            - Pause the kind cluster:"
	@echo "                    • Pause the kind-control-plane container"
	@echo "                    • Preserve all configurations and data"
	@echo ""
	@echo "${GREEN}make boot${NC}            - Resume a paused or stopped cluster"
	@echo ""
	@echo "${GREEN}make clean${NC}           - Remove the kind cluster:"
	@echo "                    • Execute 'down' first"
	@echo "                    • Delete the kind cluster"
	@echo "                    • Keep installed binaries"
	@echo ""
	@echo "${GREEN}make fclean${NC}          - Complete cleanup:"
	@echo "                    • Execute 'clean' first"
	@echo "                    • Remove all installed binaries (kind, kubectl)"
	@echo "                    • Return environment to initial state"
	@echo ""
	@echo "${GREEN}make re${NC}              - Rebuild environment from scratch (fclean + all)"
	@echo ""
	@echo "${YELLOW}Additional commands:${NC}"
	@echo "${GREEN}make install-deps${NC}    - Install required dependencies"
	@echo "${GREEN}make setup-kind-cluster${NC} - Create and configure the kind cluster"
	@echo "${GREEN}make setup-ingress${NC}   - Install and configure nginx ingress"
	@echo "${GREEN}make setup-ssl${NC}       - Configure SSL certificates" 
	@echo "${GREEN}make setup-services${NC}  - Deploy all application services"
	@echo ""
	@echo "${YELLOW}Access URL:${NC} https://localhost:7777 (works best with Google Chrome)"
	@echo ""
	

install-deps:
	@echo "${YELLOW}Installing dependencies...${NC}"

	@if [ ! -f ./kind ] || [ ! -x ./kind ]; then \
		echo "${YELLOW}Installing kind...${NC}"; \
		if [ $$(uname -m) = x86_64 ]; then \
			curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64; \
		fi; \
		chmod +x ./kind; \
		echo "${GREEN}kind installed${NC}"; \
	else \
		echo "${GREEN}kind already installed${NC}"; \
	fi

	@if [ ! -f ./kubectl ] || [ ! -x ./kubectl ]; then \
		echo "${YELLOW}Installing kubectl...${NC}"; \
		curl -LO "https://dl.k8s.io/release/v1.29.1/bin/linux/amd64/kubectl"; \
		chmod +x ./kubectl; \
		echo "${GREEN}kubectl installed${NC}"; \
	else \
		echo "${GREEN}kubectl already installed${NC}"; \
	fi

	@echo "${GREEN}Dependencies installed\n${NC}"


setup-kind-cluster:
	@echo "${YELLOW}Checking if kind cluster exists...${NC}"
	@if ! ./kind get clusters 2>/dev/null | grep -q "kind"; then \
		echo "${YELLOW}Setting up the kind cluster${NC}"; \
		./kind create cluster --config kind-config.yml; \
		echo "${GREEN}Kind cluster setup\n${NC}"; \
	else \
		echo "${GREEN}Kind cluster already exists\n${NC}"; \
	fi


setup-ingress:
	@echo "${YELLOW}Installing nginx...${NC}"
	@if ! ./kubectl get namespaces 2>/dev/null | grep -q "ingress-nginx"; then \
		echo "${YELLOW}Creating ingress-nginx namespace${NC}"; \
		./kubectl create namespace ingress-nginx; \
		echo "${YELLOW}Applying nginx ingress controller...${NC}"; \
		./kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml; \
	else \
		echo "${GREEN}Namespace ingress-nginx already exists\n${NC}"; \
	fi
	@echo "${YELLOW}Waiting for nginx controller pods to be ready...${NC}"
	@echo "${YELLOW}This may take a few minutes...${NC}"
	@sleep 5
	@./kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=300s || (echo "${RED}Timeout waiting for nginx controller. Check logs with: kubectl get pods -n ingress-nginx${NC}" && exit 1)
	@echo "${GREEN}Nginx controller is ready\n${NC}"
	@echo "${YELLOW}Setting up the ingress rules${NC}"
	./kubectl apply -f ingress
	@echo "${GREEN}Ingress controller setup\n${NC}"


setup-ssl:
	@echo "${YELLOW}Creating the ssl secret${NC}"
	./kubectl apply -f ssl
	@echo "${GREEN}SSL secret created\n${NC}"


setup-postgres-credentials:
	@echo "${YELLOW}Creating the postgres credentials secret${NC}"
	./kubectl apply -f postgres-cred/kubernetes
	@echo "${GREEN}Postgres credentials secret created\n${NC}"


setup-services:
	@echo "${YELLOW}Setting up the services${NC}"
	./kubectl apply -f frontend/kubernetes
	./kubectl apply -f db/kubernetes
	./kubectl apply -f auth/kubernetes
	./kubectl apply -f matchmaking/kubernetes
	./kubectl apply -f game/kubernetes
	./kubectl apply -f ia/kubernetes
	@echo "${GREEN}Services setup\n${NC}"


wait-for-services:
	@echo "${YELLOW}Waiting for the services to be ready...${NC}"
	@echo "${YELLOW}This may take a few minutes...${NC}"
	@sleep 2
	@if ./kubectl get pods -n default | grep -q "No resources found"; then \
		echo "${RED}No pods found in default namespace${NC}"; \
		exit 1; \
	fi
	@./kubectl wait --namespace default \
		--for=condition=ready pod \
		--all \
		--timeout=300s || (echo "${RED}Timeout waiting for services. Check logs with: kubectl get pods -n default${NC}" && exit 1)
	@echo "${GREEN}Services are ready\n${NC}"


display-url:
	@echo "${YELLOW}Use this URL to access the frontend:${NC}"
	@echo "${GREEN}https://localhost:7777${NC}"
	@echo "${YELLOW}⚠️Works best on Google Chrome$\n{NC}"


down:
	@echo "${YELLOW}Stopping kind cluster...${NC}"
	@if ./kind get clusters 2>/dev/null | grep -q "kind"; then \
		docker pause kind-control-plane; \
		echo "${GREEN}Cluster paused${NC}"; \
	else \
		echo "${RED}No cluster running\n${NC}"; \
	fi


boot:
	@echo "${YELLOW}Booting kind cluster...${NC}"
	@if docker ps -a | grep -q "kind-control-plane"; then \
		if docker ps -a --filter "status=paused" | grep -q "kind-control-plane"; then \
			docker unpause kind-control-plane; \
			echo "${GREEN}Cluster resumed${NC}"; \
		elif docker ps -a --filter "status=exited" | grep -q "kind-control-plane"; then \
			docker start kind-control-plane; \
			echo "${GREEN}Cluster started${NC}"; \
		else \
			echo "${GREEN}Cluster already running${NC}"; \
		fi; \
	else \
		echo "${RED}No cluster found. Please create one first\n${NC}"; \
		exit 1; \
	fi


clean: down
	@echo "${YELLOW}Cleaning kind cluster and resources...${NC}"
	@if ./kind get clusters 2>/dev/null | grep -q "kind"; then \
		./kind delete cluster; \
		echo "${GREEN}Cluster deleted${NC}"; \
	else \
		echo "${GREEN}No cluster to delete\n${NC}"; \
	fi


fclean: clean
	@echo "${YELLOW}Removing binaries...${NC}"
	@if [ -f ./kind ]; then \
		rm -f ./kind; \
		echo "${GREEN}kind binary removed${NC}"; \
	fi
	@if [ -f ./kubectl ]; then \
		rm -f ./kubectl; \
		echo "${GREEN}kubectl binary removed${NC}"; \
	fi
	@echo "${GREEN}Clean complete\n${NC}"


re: fclean all

.PHONY: down boot clean fclean
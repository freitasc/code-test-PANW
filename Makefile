SHELL := /bin/bash

.PHONY: help install-tools check-tools security-scan build deploy fetch-output run clean all

help:
	@echo "Available targets:"
	@echo "  install-tools   - Install required Python packages"
	@echo "  check-tools     - Check if required tools are installed"
	@echo "  security-scan   - Run security scans with Bandit and Checkov"
	@echo "  build           - Build the Docker image"
	@echo "  deploy          - Deploy the application to Kubernetes"
	@echo "  fetch-output    - Fetch and print the output from the API"
	@echo "  run             - Run the full workflow (build, deploy, fetch-output)"
	@echo "  clean           - Clean up Kubernetes resources"

install-tools:
	@python3 -m pip install --upgrade pip
	@python3 -m pip install bandit checkov

check-tools:
	@command -v minikube >/dev/null 2>&1 || { echo >&2 "Minikube is not installed. Please install it to proceed."; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo >&2 "Kubectl is not installed. Please install it to proceed."; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo >&2 "Docker is not installed. Please install it to proceed."; exit 1; }
	@command -v bandit >/dev/null 2>&1 || { echo >&2 "Bandit is not installed. Please run 'make install-tools' to install it."; exit 1; }
	@command -v checkov >/dev/null 2>&1 || { echo >&2 "Checkov is not installed. Please run 'make install-tools' to install it."; exit 1; }

security-scan:
	@set -eu; \
	echo "Running Bandit security scan... (always true)"; \
	bandit -r . -x ./output,./__pycache__,./.git -o bandit_report.json -f json || true; \
	echo "Running Checkov Docker security scan... (always true)"; \
	checkov -f Dockerfile --output-file-path=checkov_docker_report --output json || true; \
	echo "Running Checkov Kubernetes security scan... (always true)"; \
	checkov -d k8 --output-file-path=checkov_k8_report --output json || true; \
	echo ""; \
	echo "Security scan completed. Reports generated: bandit_report.json, checkov_docker_report, checkov_k8_report"

build:
	@echo "Starting Minikube and building Docker image..."
	@minikube start
	@eval $$(minikube docker-env)
	@docker build -t code-test-image .

deploy:
	@echo "Deploying application to Kubernetes..."
	@kubectl -n code-test delete job --all || true
	@kubectl -n code-test apply -f k8/jobs.yaml
	@kubectl -n code-test apply -f k8/secrets.yaml
	
fetch-output:
	@echo "Fetching output from Kubernetes..."
	@kubectl -n code-test delete pod output-reader || true
	@kubectl -n code-test apply -f k8/jobs.yaml
	@kubectl -n code-test apply -f k8/secrets.yaml
	@kubectl -n code-test wait --for=condition=Ready pod/output-reader --timeout=60s
	@echo "Output from API:"
	@mkdir -p ./kube-output
	@kubectl -n code-test cp output-reader:/app/output/posture_data.csv ./kube-output/posture_data.csv
	@ls -la ./kube-output/posture_data.csv

run: build deploy fetch-output

all: check-tools security-scan run

clean:
	@echo "Cleaning up Kubernetes resources..."
	@kubectl -n code-test delete job --all || true
	@kubectl -n code-test delete pod output-reader || true
	@echo "Cleanup completed."
	@echo "Cleaning up security scan reports..."
	@rm -r -f bandit_report.json checkov_docker_report checkov_k8_report
	@echo "Cleanup of security scan reports completed."
	@echo "All cleanup completed."
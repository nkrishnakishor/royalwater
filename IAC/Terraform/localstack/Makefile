# LocalStack EKS Pipeline — Makefile
# Usage:
#   make cluster-up    — start LocalStack + provision all infra (one-time per session)
#   make trigger       — upload trigger artifact + start pipeline execution
#   make verify        — check deployment status
#   make cluster-down  — destroy infra + stop LocalStack

SHELL         := /bin/bash
APP_NAME      ?= myapp
REGION        ?= us-east-1
CLUSTER_NAME  ?= $(APP_NAME)-cluster
PIPELINE_NAME ?= $(APP_NAME)-pipeline
TRIGGER_BUCKET ?= $(APP_NAME)-pipeline-trigger
LOCALSTACK_URL := http://localhost:4566
AWSLOCAL      := aws --endpoint-url=$(LOCALSTACK_URL) --region=$(REGION)
TF_DIR        := terraform

.PHONY: cluster-up cluster-down trigger verify status kubeconfig pipeline help

help:
	@echo "LocalStack EKS Pipeline"
	@echo ""
	@echo "  make cluster-up    Start LocalStack + provision all infra (run once per session)"
	@echo "  make cluster-down  Destroy infra + stop LocalStack"
	@echo "  make trigger       Upload trigger + start CodePipeline execution"
	@echo "  make verify        Check pods, ingress, and HTTP endpoint"
	@echo "  make status        Show cluster, pipeline, and pod status"
	@echo "  make kubeconfig    Re-configure kubectl context"

# ── Cluster Lifecycle ──────────────────────────────────────────────────────────

cluster-up: _localstack-up _tf-apply _wait-eks _kubeconfig-write
	@echo ""
	@echo "Cluster is ready. Run 'make trigger' to deploy the app."

_localstack-up:
	@echo "Starting LocalStack..."
	docker compose up -d
	@echo "Waiting for LocalStack to be ready..."
	@until $(AWSLOCAL) ec2 describe-availability-zones > /dev/null 2>&1; do \
	  echo "  waiting..."; sleep 3; \
	done
	@echo "LocalStack is up."

_tf-apply:
	@echo "Provisioning infrastructure with Terraform..."
	cd $(TF_DIR) && tflocal init -input=false -upgrade > /dev/null
	cd $(TF_DIR) && tflocal apply -auto-approve -input=false

_wait-eks:
	@echo "Waiting for EKS cluster to become ACTIVE..."
	@until [ "$$($(AWSLOCAL) eks describe-cluster --name $(CLUSTER_NAME) \
	  --query 'cluster.status' --output text 2>/dev/null)" = "ACTIVE" ]; do \
	  echo "  cluster status: $$($(AWSLOCAL) eks describe-cluster --name $(CLUSTER_NAME) \
	    --query 'cluster.status' --output text 2>/dev/null || echo 'CREATING')"; \
	  sleep 5; \
	done
	@echo "EKS cluster is ACTIVE."

_kubeconfig-write:
	@echo "Writing kubeconfig..."
	$(AWSLOCAL) eks update-kubeconfig --name $(CLUSTER_NAME) --region $(REGION)
	@echo "kubectl context set."
	@kubectl get nodes

cluster-down:
	@echo "Destroying infrastructure..."
	cd $(TF_DIR) && tflocal destroy -auto-approve -input=false || true
	@echo "Stopping LocalStack..."
	docker compose down
	@echo "Done."

kubeconfig: _wait-eks _kubeconfig-write

# ── Pipeline Trigger ───────────────────────────────────────────────────────────

trigger:
	@echo "Uploading trigger artifact to S3..."
	$(AWSLOCAL) s3 cp trigger.json s3://$(TRIGGER_BUCKET)/trigger.json
	@echo "Starting CodePipeline execution..."
	$(eval EXEC_ID := $(shell $(AWSLOCAL) codepipeline start-pipeline-execution \
	  --name $(PIPELINE_NAME) --query 'pipelineExecutionId' --output text))
	@echo "Pipeline execution ID: $(EXEC_ID)"
	@echo "Polling pipeline status..."
	@while true; do \
	  STATUS=$$($(AWSLOCAL) codepipeline get-pipeline-execution \
	    --pipeline-name $(PIPELINE_NAME) \
	    --pipeline-execution-id $(EXEC_ID) \
	    --query 'pipelineExecution.status' --output text 2>/dev/null); \
	  echo "  status: $$STATUS"; \
	  if [ "$$STATUS" = "Succeeded" ]; then \
	    echo "Pipeline SUCCEEDED."; break; \
	  elif [ "$$STATUS" = "Failed" ] || [ "$$STATUS" = "Stopped" ]; then \
	    echo "Pipeline FAILED ($$STATUS). Check logs."; exit 1; \
	  fi; \
	  sleep 10; \
	done

# ── Verify ─────────────────────────────────────────────────────────────────────

verify:
	@echo "=== Pods ==="
	kubectl get pods -l app=$(APP_NAME)
	@echo ""
	@echo "=== Services ==="
	kubectl get svc -l app=$(APP_NAME)
	@echo ""
	@echo "=== Ingress ==="
	kubectl get ingress
	@echo ""
	@echo "=== HTTP check ==="
	curl -sf http://localhost:8081/app && echo "OK" || echo "Not reachable yet."

# ── Status ─────────────────────────────────────────────────────────────────────

status:
	@echo "=== EKS Cluster ==="
	$(AWSLOCAL) eks describe-cluster --name $(CLUSTER_NAME) \
	  --query 'cluster.{Name:name,Status:status,Endpoint:endpoint}' --output table
	@echo ""
	@echo "=== Latest Pipeline Execution ==="
	$(AWSLOCAL) codepipeline list-pipeline-executions --pipeline-name $(PIPELINE_NAME) \
	  --max-results 1 --output table 2>/dev/null || echo "No executions yet."
	@echo ""
	@echo "=== All Pods ==="
	kubectl get pods -A

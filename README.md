# devops-assessments
This is my Devops-Assesment task for digitalsofts.

# Production-Grade DevOps Assessment & Infrastructure Setup

This repository contains a fully automated, containerized, and scalable deployment pipeline for a **Laravel Application** using AWS, Docker, Jenkins (Master/Agent Architecture), and Terraform.

## Architecture Overview

[ Developer ] ──> [ GitHub ] ──(Webhook)──> [ Jenkins Master ]
│
(Build & Deploy)
▼
[ End User ] ──> [ AWS ALB ] ──(Port 8080)──> [ Jenkins Agent / Docker Container ]
│
┌────────────┴────────────┐
▼                         ▼
[ MySQL Database ]        [ AWS S3 Backup ]


- **Application:** Laravel PHP Application
- **CI/CD Automation:** Jenkins Master/Agent setup with GitHub Webhook triggers
- **Containerization:** Docker with automated cache clearing
- **Load Balancing:** AWS Application Load Balancer (ALB) with HTTP-to-HTTPS Redirection
- **Database Backup:** Automated shell scripts uploading MySQL dumps to AWS S3
- **Infrastructure:** EC2 Instances, Target Groups, Security Groups, and CloudWatch Alarms
---
## 📁 Repository Directory Structure

```text
devops-assessment/
├── app/                  # Laravel application codebase
├── docker/               # Docker & Nginx specific configuration files
├── terraform/            # Infrastructure as Code (.tf files)
├── k8s/                  # Kubernetes manifests (Deployments, Services)
├── scripts/              # Automation scripts (deploy.sh, backup.sh)
├── devops-assessments/
│   └── workflows/        # Jenkins CI/CD workflows
├── monitoring/           # CloudWatch Alarm definitions & configurations
├── docs/
├    └── screenshots/     # Architecture diagrams & proof screenshots
├── Dockerfile            # Container build definition
├── Jenkinsfile           # Multi-stage CI/CD pipeline script
├── docker-compose.yml    # Multi-container orchestration config
├── README.md             # Project documentation
├── SECURITY.md           # Security policies and best practices
└── AI_USAGE.md           # AI assistance usage disclosures


# After Improvements

# Enterprise Laravel DevOps & Cloud Infrastructure Architecture

This repository contains the end-to-end, reproducible DevOps infrastructure, CI/CD pipelines, IaC provisioners, and Kubernetes manifests for deploying a highly available, fault-tolerant Laravel application on AWS.

---

## 1. System Architecture Diagram

Internet
                             │
                             ▼
                [ AWS Route 53 (DNS) ]
                             │
                             ▼
           [ Application Load Balancer (ALB) ]
           (Multi-AZ Public Subnets: 80/443)
                             │
        ┌────────────────────┴────────────────────┐
        ▼                                         ▼
        [ EC2 Instance - AZ-A ]                   [ EC2 Instance - AZ-B ]
(Docker Container: 8080)                  (Docker Container: 8080)
│                                         │
└────────────────────┬────────────────────┘
│
┌────────────────────┼────────────────────┐
▼                    ▼                    ▼
[ Amazon RDS MariaDB ]   [ AWS S3 Bucket ]   [ CloudWatch ]
(Private DB Subnet)     (Backups & State)   (Logs & Metrics)

---

## 2. Prerequisites

Before reproducing this infrastructure, ensure you have the following CLI tools installed and configured locally:

* **AWS CLI v2** (configured with appropriate IAM permissions)
* **Terraform v1.5+**
* **Docker Engine & Docker Compose**
* **kubectl v1.28+** (for Kubernetes deployments)
* **Git**

---

## 3. Environment Configuration & Secrets

Copy `.env.example` to `.env` and populate the required runtime environment variables:

```bash
# Application Configuration
APP_ENV=production
APP_KEY=base64:YourSuperSecretKeyHere
APP_DEBUG=false
APP_URL=[[http://your-alb-dns.amazonaws.com]](https://staging-alb-1569892775.eu-north-1.elb.amazonaws.com/)([http://your-alb-dns.amazonaws.com](https://thelyricsclub.com/))

# Database Credentials
DB_HOST=10.0.1.112
DB_PORT=3306
DB_DATABASE=devops
DB_USERNAME=root
DB_PASSWORD=*********

# Storage & Backups
S3_BUCKET_NAME=devops-assessment-zain-backups-2026
AWS_DEFAULT_REGION=us-north-1

## 4. Infrastructure Provisioning (Terraform IaC)
## The entire cloud infrastructure is 100% codified using Terraform.
Navigate to Terraform directory:

cd terraform/
Initialize Remote Backend & Modules:

terraform init
Validate Infrastructure Configuration:

terraform validate
Inspect Execution Plan:

terraform plan -out=tfplan
Apply & Spin Up AWS Resources:

terraform apply tfplan

## 5. Jenkins CI/CD Setup & GitHub Webhook
## Jenkins Server Requirements: Docker, Git, and AWS CLI pre-installed on the agent node (agentzain).

Plugins Required: Pipeline, Git, Docker Pipeline, Credentials Binding.

GitHub Webhook Configuration:

Go to your GitHub Repository -> Settings -> Webhooks -> Add Webhook.

Payload URL: http://YOUR_JENKINS_SERVER_IP:8080/github-webhook/

Content Type: application/json

Events: Trigger on Just the push event.

## 6. Docker Architecture & Layer Optimization
## Multi-Stage Build: Dependencies are resolved in a lightweight builder stage before copying operational artifacts into the runtime image.

Layer Caching: Layer order is structured to cache static system dependencies (apt-get, PHP extensions) separately from dynamic application code, reducing build time by over 80%.

Immutable Tagging: Every build generates an immutable tag based on the Git Commit SHA (my-laravel-app:${GIT_COMMIT_SHA}) along with updating :latest.

## 7. Deployment, Health Checks & Automated Rollback
## Deployments are managed by the Jenkinsfile pipeline executing the following quality gates:

Pre-Build Test Gate: Runs ./vendor/bin/phpunit --stop-on-failure.

Container Launch: Spins up the newly tagged container image.

Health Verification: Performs an automated HTTP status check (http://127.0.0.1:8080).

Automated Rollback: If the health check returns any status other than 200 OK (e.g., HTTP 500 error), the pipeline's try-catch block triggers immediately:

Stops and deletes the broken container.

Restores the previous stable image (my-laravel-app:latest).

Halts downstream stages and marks the build as failed.


## 8. Backup & Disaster Recovery (DR) Strategy
## RPO (Recovery Point Objective): 24 Hours (Daily Automated Cron/Pipeline Backups).

RTO (Recovery Time Objective): < 15 Minutes.

S3 Security: Backups are compressed (.sql.gz), encrypted with AES-256, and lifecycle-managed (archived after 30 days).

Executing a Database Restore:
Run the automated restore script with valid AWS and DB environment variables:

Bash
chmod +x scripts/restore.sh
./scripts/restore.sh

## 9. Kubernetes Orchestration (k8s/)
## To deploy this application on Kubernetes (EKS / Minikube):

# Apply ConfigMaps and Secrets
kubectl apply -f k8s/configmap-secret.yaml

# Deploy Application Pods & Rolling Strategy
kubectl apply -f k8s/deployment.yaml

# Expose LoadBalancer Service & HPA Auto-scaler
kubectl apply -f k8s/service-hpa.yaml

## 10. Monitoring & Alarms
## AWS CloudWatch Alarms: Monitored metrics include EC2 CPU Utilization (>75%), ALB Target Health Checks, and RDS Storage/IOPS thresholds.

Logging: Application container stdout/stderr logs are streamed directly to CloudWatch Log Groups.

## 11. Troubleshooting Common Issues
## Pipeline Failures at Quality Gate: Check local test status using ./vendor/bin/phpunit. Ensure DB migrations are up to date.

Container Health Check Timeout: Verify port mappings (8080:80) and confirm .env database parameters are reachable from inside the container.

Terraform State Lock Errors: Force-unlock the DynamoDB table if a previous run crashed unexpectedly:
terraform force-unlock <LOCK-ID>

## 12. Cleanup (Tear Down Infrastructure)
## To destroy all provisioned AWS cloud resources and avoid incurring unwanted costs:

cd terraform/
terraform destroy -auto-approve



## 13. Estimated AWS Monthly Cost Breakdown

| AWS Resource | Service / Specification | Estimated Monthly Cost (USD) |
| :--- | :--- | :--- |
| **EC2 Instances** | 2x `t3.small` (Linux, On-Demand) | ~$30.00 |
| **Amazon VPC** | Custom VPC, Subnets, Route Tables & IGW | **$0.00** |
| **AWS Certificate Manager (ACM)** | SSL/TLS Public Certificate | **$0.00** |
| **AWS Route 53** | 1 Hosted Zone + 5 DNS Records | ~$0.50 |
| **Application Load Balancer (ALB)** | 1x ALB + LCU Usage | ~$18.00 |
| **Amazon S3** | State Files & DB Backups (<10 GB Storage) | ~$0.50 |
| **AWS CloudWatch** | Alarms, Log Groups & Basic Metrics | ~$2.00 |
| **Total Estimated Cost** | **Production-Ready AWS Architecture** | **~$51.00 / month** |


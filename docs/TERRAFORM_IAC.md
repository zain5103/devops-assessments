# Infrastructure as Code (IaC) Strategy with Terraform

This project transitioned from existing/manual cloud infrastructure to a 100% automated, reproducible, and modular Infrastructure as Code (IaC) architecture using Terraform.

## Why Manual Infrastructure Was Replaced

Previously, relying on pre-existing or manually created AWS instances meant the environment was non-reproducible, prone to configuration drift, and difficult for other engineers to spin up independently.

Now, the entire AWS infrastructure—from networking to compute, load balancing, security, and storage—is codified in version-controlled `.tf` files. Any DevOps engineer can clone this repository and spin up an exact replica of the production environment with standard Terraform commands.

---

## Provisioned AWS Resources

Executing a single `terraform apply` provisions the following resources end-to-end:

* **Networking:** Custom VPC, Public & Private Subnets across multiple Availability Zones, Internet Gateway, and Route Tables.
* **Security & Access (IAM & SGs):**
  * **ALB Security Group:** Allows external HTTP/HTTPS traffic (Ports 80/443).
  * **EC2 Security Group:** Strictly limits inbound access to Port 8080 only from the Application Load Balancer.
  * **RDS Security Group:** Allows Database connections (Port 3306) only from the EC2 application layer.
  * **IAM Roles & Policies:** Least-privilege roles for EC2 S3 backup access and CloudWatch logs ingestion.
* **Compute & Automation:** EC2 instances provisioned with automated `user_data` scripts that install and configure Docker engine upon boot.
* **Load Balancing:** Application Load Balancer (ALB) with Target Groups, Listener Rules, and Health Check paths (`/`).
* **Database & Storage:** Amazon RDS (MariaDB/MySQL) instance running inside private database subnets and an S3 Bucket configured for database backups.
* **Monitoring:** CloudWatch Log Groups and Metric Alarms configured for CPU utilization and instance health monitoring.

---

## Terraform State, Remote Backend & Locking

To ensure enterprise-grade team collaboration and prevent state corruption:

1. **Remote State Storage:** State is stored centrally in an **AWS S3 Bucket** (with bucket versioning enabled to track state history and allow state rollbacks).
2. **State Locking (DynamoDB):** An **AWS DynamoDB table** is configured for state locking (`LockID`). This prevents concurrent execution and race conditions when multiple engineers or CI/CD pipelines run `terraform apply`.
3. **Sensitive Data & Variables:** Passwords, API keys, and sensitive database credentials are passed dynamically via `terraform.tfvars` (ignored in `.gitignore`) or environment variables (`TF_VAR_*`), keeping secrets out of source code.

---

## Environment Reproduction Steps

To deploy this entire infrastructure in your own AWS account:

1. **Initialize Working Directory:**
   ```bash
   cd terraform/
   terraform init

   Validate Syntax & Configurations:
   terraform validate

   Review Execution Plan:
   terraform plan -out=tfplan

   Apply Infrastructure Changes:
   terraform apply tfplan
   
   Clean Up / Destroy Resources:
   terraform destroy


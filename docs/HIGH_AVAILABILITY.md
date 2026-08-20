# High Availability (HA) & Multi-AZ Fault Tolerance Architecture

This document outlines the High Availability (HA) design implemented to eliminate single points of failure (SPOF) across compute, networking, and database layers.

## High Availability Architecture Diagram

Internet
                      │
                      ▼
         [ AWS Application Load Balancer ]
         (Cross-Zone Load Balancing Active)
                │                   │
     ┌──────────┴──────────┐        └──────────┐
     ▼                     ▼                   ▼
[ AZ-A (us-east-1a) ]   [ AZ-B (us-east-1b) ]  [ Health Checks ]

## Technical Pillars of HA Strategy

1. **Multi-AZ Compute (Auto Scaling Group):**
   * EC2 instances are distributed across multiple AWS Availability Zones.
   * Auto Scaling Group (ASG) maintains a minimum capacity of 2 instances. If load increases or an instance fails, ASG automatically provisions replacement nodes.

2. **Stateless Application Architecture:**
   * Laravel session state is decoupled from local container storage and stored in Amazon ElastiCache (Redis) or MySQL database.
   * Any client request can land on EC2-A or EC2-B transparently without losing user session context.

3. **Multi-AZ Database Layer (Amazon RDS):**
   * Multi-AZ deployment enabled on RDS (MariaDB/MySQL).
   * Data is synchronously replicated to a standby replica in a secondary AZ. In the event of primary DB failure, AWS automatically executes a DNS failover (< 60 seconds).

---

## Failure Scenarios & Recovery Analysis

| Failure Event | Impact | Automatic Recovery Mechanism |
| :--- | :--- | :--- |
| **EC2-A Fails / Crashes** | Zero Downtime | ALB Health Check fails instance A. All inbound traffic routes instantly to EC2-B. Auto Scaling Group terminates EC2-A and spins up EC2-C in AZ-A. |
| **Docker Container Crashes** | Temporary Request Re-route | Container restart policy (`--restart unless-stopped`) or K8s readiness probe triggers container reboot. ALB diverts traffic to healthy nodes until boot succeeds. |
| **Entire AZ-A Goes Down** | Zero Downtime | AWS ALB automatically routes 100% of incoming traffic to AZ-B. RDS primary automatically fails over to the standby instance in AZ-B. |

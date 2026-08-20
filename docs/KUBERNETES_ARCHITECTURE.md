# Kubernetes (K8s) Deployment & Container Orchestration Strategy

This directory contains production-ready Kubernetes manifests to orchestrate the Laravel application on Amazon EKS or any self-managed K8s cluster.

## K8s Core Components Implemented

1. **Deployments & Pod Replicas:**
   * Configured with `replicas: 2` across cluster nodes.
   * Employs a **Zero-Downtime RollingUpdate Strategy** (`maxSurge: 1`, `maxUnavailable: 0`), ensuring new Pods boot before terminating legacy Pods.

2. **Self-Healing & Health Monitoring:**
   * **Liveness Probe:** Periodically checks if the Laravel app container is alive. Restarts corrupt containers automatically.
   * **Readiness Probe:** Ensures traffic is only directed to Pods that have fully initialized Laravel caches and routes.

3. **Resource Management & Limits:**
   * Strict `requests` and `limits` configured to prevent Pod OOM (Out Of Memory) issues and prevent noisy neighbor problems on nodes.

4. **ConfigMaps & Secrets:**
   * Decouples application configuration (`APP_ENV`, DB Host) from image binaries via `ConfigMap`.
   * Securely mounts sensitive database credentials using K8s `Secret`.

5. **Auto Scaling & Traffic Management:**
   * **Service:** Exposes the application deployment via a K8s LoadBalancer.
   * **Horizontal Pod Autoscaler (HPA):** Automatically scales Pod replicas from 2 up to 5 whenever average CPU utilization crosses 75%.

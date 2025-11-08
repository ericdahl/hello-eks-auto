# Repository Review Findings

This document contains all issues and improvements identified during the code review of hello-eks-auto.

## Critical/High Priority Issues

### 1. Missing Terraform Version Constraints
**Severity:** High
**File:** Root Terraform files
**Description:** No `terraform` block specifying required Terraform version or provider version constraints. This can lead to compatibility issues and unexpected behavior when different versions are used.

**Recommendation:**
```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

---

### 2. CloudWatch Log Group Missing Retention Policy
**Severity:** High (Cost Impact)
**File:** `eks_cluster.tf:77-79`
**Description:** CloudWatch log group for EKS cluster logs has no retention policy, meaning logs are retained indefinitely, which will continuously increase costs.

**Recommendation:**
```hcl
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.name}/cluster"
  retention_in_days = 7  # or 30, 90, etc. based on requirements
}
```

---

### 3. Security Risk: Highly Privileged Debug DaemonSet
**Severity:** Critical (Security)
**File:** `k8s/debug.yaml`
**Description:** The debug DaemonSet runs with:
- `privileged: true`
- `hostPID: true`
- `hostIPC: true`
- `hostNetwork: true`
- Host root filesystem mounted at `/host`

This is a significant security risk if left running in production or if the cluster is compromised.

**Recommendation:**
- Add prominent warning in README about removing this before production
- Consider using kubectl debug or ephemeral containers instead
- If needed, add namespace isolation and document it's for debugging only

---

### 4. Missing Terraform Tags Required by CodeRabbit Config
**Severity:** High
**File:** All Terraform resources
**Description:** `.coderabbit.yml` requires `ManagedBy` and `Provisioner=Terraform` tags on all taggable resources, but these are not present.

**Recommendation:**
Add to `main.tf` default_tags:
```hcl
default_tags {
  tags = {
    Name        = "hello-eks-auto"
    Repository  = "https://github.com/ericdahl/hello-eks-auto"
    ManagedBy   = "team-name"  # Update with actual team
    Provisioner = "Terraform"
  }
}
```

---

### 5. Grafana Using Default Credentials
**Severity:** Medium (Security)
**File:** `k8s/grafana.yaml`
**Description:** Grafana deployment uses default admin/admin credentials without secret management.

**Recommendation:**
Use Kubernetes secrets to manage Grafana admin credentials:
```yaml
env:
  - name: GF_SECURITY_ADMIN_PASSWORD
    valueFrom:
      secretKeyRef:
        name: grafana-admin
        key: password
```

---

### 6. Promtail Running as Root User
**Severity:** Medium (Security)
**File:** `k8s/promtail.yaml:194-196`
**Description:** Promtail DaemonSet runs with `runAsUser: 0` and `runAsGroup: 0` (root), which violates least-privilege principle.

**Recommendation:**
While Promtail needs to read host logs, consider using security contexts with appropriate capabilities instead of running as root, or document why root is necessary.

---

## Medium Priority Issues

### 7. Missing Terraform Outputs
**Severity:** Medium
**File:** N/A - missing file
**Description:** No `outputs.tf` file to export important values like cluster endpoint, cluster name, VPC ID, etc.

**Recommendation:**
Create `outputs.tf`:
```hcl
output "cluster_endpoint" {
  value = aws_eks_cluster.default.endpoint
}

output "cluster_name" {
  value = aws_eks_cluster.default.name
}

output "cluster_security_group_id" {
  value = aws_eks_cluster.default.vpc_config[0].cluster_security_group_id
}
```

---

### 8. README References Non-Existent File
**Severity:** Medium (Documentation)
**File:** `README.md:55`
**Description:** README references `promtail-helm.yaml` but the actual file is `promtail.yaml`.

**Current:**
```bash
kubectl apply -f k8s/promtail-helm.yaml -n loki
```

**Should be:**
```bash
kubectl apply -f k8s/promtail.yaml -n loki
```

---

### 9. Hardcoded Kubeconfig Path in tf-k8s Modules
**Severity:** Medium
**Files:** All `tf-k8s/*/main.tf`
**Description:** All Kubernetes provider configurations use hardcoded `~/.kube/config` path.

**Recommendation:**
Make configurable or use environment variables:
```hcl
provider "kubernetes" {
  config_path = var.kubeconfig_path != "" ? var.kubeconfig_path : "~/.kube/config"
}
```

---

### 10. Duplicate/Conflicting Promtail Configurations
**Severity:** Medium (Confusion)
**Files:** `k8s/loki-simple.yaml` and `k8s/promtail.yaml`
**Description:** Two separate Promtail configurations exist with different versions (2.9.3 vs 3.0.0) and configurations. This can be confusing for users.

**Recommendation:**
- Document which file to use for which scenario
- Consider consolidating or clearly separating "simple" vs "advanced" configurations

---

### 11. Inconsistent NodeClass Configurations
**Severity:** Medium
**Files:** `k8s/nodeclass-ephemeral-storage.yaml` and `tf-k8s/nodeclass/main.tf`
**Description:** Two different NodeClass configurations with different selectors and names. The YAML version uses non-existent tag selectors.

**Recommendation:**
Align configurations or document the differences clearly.

---

### 12. Missing Variable Description
**Severity:** Low
**File:** `variables.tf:15`
**Description:** `access_entry_principal_arn` variable has no description.

**Recommendation:**
```hcl
variable "access_entry_principal_arn" {
  description = "ARN of the IAM principal (user or role) to grant EKS cluster admin access"
  type        = string
}
```

---

### 13. Missing Resource Requests/Limits
**Severity:** Medium
**Files:** Multiple Kubernetes manifests
**Description:** Several deployments don't specify resource requests/limits:
- `k8s/loki-simple.yaml` - Loki container
- `k8s/loki-simple.yaml` - Promtail container
- `k8s/game-2048/01-game.yaml` - 2048 game deployment

**Recommendation:**
Add resource requests and limits to all containers for better scheduling and resource management.

---

### 14. Missing Namespace Specification
**Severity:** Medium
**Files:** `k8s/grafana.yaml`, `k8s/grafana-simple.yaml`
**Description:** Grafana manifests don't specify a namespace, will deploy to 'default'.

**Recommendation:**
Add namespace to metadata or document that namespace must be specified at apply time.

---

### 15. Using :latest Tag in Production
**Severity:** Medium
**File:** `k8s/grafana.yaml:34`
**Description:** Grafana deployment uses `grafana/grafana:latest` which is not reproducible and can break unexpectedly.

**Recommendation:**
Pin to specific version like in `grafana-simple.yaml:34` which uses `11.4.0`.

---

## Low Priority Issues / Enhancements

### 16. TODO Comment in Code
**Severity:** Low
**File:** `vpc.tf:2`
**Description:** Unresolved TODO comment: "TODO: simplify or reorganize?"

**Recommendation:**
Either resolve the TODO or remove the comment.

---

### 17. No Terraform Backend Configuration
**Severity:** Low
**Description:** Terraform state will be stored locally. For team collaboration, consider remote state.

**Recommendation:**
Add backend configuration for S3 + DynamoDB or Terraform Cloud.

---

### 18. VPC Subnet Naming Uses CIDR Block
**Severity:** Low
**File:** `vpc.tf:28`
**Description:** Subnet Name tag uses VPC CIDR block which is not descriptive.

**Current:**
```hcl
Name = "${aws_vpc.default.cidr_block}-public"
```

**Recommendation:**
```hcl
Name = "${local.name}-public-${each.key}"
```

---

### 19. Missing VPC Flow Logs
**Severity:** Low (Security/Auditing)
**Description:** VPC doesn't have flow logs enabled for network traffic auditing.

**Recommendation:**
Add VPC flow logs for security and troubleshooting:
```hcl
resource "aws_flow_log" "vpc" {
  vpc_id          = aws_vpc.default.id
  traffic_type    = "ALL"
  iam_role_arn   = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
}
```

---

### 20. Loki ServiceAccount Not Created
**Severity:** Low
**File:** `tf-k8s/loki/main.tf:48`
**Description:** Loki StatefulSet references `service_account_name = "loki"` but doesn't create the ServiceAccount.

**Recommendation:**
Create the ServiceAccount resource or use "default".

---

### 21. Missing Storage Class in Grafana PVC
**Severity:** Low
**File:** `k8s/grafana.yaml:3-11`
**Description:** PVC doesn't specify a storage class, will use cluster default.

**Recommendation:**
Explicitly specify storage class for clarity:
```yaml
spec:
  storageClassName: gp3
```

---

### 22. Inconsistent 2048 Game Replica Counts
**Severity:** Low
**Files:** `k8s/game-2048/01-game.yaml` vs `tf-k8s/game-2048/main.tf`
**Description:** YAML version has 5 replicas, Terraform version has 1.

**Recommendation:**
Align replica counts or document the difference.

---

### 23. Missing Standard Kubernetes Labels
**Severity:** Low
**Description:** Many resources are missing standard Kubernetes labels like:
- `app.kubernetes.io/name`
- `app.kubernetes.io/version`
- `app.kubernetes.io/component`
- `app.kubernetes.io/managed-by`

**Recommendation:**
Add standard labels for better resource management and observability.

---

### 24. No Network Policies
**Severity:** Low (Security)
**Description:** No NetworkPolicies defined to restrict pod-to-pod communication.

**Recommendation:**
Consider adding NetworkPolicies for production deployments to follow zero-trust principles.

---

### 25. No PodDisruptionBudgets
**Severity:** Low (Availability)
**Description:** No PodDisruptionBudgets defined for critical services.

**Recommendation:**
Add PDBs for multi-replica deployments to ensure availability during node maintenance.

---

## Summary

**Total Issues Found:** 25
- **Critical/High Priority:** 6
- **Medium Priority:** 9
- **Low Priority/Enhancements:** 10

**Top 5 Recommendations:**
1. Add Terraform version constraints and required providers
2. Add CloudWatch log group retention policy
3. Add security warning about debug DaemonSet
4. Add required tags (ManagedBy, Provisioner) to comply with CodeRabbit config
5. Create outputs.tf for commonly needed values

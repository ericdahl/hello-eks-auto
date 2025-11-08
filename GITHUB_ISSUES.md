# GitHub Issues to Create

Copy each issue below and create them in GitHub. Issues are ordered by priority.

---

## Issue 1: Add Terraform Version Constraints

**Labels:** `terraform`, `enhancement`, `high-priority`

**Title:** Add Terraform version constraints and required provider versions

**Description:**

The repository is missing Terraform version constraints, which can lead to compatibility issues when different users or CI/CD systems use different Terraform versions.

**Current State:**
No `terraform` block exists in the configuration.

**Expected:**
Add version constraints to ensure consistent behavior:

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

**Files Affected:**
- `main.tf` or new `versions.tf`

**Impact:** High - Can cause unexpected behavior or errors with different Terraform versions

---

## Issue 2: Add CloudWatch Log Group Retention Policy

**Labels:** `terraform`, `cost-optimization`, `high-priority`

**Title:** CloudWatch log group for EKS cluster logs missing retention policy

**Description:**

The CloudWatch log group created for EKS cluster logs (`eks_cluster.tf:77-79`) does not have a retention policy, meaning logs will be retained indefinitely. This will continuously increase AWS costs over time.

**Current Code:**
```hcl
resource "aws_cloudwatch_log_group" "cluster" {
  name = "/aws/eks/${local.name}/cluster"
}
```

**Recommended Fix:**
```hcl
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.name}/cluster"
  retention_in_days = 7  # or 30, 90, etc. based on requirements
}
```

**Files Affected:**
- `eks_cluster.tf:77-79`

**Impact:** High - Direct cost impact from log retention

---

## Issue 3: Security Warning Needed for Debug DaemonSet

**Labels:** `security`, `documentation`, `critical`

**Title:** Debug DaemonSet has excessive privileges - add security warning

**Description:**

The debug DaemonSet in `k8s/debug.yaml` runs with highly privileged settings that pose a significant security risk:

- `privileged: true`
- `hostPID: true`
- `hostIPC: true`
- `hostNetwork: true`
- Host root filesystem mounted at `/host`

**Security Implications:**
A compromised pod with these privileges could:
- Access all host resources
- Escape container isolation
- Compromise the entire node and potentially the cluster

**Recommendations:**

1. Add prominent warning in README about removing this DaemonSet before production
2. Add security warning comment at the top of `k8s/debug.yaml`
3. Consider using `kubectl debug` or ephemeral containers as safer alternatives
4. If this must exist, isolate it to a dedicated debug namespace with clear documentation

**Files Affected:**
- `k8s/debug.yaml`
- `README.md`

**Impact:** Critical - Security risk if left running in production

---

## Issue 4: Add Required Terraform Tags per CodeRabbit Config

**Labels:** `terraform`, `compliance`, `high-priority`

**Title:** Terraform resources missing ManagedBy and Provisioner tags

**Description:**

The `.coderabbit.yml` configuration requires all taggable Terraform resources to have `ManagedBy` and `Provisioner=Terraform` tags, but these are not currently present.

**Current CodeRabbit Config:**
```yaml
Every taggable resource should have a ManagedBy tag for their team name.
Every taggable resource should have a Provisioner=Terraform tag key/value.
```

**Recommended Fix:**
Add to `main.tf` default_tags:

```hcl
default_tags {
  tags = {
    Name        = "hello-eks-auto"
    Repository  = "https://github.com/ericdahl/hello-eks-auto"
    ManagedBy   = "team-name"  # Update with actual team name
    Provisioner = "Terraform"
  }
}
```

**Files Affected:**
- `main.tf:4-9`

**Impact:** High - Non-compliance with repository code review requirements

---

## Issue 5: Create Terraform Outputs File

**Labels:** `terraform`, `enhancement`, `medium-priority`

**Title:** Add outputs.tf for commonly needed values

**Description:**

The repository is missing an `outputs.tf` file to export important values like cluster endpoint, cluster name, VPC ID, etc. This makes it harder to use these values in other Terraform modules or scripts.

**Recommended Outputs:**

```hcl
output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.default.endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.default.name
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.default.vpc_config[0].cluster_security_group_id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.default.id
}

output "subnet_ids" {
  description = "List of subnet IDs"
  value       = [for az in var.availability_zones : aws_subnet.public[az].id]
}
```

**Files Affected:**
- New file: `outputs.tf`

**Impact:** Medium - Improves usability and integration

---

## Issue 6: Fix README File Reference

**Labels:** `documentation`, `bug`, `good-first-issue`

**Title:** README references non-existent promtail-helm.yaml file

**Description:**

In `README.md:55`, the Promtail installation instructions reference `promtail-helm.yaml` but the actual file is named `promtail.yaml`.

**Current (Incorrect):**
```bash
kubectl apply -f k8s/promtail-helm.yaml -n loki
```

**Should be:**
```bash
kubectl apply -f k8s/promtail.yaml -n loki
```

**Files Affected:**
- `README.md:55`

**Impact:** Medium - Users following the README will encounter an error

---

## Issue 7: Grafana Using Hardcoded Default Credentials

**Labels:** `kubernetes`, `security`, `enhancement`

**Title:** Grafana deployment should use Kubernetes secrets for credentials

**Description:**

The Grafana deployment uses default admin/admin credentials without secret management. While this is acceptable for a demo, it should be improved for better security practices.

**Current State:**
Credentials are hardcoded as admin/admin

**Recommended Enhancement:**

```yaml
env:
  - name: GF_SECURITY_ADMIN_USER
    valueFrom:
      secretKeyRef:
        name: grafana-admin
        key: username
  - name: GF_SECURITY_ADMIN_PASSWORD
    valueFrom:
      secretKeyRef:
        name: grafana-admin
        key: password
```

**Files Affected:**
- `k8s/grafana.yaml`
- `README.md` (update login instructions)

**Impact:** Medium - Security best practice for credential management

---

## Issue 8: Promtail Running as Root User

**Labels:** `kubernetes`, `security`, `medium-priority`

**Title:** Promtail DaemonSet runs as root user

**Description:**

The Promtail DaemonSet in `k8s/promtail.yaml:194-196` runs with `runAsUser: 0` and `runAsGroup: 0` (root user), which violates the principle of least privilege.

**Current Code:**
```yaml
securityContext:
  runAsUser: 0
  runAsGroup: 0
```

**Consideration:**
While Promtail needs to read host log files, consider if there are alternative approaches using capabilities or file system permissions instead of running as root.

**Files Affected:**
- `k8s/promtail.yaml:194-196`

**Impact:** Medium - Security hardening opportunity

---

## Issue 9: Hardcoded Kubeconfig Paths in tf-k8s Modules

**Labels:** `terraform`, `enhancement`, `good-first-issue`

**Title:** Make kubeconfig path configurable in tf-k8s modules

**Description:**

All Kubernetes provider configurations in `tf-k8s/*/main.tf` use a hardcoded path `~/.kube/config`. This reduces flexibility for users who may have kubeconfig in different locations or use different kubeconfig contexts.

**Affected Files:**
- `tf-k8s/game-2048/main.tf:2`
- `tf-k8s/kuar/main.tf:2`
- `tf-k8s/loki/main.tf:2`
- `tf-k8s/nodeclass/main.tf:2`

**Recommended Fix:**

```hcl
variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}
```

**Impact:** Low - Improves flexibility and user experience

---

## Issue 10: Clarify Promtail Configuration Options

**Labels:** `documentation`, `kubernetes`, `enhancement`

**Title:** Document which Promtail configuration to use

**Description:**

There are two separate Promtail configurations in the repository:
1. `k8s/loki-simple.yaml` - Includes Promtail 2.9.3 as part of all-in-one deployment
2. `k8s/promtail.yaml` - Standalone Promtail 3.0.0 with more advanced configuration

This can be confusing for users trying to decide which to deploy.

**Recommendations:**

1. Add clear documentation in README explaining:
   - When to use `loki-simple.yaml` (quick start, testing)
   - When to use separate `loki` + `promtail.yaml` (production, custom configuration)

2. Consider renaming for clarity:
   - Keep `loki-simple.yaml` as-is (all-in-one)
   - Rename `promtail.yaml` to `promtail-standalone.yaml`

**Files Affected:**
- `README.md`
- Potentially `k8s/promtail.yaml`

**Impact:** Medium - Reduces user confusion

---

## Issue 11: Add Resource Requests and Limits to Kubernetes Deployments

**Labels:** `kubernetes`, `enhancement`, `good-first-issue`

**Title:** Add resource requests/limits to deployments without them

**Description:**

Several Kubernetes deployments are missing resource requests and limits, which is important for:
- Proper pod scheduling
- Preventing resource starvation
- Cluster stability

**Deployments Missing Resources:**

1. `k8s/loki-simple.yaml` - Loki container (line 82-86)
2. `k8s/loki-simple.yaml` - Promtail container (line 188-191)
3. `k8s/game-2048/01-game.yaml` - 2048 game deployment (line 22-27)

**Example Addition:**

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

**Files Affected:**
- `k8s/loki-simple.yaml`
- `k8s/game-2048/01-game.yaml`

**Impact:** Medium - Improves cluster resource management

---

## Issue 12: Resolve TODO Comment in vpc.tf

**Labels:** `terraform`, `cleanup`, `good-first-issue`

**Title:** Resolve or remove TODO comment in vpc.tf

**Description:**

There's an unresolved TODO comment at `vpc.tf:2`:

```hcl
# TODO: simplify or reorganize?
public_subnet_cidrs = [for s in range(0, 3) : cidrsubnet(aws_vpc.default.cidr_block, 8, s)]
```

**Action Needed:**
Either:
1. Simplify/reorganize the code as intended
2. Remove the comment if the current implementation is satisfactory

**Files Affected:**
- `vpc.tf:2`

**Impact:** Low - Code cleanup

---

## Issue 13: Add Namespace to Grafana Manifests

**Labels:** `kubernetes`, `enhancement`, `good-first-issue`

**Title:** Grafana manifests should specify namespace

**Description:**

The Grafana manifests (`grafana.yaml` and `grafana-simple.yaml`) don't specify a namespace in the resource metadata, which means they'll be deployed to the `default` namespace unless specified at apply time.

**Current Behavior:**
Resources created in `default` namespace unless `-n` flag used

**Recommended:**
Add namespace to all resources:

```yaml
metadata:
  name: grafana
  namespace: grafana
```

**Files Affected:**
- `k8s/grafana.yaml`
- `k8s/grafana-simple.yaml`

**Impact:** Low - Improves clarity and namespace isolation

---

## Issue 14: Pin Grafana Version Instead of Using :latest

**Labels:** `kubernetes`, `bug`, `good-first-issue`

**Title:** grafana.yaml uses :latest tag instead of pinned version

**Description:**

`k8s/grafana.yaml:34` uses `grafana/grafana:latest` which is not reproducible and can break unexpectedly when new versions are released.

**Current:**
```yaml
image: grafana/grafana:latest
```

**Recommended:**
```yaml
image: grafana/grafana:11.4.0
```

(This aligns with the pinned version in `grafana-simple.yaml`)

**Files Affected:**
- `k8s/grafana.yaml:34`

**Impact:** Medium - Ensures reproducible deployments

---

## Issue 15: Inconsistent 2048 Game Replica Counts

**Labels:** `kubernetes`, `terraform`, `inconsistency`

**Title:** YAML and Terraform versions of 2048 game have different replica counts

**Description:**

The 2048 game deployment has inconsistent replica counts:
- `k8s/game-2048/01-game.yaml:16` - 5 replicas
- `tf-k8s/game-2048/main.tf:31` - 1 replica

**Recommendation:**
Align replica counts or document why they differ. For a demo, 1-2 replicas is probably sufficient for both.

**Files Affected:**
- `k8s/game-2048/01-game.yaml:16`
- `tf-k8s/game-2048/main.tf:31`

**Impact:** Low - Documentation/consistency issue

---

## Issue 16: NodeClass Configurations Are Inconsistent

**Labels:** `kubernetes`, `terraform`, `bug`

**Title:** NodeClass configurations don't match between YAML and Terraform

**Description:**

There are two NodeClass configurations that are inconsistent:

1. `k8s/nodeclass-ephemeral-storage.yaml`:
   - Name: `private-compute`
   - References non-existent tags like `Name: "eks-cluster-node-sg"`
   - 160Gi ephemeral storage

2. `tf-k8s/nodeclass/main.tf`:
   - Name: `private-compute` (same)
   - Different selector configuration
   - 16Gi ephemeral storage (different)

**Issues:**
- YAML version references tags that don't exist in the Terraform VPC configuration
- Storage sizes differ significantly (160Gi vs 16Gi)
- Both create same resource name which would conflict

**Recommendation:**
- Align the configurations
- Use the actual subnet/SG tags from the Terraform config
- Document which version to use

**Files Affected:**
- `k8s/nodeclass-ephemeral-storage.yaml`
- `tf-k8s/nodeclass/main.tf`

**Impact:** Medium - Potential deployment failures

---

## Issue 17: Add Variable Description

**Labels:** `terraform`, `documentation`, `good-first-issue`

**Title:** Add description to access_entry_principal_arn variable

**Description:**

The `access_entry_principal_arn` variable in `variables.tf:15` is missing a description field.

**Current:**
```hcl
variable "access_entry_principal_arn" {}
```

**Recommended:**
```hcl
variable "access_entry_principal_arn" {
  description = "ARN of the IAM principal (user or role) to grant EKS cluster admin access"
  type        = string
}
```

**Files Affected:**
- `variables.tf:15`

**Impact:** Low - Documentation improvement

---

## Issue 18: Improve VPC Subnet Naming

**Labels:** `terraform`, `enhancement`, `good-first-issue`

**Title:** VPC subnet names use CIDR block instead of descriptive names

**Description:**

Subnet Name tags use the VPC CIDR block (`vpc.tf:28`), which is not very descriptive when viewing resources in AWS Console.

**Current:**
```hcl
Name = "${aws_vpc.default.cidr_block}-public"
```

Results in names like: `10.0.0.0/16-public`

**Recommended:**
```hcl
Name = "${local.name}-public-${each.key}"
```

Results in names like: `hello-eks-auto-public-us-east-1a`

**Files Affected:**
- `vpc.tf:28`

**Impact:** Low - Improves AWS Console resource visibility

---

## Issue 19: Consider Adding VPC Flow Logs

**Labels:** `terraform`, `security`, `enhancement`

**Title:** Add VPC Flow Logs for network traffic auditing

**Description:**

VPC Flow Logs are not enabled, which limits ability to audit network traffic and troubleshoot connectivity issues.

**Recommendation:**

Add VPC Flow Logs:

```hcl
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${local.name}"
  retention_in_days = 7
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${local.name}-vpc-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })
}

resource "aws_flow_log" "vpc" {
  vpc_id          = aws_vpc.default.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
}
```

**Files Affected:**
- New resources in `vpc.tf` or new `flow_logs.tf`

**Impact:** Low - Security/auditing enhancement

---

## Issue 20: Loki StatefulSet References Non-Existent ServiceAccount

**Labels:** `terraform`, `bug`, `good-first-issue`

**Title:** Loki Terraform config references ServiceAccount that isn't created

**Description:**

In `tf-k8s/loki/main.tf:48`, the Loki StatefulSet specifies:

```hcl
service_account_name = "loki"
```

However, this ServiceAccount is never created in the Terraform configuration, which will cause deployment to fail.

**Fix Options:**

1. Create the ServiceAccount:
```hcl
resource "kubernetes_service_account" "loki" {
  metadata {
    name      = "loki"
    namespace = kubernetes_namespace.loki.metadata[0].name
  }
}
```

2. Or use the default ServiceAccount:
```hcl
service_account_name = "default"
```

**Files Affected:**
- `tf-k8s/loki/main.tf:48`

**Impact:** Medium - Deployment will fail

---

## Summary Statistics

**Total Issues:** 20

**By Priority:**
- Critical: 1
- High: 3
- Medium: 9
- Low: 7

**By Category:**
- Security: 4
- Documentation: 5
- Terraform: 7
- Kubernetes: 7
- Cost Optimization: 1
- Consistency: 2

**Good First Issues:** 9

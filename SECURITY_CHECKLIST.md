# CI Security Checklist by Architecture Layer

> Architecture: Spring Boot + JPA + MySQL + S3
> Infrastructure: ALB + TG + ASG + Route 53 + WAF + S3 + ECS (EC2) + RDS MySQL + ECR
> Deployment: Docker image via ECR -> ECS

This checklist defines **what to check** at each architecture layer during CI.
Each check maps to a pipeline job and a DoD DevSecOps guidebook activity.

---

## Checklist Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        CI SECURITY CHECKS                              │
│                                                                        │
│  Layer 1: APPLICATION (Spring Boot)                                    │
│  ├─ SAST: SQL injection, XSS, SSRF, insecure deserialization          │
│  ├─ Dependency CVEs: Spring, Jackson, MySQL connector, AWS SDK         │
│  ├─ Secret scan: DB passwords, AWS keys, API keys in code             │
│  ├─ API security: Auth bypass, mass assignment, broken access          │
│  └─ JPA/Hibernate: HQL injection, lazy loading N+1, entity exposure   │
│                                                                        │
│  Layer 2: CONTAINER (Docker)                                           │
│  ├─ Base image CVEs: JDK runtime vulnerabilities                      │
│  ├─ Dockerfile lint: USER non-root, no secrets in layers              │
│  ├─ Image size: Minimal attack surface (distroless/alpine)            │
│  └─ Runtime config: Read-only FS, dropped capabilities, no privileged │
│                                                                        │
│  Layer 3: ORCHESTRATION (ECS + EC2 + ASG)                              │
│  ├─ Task definition: No privileged, no host networking, logging       │
│  ├─ IAM roles: Least privilege for task role and execution role       │
│  ├─ Secrets injection: Via Secrets Manager, not env vars in task def  │
│  └─ EC2 instances: IMDSv2 enforced, no public IPs, hardened AMI      │
│                                                                        │
│  Layer 4: NETWORK (ALB + WAF + Route 53)                               │
│  ├─ ALB: HTTPS only, TLS 1.2+, security headers                      │
│  ├─ WAF: OWASP rules, rate limiting, geo blocking                    │
│  ├─ Security groups: Least privilege, no 0.0.0.0/0 ingress           │
│  └─ Route 53: DNSSEC, health checks                                  │
│                                                                        │
│  Layer 5: DATA (RDS MySQL + S3)                                        │
│  ├─ RDS: Encryption at rest, SSL in transit, no public access         │
│  ├─ S3: Encryption, block public access, versioning, access logging   │
│  ├─ Backup: Automated backups, retention, cross-region replication    │
│  └─ Access: IAM-only (no static credentials), bucket policy           │
│                                                                        │
│  Layer 6: IAC (Terraform)                                              │
│  ├─ Misconfig scan: tfsec/checkov on all .tf files                    │
│  ├─ Plan review: No destructive changes without approval              │
│  ├─ State security: Encrypted S3 backend, DynamoDB locking            │
│  └─ Drift detection: Planned vs actual infrastructure                 │
│                                                                        │
│  Layer 7: SUPPLY CHAIN                                                 │
│  ├─ SBOM: All components cataloged (app + container + infra)          │
│  ├─ Image signing: cosign + SLSA provenance                          │
│  ├─ ECR scanning: Scan on push enabled                                │
│  └─ Dependency pinning: Gradle lockfile, Dockerfile digest pins       │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Layer 1: APPLICATION (Spring Boot + JPA + MySQL + S3)

### What to Check

| # | Check | Severity | What It Catches | Tool | Pipeline Job |
|---|-------|----------|----------------|------|-------------|
| A-01 | **SQL / HQL Injection** | CRITICAL | JPA `@Query` with string concatenation, native queries without parameterization, JdbcTemplate with raw SQL | Semgrep, SpotBugs | `sast` |
| A-02 | **Insecure Deserialization** | CRITICAL | Jackson polymorphic deserialization, unsafe ObjectMapper config, `@JsonTypeInfo` misuse | Semgrep (p/java) | `sast` |
| A-03 | **Server-Side Request Forgery (SSRF)** | HIGH | S3 presigned URL manipulation, URL parameter passed to HTTP client, S3 key path traversal | Semgrep (p/owasp-top-ten) | `sast` |
| A-04 | **Broken Authentication** | HIGH | Missing `@PreAuthorize`, unprotected endpoints, hardcoded API keys, session fixation | Semgrep, manual review | `sast`, `dast` |
| A-05 | **Mass Assignment** | HIGH | JPA entity used directly as request body (`@RequestBody Document`), missing `@JsonIgnore` on sensitive fields | Semgrep custom rule | `sast` |
| A-06 | **Sensitive Data Exposure** | HIGH | DB credentials in `application.yml`, AWS keys in config, stack traces in responses, entity ID exposure (IDOR) | TruffleHog, Semgrep | `secret-scan`, `sast` |
| A-07 | **Spring Actuator Exposure** | MEDIUM | Actuator endpoints (env, beans, heapdump) exposed without auth, info endpoint leaking version/git details | Semgrep, DAST (ZAP) | `sast`, `dast` |
| A-08 | **Missing Security Headers** | MEDIUM | No CSRF token, missing Content-Security-Policy, X-Frame-Options, X-Content-Type-Options | OWASP ZAP | `dast` |
| A-09 | **Dependency CVEs** | CRITICAL | Known vulnerabilities in Spring Boot, Spring Security, Jackson, MySQL Connector/J, AWS SDK, Log4j | Grype, Snyk | `dependency-scan` |
| A-10 | **S3 Bucket Access** | HIGH | Overly permissive S3 operations, missing input validation on S3 keys (path traversal: `../../etc/passwd`), unsigned URLs | Semgrep custom rule | `sast` |
| A-11 | **JPA/Hibernate Issues** | MEDIUM | N+1 queries (performance), lazy loading outside transaction, entity toString() with sensitive data | SpotBugs, performance test | `sast`, `performance-test` |
| A-12 | **Logging Sensitive Data** | MEDIUM | Logging request bodies with passwords/tokens, logging SQL with parameter values, MDC leaking PII | Semgrep | `sast` |

### Semgrep Custom Rules (Spring Boot Specific)

```yaml
# .semgrep/spring-security.yml
rules:
  # A-05: Detect JPA entity used directly as controller request body
  - id: jpa-entity-as-request-body
    patterns:
      - pattern: |
          @RequestBody $ENTITY $VAR
      - metavariable-regex:
          metavariable: $ENTITY
          regex: ".*(Entity|Model)$"
    message: "JPA entity used directly as @RequestBody. Use a DTO to prevent mass assignment."
    severity: WARNING
    languages: [java]

  # A-10: Detect S3 key path traversal
  - id: s3-key-path-traversal
    pattern: |
      $S3CLIENT.putObject(..., $KEY, ...)
    message: "Validate S3 key does not contain path traversal characters (../ or //)"
    severity: WARNING
    languages: [java]

  # A-07: Detect exposed actuator endpoints
  - id: actuator-endpoints-exposed
    pattern: |
      management.endpoints.web.exposure.include=*
    message: "All actuator endpoints exposed. Restrict to health,info,prometheus only."
    severity: ERROR
    languages: [yaml]
```

---

## Layer 2: CONTAINER (Docker)

### What to Check

| # | Check | Severity | What It Catches | Tool | Pipeline Job |
|---|-------|----------|----------------|------|-------------|
| C-01 | **Base Image CVEs** | CRITICAL | Vulnerabilities in JDK runtime, OS packages (glibc, openssl, zlib) | Trivy | `container-scan` |
| C-02 | **Run as Root** | HIGH | Container running as UID 0 (attacker gains root on container escape) | Hadolint, Trivy | `lint`, `container-scan` |
| C-03 | **Secrets in Image Layers** | CRITICAL | AWS credentials, DB passwords, API keys baked into any layer (including build stages) | Trivy, TruffleHog | `container-scan`, `secret-scan` |
| C-04 | **Unnecessary Packages** | MEDIUM | Build tools (gcc, make), shells (bash), package managers in final image increase attack surface | Trivy misconfiguration | `container-scan` |
| C-05 | **Dockerfile Best Practices** | MEDIUM | Missing HEALTHCHECK, COPY instead of ADD, no `.dockerignore`, mutable base image tag | Hadolint | `lint` |
| C-06 | **Image Size** | LOW | Large images increase pull time and attack surface. Target: < 200MB for JDK app | Custom check | `build` |
| C-07 | **Pinned Base Image** | HIGH | Base image referenced by tag (`:latest`, `:21`) instead of digest (`@sha256:...`). Mutable tags allow supply chain attacks | Hadolint, custom check | `lint` |
| C-08 | **No Privileged Mode** | CRITICAL | ECS task definition must not set `privileged: true` | tfsec/checkov | `iac-scan` |

### Dockerfile Security Requirements

```dockerfile
# REQUIRED checks for this architecture:
# [C-02] USER directive: Must run as non-root (UID >= 1000)
# [C-04] Multi-stage build: Build tools must not be in final image
# [C-05] HEALTHCHECK: Must include health check for ECS
# [C-07] Pinned base: Use digest, not tag
# [C-03] No COPY of secrets: No .env, credentials, or key files
```

---

## Layer 3: ORCHESTRATION (ECS + EC2 + ASG)

### What to Check

| # | Check | Severity | What It Catches | Tool | Pipeline Job |
|---|-------|----------|----------------|------|-------------|
| O-01 | **Task Definition: No Privileged** | CRITICAL | `privileged: true` in container definition allows container escape to host | checkov/tfsec | `iac-scan` |
| O-02 | **Task Definition: Read-Only Root** | HIGH | Writable root filesystem allows attackers to modify application binaries | checkov/tfsec | `iac-scan` |
| O-03 | **Task Role: Least Privilege** | HIGH | Task role with `s3:*` or `*` actions. Should be scoped to specific bucket + actions | checkov/tfsec, IAM Access Analyzer | `iac-scan` |
| O-04 | **Execution Role: Least Privilege** | HIGH | Execution role should only have ECR pull + CloudWatch Logs + Secrets Manager read | checkov/tfsec | `iac-scan` |
| O-05 | **Secrets via Secrets Manager** | CRITICAL | DB password, API keys passed as plaintext `environment` in task def instead of `secrets` (Secrets Manager/SSM) | checkov/tfsec | `iac-scan` |
| O-06 | **Logging Enabled** | HIGH | Task definition missing `logConfiguration` (awslogs driver). Without logs, incidents cannot be investigated | checkov/tfsec | `iac-scan` |
| O-07 | **EC2 IMDSv2 Enforced** | HIGH | Instance metadata v1 allows SSRF attacks to steal IAM credentials. Must require IMDSv2 (hop limit = 1 for containers) | checkov/tfsec | `iac-scan` |
| O-08 | **No Public IP on Instances** | HIGH | ECS EC2 instances should be in private subnets, no public IP assignment | checkov/tfsec | `iac-scan` |
| O-09 | **ASG Launch Template** | MEDIUM | Must use launch template (not launch config), encrypted EBS, latest ECS-optimized AMI | checkov/tfsec | `iac-scan` |
| O-10 | **ECR Image Scanning** | HIGH | ECR repo must have `scan_on_push = true` to catch CVEs post-push | checkov/tfsec | `iac-scan` |
| O-11 | **Container Insights** | MEDIUM | ECS cluster should have Container Insights enabled for monitoring | checkov/tfsec | `iac-scan` |

---

## Layer 4: NETWORK (ALB + WAF + Route 53 + Security Groups)

### What to Check

| # | Check | Severity | What It Catches | Tool | Pipeline Job |
|---|-------|----------|----------------|------|-------------|
| N-01 | **ALB: HTTPS Only** | CRITICAL | HTTP listener without redirect to HTTPS. All traffic must be encrypted in transit | checkov/tfsec | `iac-scan` |
| N-02 | **ALB: TLS 1.2 Minimum** | HIGH | SSL policy allowing TLS 1.0/1.1 (vulnerable to POODLE, BEAST). Use `ELBSecurityPolicy-TLS13-1-2-2021-06` | checkov/tfsec | `iac-scan` |
| N-03 | **ALB: Access Logging** | MEDIUM | ALB access logs disabled. Required for incident investigation and compliance | checkov/tfsec | `iac-scan` |
| N-04 | **ALB: Drop Invalid Headers** | MEDIUM | ALB forwarding invalid HTTP headers enables request smuggling attacks | checkov/tfsec | `iac-scan` |
| N-05 | **WAF: Attached to ALB** | CRITICAL | ALB exposed without WAF protection. WAF must be associated with ALB | checkov/tfsec | `iac-scan` |
| N-06 | **WAF: OWASP Rules Active** | HIGH | Missing AWS Managed Rules: `AWSManagedRulesCommonRuleSet`, `AWSManagedRulesSQLiRuleSet`, `AWSManagedRulesKnownBadInputsRuleSet` | checkov/tfsec | `iac-scan` |
| N-07 | **WAF: Rate Limiting** | HIGH | No rate limiting rule allows DDoS and brute-force attacks | checkov/tfsec | `iac-scan` |
| N-08 | **WAF: Logging** | MEDIUM | WAF logging disabled. Cannot investigate blocked/allowed requests | checkov/tfsec | `iac-scan` |
| N-09 | **Security Group: No 0.0.0.0/0 Ingress** | CRITICAL | Security group allows inbound from any IP. ALB SG: restrict to known CIDRs. ECS/RDS SG: ALB SG only | checkov/tfsec | `iac-scan` |
| N-10 | **Security Group: Restricted Egress** | MEDIUM | ECS instances with unrestricted egress (`0.0.0.0/0:*`). Scope to required destinations (RDS, S3, ECR, CloudWatch) | checkov/tfsec | `iac-scan` |
| N-11 | **Route 53: Health Check** | MEDIUM | DNS record without health check. Failover won't work if primary is unhealthy | checkov/tfsec | `iac-scan` |
| N-12 | **VPC Flow Logs** | HIGH | VPC flow logs disabled. Cannot detect network anomalies or investigate incidents | checkov/tfsec | `iac-scan` |
| N-13 | **Private Subnets for Compute** | HIGH | ECS instances and RDS in public subnets. Must be in private subnets behind NAT | checkov/tfsec | `iac-scan` |

---

## Layer 5: DATA (RDS MySQL + S3)

### What to Check

| # | Check | Severity | What It Catches | Tool | Pipeline Job |
|---|-------|----------|----------------|------|-------------|
| D-01 | **RDS: Encryption at Rest** | CRITICAL | RDS instance without storage encryption (AES-256 via KMS) | checkov/tfsec | `iac-scan` |
| D-02 | **RDS: Encryption in Transit** | HIGH | MySQL SSL not enforced. Parameter group must set `require_secure_transport = 1` | checkov/tfsec | `iac-scan` |
| D-03 | **RDS: No Public Access** | CRITICAL | `publicly_accessible = true` exposes database to internet | checkov/tfsec | `iac-scan` |
| D-04 | **RDS: Multi-AZ** | HIGH | Single-AZ deployment has no failover. Production must be Multi-AZ | checkov/tfsec | `iac-scan` |
| D-05 | **RDS: Automated Backups** | HIGH | Backups disabled or retention < 7 days | checkov/tfsec | `iac-scan` |
| D-06 | **RDS: Deletion Protection** | MEDIUM | `deletion_protection = false` allows accidental database destruction | checkov/tfsec | `iac-scan` |
| D-07 | **RDS: Enhanced Monitoring** | MEDIUM | No enhanced monitoring. Cannot detect OS-level performance issues | checkov/tfsec | `iac-scan` |
| D-08 | **RDS: IAM Auth** | MEDIUM | Using static password instead of IAM database authentication | checkov/tfsec | `iac-scan` |
| D-09 | **S3: Block Public Access** | CRITICAL | `block_public_access` not fully enabled (all four settings must be true) | checkov/tfsec | `iac-scan` |
| D-10 | **S3: Encryption (SSE-KMS)** | HIGH | Bucket without server-side encryption, or using SSE-S3 instead of SSE-KMS | checkov/tfsec | `iac-scan` |
| D-11 | **S3: Versioning** | MEDIUM | Versioning disabled. Cannot recover from accidental deletions or ransomware | checkov/tfsec | `iac-scan` |
| D-12 | **S3: Access Logging** | MEDIUM | Server access logging disabled. Cannot audit who accessed what | checkov/tfsec | `iac-scan` |
| D-13 | **S3: Lifecycle Policy** | LOW | No lifecycle rules. Old versions and incomplete multipart uploads accumulate cost | checkov/tfsec | `iac-scan` |
| D-14 | **S3: Bucket Policy** | HIGH | Bucket policy allowing `s3:*` or `Principal: *`. Must restrict to ECS task role ARN | manual review | PR review |

---

## Layer 6: INFRASTRUCTURE AS CODE (Terraform)

### What to Check

| # | Check | Severity | What It Catches | Tool | Pipeline Job |
|---|-------|----------|----------------|------|-------------|
| I-01 | **IaC Misconfiguration Scan** | HIGH | All checks from Layers 3-5 in a single automated scan across all `.tf` files | checkov, tfsec | `iac-scan` |
| I-02 | **Terraform Plan Review** | HIGH | Unexpected resource deletions, security group changes, IAM policy modifications | `terraform plan` + manual review | `iac-plan` |
| I-03 | **State File Encryption** | CRITICAL | Terraform state stored unencrypted (contains secrets). Backend must use S3 with SSE + DynamoDB lock | Manual verification | Setup |
| I-04 | **No Hardcoded Secrets** | CRITICAL | AWS keys, DB passwords, API keys in `.tf` or `.tfvars` files | TruffleHog, tfsec | `secret-scan`, `iac-scan` |
| I-05 | **Provider Version Pinning** | MEDIUM | Unpinned provider versions can introduce breaking changes or supply chain attacks | tflint | `lint` |
| I-06 | **Module Source Pinning** | MEDIUM | Remote modules referenced without version constraint | tflint | `lint` |
| I-07 | **Terraform Format** | LOW | Unformatted code. `terraform fmt -check` ensures consistency | `terraform fmt` | `lint` |
| I-08 | **Terraform Validate** | MEDIUM | Syntactically invalid configuration | `terraform validate` | `lint` |

---

## Layer 7: SUPPLY CHAIN

### What to Check

| # | Check | Severity | What It Catches | Tool | Pipeline Job |
|---|-------|----------|----------------|------|-------------|
| S-01 | **SBOM Generation** | REQUIRED | Missing bill of materials for deployed artifact | Syft | `sbom-generate` |
| S-02 | **Image Signing** | REQUIRED | Unsigned image deployed to ECS (no proof of origin) | cosign | `sign-and-attest` |
| S-03 | **Build Provenance** | REQUIRED | No cryptographic proof of build environment | SLSA attestation | `sign-and-attest` |
| S-04 | **ECR Scan on Push** | HIGH | CVE discovered after push to ECR, before deployment | ECR native scanning | `iac-scan` (config check) |
| S-05 | **Gradle Dependency Lock** | HIGH | Unlocked dependencies allow silent substitution | `gradle --write-locks` | `build` |
| S-06 | **Dockerfile Base Pin** | HIGH | Mutable base image tag allows supply chain injection | Hadolint | `lint` |
| S-07 | **GitHub Actions Pin** | HIGH | Actions referenced by mutable tag (`@v4`) instead of SHA | Custom check | `lint` |

---

## Pipeline Job <-> Checklist Mapping

| Pipeline Job | Checks Covered | Architecture Layers |
|-------------|---------------|-------------------|
| `secret-scan` | A-06, C-03, I-04 | Application, Container, IaC |
| `lint` | C-02, C-05, C-07, I-05, I-06, I-07, I-08, S-06, S-07 | Container, IaC, Supply Chain |
| `sast` | A-01 through A-05, A-07, A-10, A-11, A-12 | Application |
| `unit-test` | A-01, A-04, A-05 (via test coverage) | Application |
| `build` | C-06, S-05 | Container, Supply Chain |
| `dependency-scan` | A-09 | Application |
| `container-scan` | C-01, C-02, C-03, C-04, C-08 | Container |
| `sbom-generate` | S-01 | Supply Chain |
| `iac-scan` | O-01 through O-11, N-01 through N-13, D-01 through D-14, I-01, I-04 | Orchestration, Network, Data, IaC |
| `iac-plan` | I-02 | IaC |
| `integration-test` | A-01, A-04 (runtime validation) | Application |
| `e2e-test` | A-04, A-08 (user-visible auth/security) | Application, Network |
| `dast` | A-04, A-07, A-08, N-01, N-02 | Application, Network |
| `performance-test` | A-11 (N+1 queries under load) | Application |
| `sign-and-attest` | S-02, S-03 | Supply Chain |

---

## Severity Response Matrix

| Severity | Pipeline Action | Response SLA | Example |
|----------|----------------|-------------|---------|
| **CRITICAL** | Block pipeline, fail immediately | Fix before merge | SQL injection, secrets in code, public RDS |
| **HIGH** | Block pipeline, fail on threshold | Fix within 7 days | Missing encryption, overly permissive IAM |
| **MEDIUM** | Warning, don't block | Fix within 30 days | Missing access logging, no deletion protection |
| **LOW** | Info only | Fix when convenient | Image size, missing lifecycle policy |

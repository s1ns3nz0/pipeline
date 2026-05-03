# DevSecOps Pipeline Workflow v2 - Best Practices

> Unified workflow integrating DoD Enterprise DevSecOps Activities & Tools Guidebook v2.5,
> DORA 5 Metrics (Accelerate State of DevOps Report), SRE operational tooling,
> and NIST SP 800-218 (SSDF) / SP 800-53 controls.
>
> **Revision**: v2.0 - Addresses supply chain security, Zero Trust, secrets management,
> network security, observability tracing, disaster recovery, and pipeline self-defense.

---

## Architecture Overview

```
                     CONTINUOUS SECURITY + DORA METRICS FEEDBACK
  ┌──────────────────────────────────────────────────────────────────────────────┐
  │                                                                              │
  │   ┌──────────────────────────────────────────────────────────────────────┐   │
  │   │                    ZERO TRUST LAYER                                  │   │
  │   │  Identity (IdP/SSO) | mTLS | RBAC/ABAC | Signed Commits | MFA      │   │
  │   └──────────────────────────────────────────────────────────────────────┘   │
  │                                                                              │
  ▼                                                                              │
┌──────┐  ┌───────┐  ┌───────┐  ┌──────┐  ┌───────┐  ┌───────┐  ┌──────┐       │
│ PLAN │─▶│DEVELOP│─▶│ BUILD │─▶│ TEST │─▶│RELEASE│─▶│DELIVER│─▶│DEPLOY│       │
└──────┘  └───────┘  └───────┘  └──────┘  └───────┘  └───────┘  └──────┘       │
  ▲                                                                  │          │
  │         ┌──────────────────────────────────────────────────┐      │          │
  │         │              SEC (All Phases)                    │      │          │
  │         │  Threat Modeling | SAST | DAST | SBOM | IAST     │      │          │
  │         │  Risk Assessment | Compliance | RASP | WAF       │      │          │
  │         │  Secrets Mgmt | Network Policy | Container Sec   │      │          │
  │         └──────────────────────────────────────────────────┘      │          │
  │                                                                  ▼          │
┌────────┐  ┌───────┐  ┌───────┐                              ┌──────────┐     │
│FEEDBACK│◀─│MONITOR│◀─│OPERATE│◀─────────────────────────────│  (prod)  │     │
└────────┘  └───────┘  └───────┘                              └──────────┘     │
  │            │           │                                                    │
  │            ▼           ▼                                                    │
  │   ┌──────────────────────────────────────┐                                  │
  │   │         SRE / OBSERVABILITY          │                                  │
  │   │  Metrics: Prometheus                 │                                  │
  │   │  Logs:    ELK / Loki                 │                                  │
  │   │  Traces:  Jaeger / Tempo             │                                  │
  │   │  Viz:     Grafana                    │                                  │
  │   │  Alerts:  PagerDuty / Alertmanager   │                                  │
  │   │  IaC:     Terraform / Ansible        │                                  │
  │   └──────────────────────────────────────┘                                  │
  │                                                                              │
  │   ┌──────────────────────────────────────┐                                  │
  │   │     PIPELINE SELF-DEFENSE LAYER      │                                  │
  │   │  Runner Hardening | Hermetic Builds  │                                  │
  │   │  Pipeline-as-Code Integrity          │                                  │
  │   │  Secrets Vault | Audit Trail         │                                  │
  │   └──────────────────────────────────────┘                                  │
  └─────────────────────────────────────────────────────────────────────────────┘
                        DORA METRICS MEASUREMENT LAYER
            (Deployment Freq | Lead Time | Change Fail Rate |
             MTTR | Reliability)
```

---

## Cross-Cutting Concerns (Apply to ALL Phases)

These five architectural layers are not phase-specific. They wrap the entire pipeline and must be in place before any phase is considered secure.

### CC-1: Zero Trust & Identity

| Control | Implementation | Tools |
|---------|---------------|-------|
| SSO / IdP for all pipeline tools | Centralized identity provider | Okta, Keycloak, Azure AD |
| MFA enforcement | Required on source control, CI/CD, artifact repos, cloud console | IdP-enforced, hardware keys (YubiKey) |
| Signed commits | GPG or SSH signing required; reject unsigned commits via branch protection | Git + GPG/SSH, GitHub/GitLab branch rules |
| RBAC / ABAC | Least-privilege for all service accounts and human users | OPA/Gatekeeper, cloud IAM policies |
| Separation of duties | Developers cannot approve their own PRs; deploy approval != author | Branch protection rules, CI/CD policy |
| Short-lived credentials | No long-lived API keys; use OIDC federation for CI/CD | GitHub OIDC, Workload Identity, IRSA |
| Break-glass procedures | Documented emergency access with automatic audit + expiry | PIM (Privileged Identity Management), audit logs |
| Bi-directional auth / mTLS | Service-to-service authentication | Service mesh (Istio, Linkerd), cert-manager |

### CC-2: Secrets Management

| Control | Implementation | Tools |
|---------|---------------|-------|
| Centralized secrets vault | All secrets stored in vault, never in code, env vars, or CI config | **HashiCorp Vault**, AWS Secrets Manager, Azure Key Vault, GCP Secret Manager |
| Dynamic secrets | Database creds, API keys generated on-demand with TTL | Vault dynamic secrets engines |
| Secret rotation | Automated rotation on schedule + on compromise | Vault, cloud-native rotation (AWS, GCP, Azure) |
| Sealed secrets for GitOps | Encrypt secrets in Git for Kubernetes consumption | Bitnami Sealed Secrets, SOPS + age/KMS |
| CI/CD secret injection | Secrets injected at runtime, never baked into images or artifacts | Vault Agent, External Secrets Operator, CI native secret stores |
| Pre-commit secret scan | Block commits containing secrets before they reach remote | **GitGuardian**, TruffleHog, detect-secrets (pre-commit hook) |
| Secret leak response | Automated revocation + rotation when a secret is detected in history | GitGuardian incident workflow, Vault revocation API |

### CC-3: Network Security

| Control | Implementation | Tools |
|---------|---------------|-------|
| WAF (Web Application Firewall) | Protect public-facing applications from OWASP Top 10 | AWS WAF, Cloudflare WAF, ModSecurity |
| API Gateway security | Rate limiting, auth, request validation at the edge | Kong, AWS API Gateway, Apigee |
| Kubernetes Network Policies | Default-deny ingress/egress per namespace | Calico, Cilium, native K8s NetworkPolicy |
| Service mesh / mTLS | Encrypt all east-west traffic, enforce identity-based access | Istio, Linkerd, Consul Connect |
| Ingress/egress controls | Whitelist outbound traffic from build environments | Network policies, firewall rules, proxy (Squid) |
| Micro-segmentation | Isolate workloads by security zone | Cloud VPC/subnet design, Cilium, NSX |
| DDoS protection | Volumetric and application-layer protection | Cloud-native (AWS Shield, Cloudflare), CDN |

### CC-4: Data Protection & Privacy

| Control | Implementation | Tools |
|---------|---------------|-------|
| Encryption at rest | All data stores, disks, backups encrypted | Cloud KMS, LUKS, Vault Transit |
| Encryption in transit | TLS 1.2+ everywhere, mTLS for internal | cert-manager, Let's Encrypt, service mesh |
| Key management | Centralized KMS with rotation and audit | AWS KMS, GCP Cloud KMS, Azure Key Vault, Vault Transit |
| Data classification | Label data by sensitivity (public, internal, confidential, restricted) | Policy + tooling (BigID, Collibra) |
| PII/PHI handling | Masking, tokenization, or encryption for sensitive fields | Vault Transform, dynamic data masking |
| Database credential rotation | Automated rotation via vault, no static DB passwords | Vault database secrets engine |
| Backup encryption | All backups encrypted with separate key hierarchy | Velero + KMS, cloud-native backup encryption |

### CC-5: Pipeline Self-Defense

| Control | Implementation | Tools |
|---------|---------------|-------|
| CI/CD runner hardening | Ephemeral runners, minimal images, no persistent state | GitHub Actions ephemeral runners, Kubernetes-based runners |
| Hermetic / reproducible builds | Pin all dependencies, no network access during build | Bazel, Nix, Docker multi-stage with locked deps |
| Pipeline-as-code integrity | Changes to CI config require same review + approval as application code | CODEOWNERS on `.github/workflows/`, `Jenkinsfile`, etc. |
| Third-party action pinning | Pin all CI actions/plugins to SHA, not mutable tags | `uses: actions/checkout@<sha>` not `@v4` |
| Pipeline audit trail | Immutable log of who triggered what, when, with what inputs | CI/CD native audit logs, SIEM ingestion |
| Build provenance attestation | Cryptographic proof of where/how an artifact was built | SLSA framework, in-toto, Sigstore |
| Runner network isolation | Build runners cannot reach production, only artifact repos | Network policies, VPC segmentation |
| Separation of CI and CD | Build environment cannot deploy; deploy environment pulls from artifact repo | Separate pipelines, ArgoCD pull-based GitOps |

---

## DORA 5 Metrics Integration

Source: DORA / Accelerate State of DevOps Report (Google Cloud). The five metrics provide an objective, research-backed way to measure software delivery performance. They are team- and application-level metrics.

> **Caution**: Metrics can be gamed. Deployment frequency without quality gates is just deploying broken code faster. Always pair DORA metrics with quality and security gates. Never use DORA metrics as individual performance measures - they are team signals.

| Metric | Definition | Measurement Point | Low | Medium | High | Elite |
|--------|-----------|-------------------|-----|--------|------|-------|
| **Deployment Frequency** | How often code deploys to prod | Deploy phase | < 1/month | 1/month - 1/week | 1/day - 1/week | On-demand (multiple/day) |
| **Lead Time for Changes** | Commit to running in prod | Develop -> Deploy | > 6 months | 1-6 months | 1 day - 1 week | < 1 hour |
| **Change Failure Rate** | % of deploys causing failure | Monitor/Feedback | 46-60% | 16-30% | 0-15% | 0-5% |
| **Mean Time to Restore** | Time to recover from failure | Operate/Monitor | > 6 months | 1 day - 1 week | < 1 day | < 1 hour |
| **Reliability** | Performance against SLO targets | Monitor continuously | N/A | N/A | N/A | Meets/exceeds |

### Anti-Gaming Controls

| Gaming Vector | Mitigation |
|--------------|-----------|
| Deploy frequently with feature flags hiding broken code | Measure *user-facing* deployment frequency; track flag debt |
| Count rollbacks as "fast MTTR" | Separate rollback-from-failure vs. planned rollback metrics |
| Define lenient SLOs to always "meet" reliability | SLOs must be user-meaningful; review with stakeholders quarterly |
| Skip tests to reduce lead time | Quality gates are non-negotiable; lead time includes gate time |
| Reclassify failures as "expected" to lower CFR | Define failure criteria upfront; automated classification from incidents |

### Phase Mapping

- **Plan**: Cycle time (backlog item created -> dev starts)
- **Develop -> Build -> Test**: Lead time (commit -> artifact ready)
- **Release -> Deploy**: Deployment frequency + change failure rate
- **Operate -> Monitor**: MTTR + reliability (SLI vs. SLO)
- **Feedback -> Plan**: Metrics feed priority decisions; error budgets gate velocity

---

## Phase 1: PLAN

### Activities

| Activity | Baseline | Description | Tools | SSDF |
|----------|----------|------------|-------|------|
| Change management planning | REQUIRED | Plan the change control process | Jira, GitLab Issues, Azure Boards | PO.1.1, PS.1.1, PS.3.1 |
| Configuration identification | REQUIRED | Discover/input configuration items into CMDB | ServiceNow CMDB, Netbox | PO.2.1, PS.1.1, PW.2.1 |
| Configuration management planning | REQUIRED | Plan CM control process, identify config items | Jira + Confluence | PO.3.1, PO.3.3, PO.4.1 |
| Database design | PREFERRED | Data modeling, DB selection, deployment topology | Draw.io, dbdiagram.io, pgModeler | PO.1.2, PO.3.1, PW.1.1 |
| Design review | PREFERRED | Review and approve plans and documents | Confluence, team collaboration | PO.1.2, PW.1.2, PW.2.1 |
| DevSecOps process design | REQUIRED | Design project-specific pipelines and workflows | Draw.io, Miro, Lucidchart | PO.1.1 |
| Documentation version control | REQUIRED | Track design changes | Confluence, GitBook, Notion | PO.1.1, PO.1.2, PO.1.3 |
| IaC deployment | REQUIRED | Deploy infrastructure via code | **Terraform**, Pulumi, CloudFormation | PO.3.2, PO.3.3 |
| Mission-Based Cyber Risk Assessment | REQUIRED | NIST 800-53 RMF risk assessment | eMASS, Xacta, NIST RMF tools | PW.7.2, RV.1.1 |
| Project/Release planning | REQUIRED | Task management, release planning | Jira, Azure DevOps, Linear | PS.3.1, PS.3.2 |
| Project team onboarding planning | REQUIRED | Plan onboarding, access control policy | IdP + RBAC provisioning | PO.2.1, PO.2.2, PO.2.3 |
| Risk management | REQUIRED | Risk assessment including supply chain | NIST RMF tools, Archer | PO.1.2, PO.3.1 |
| Software requirement analysis | REQUIRED | Gather requirements from all stakeholders | Jira, Doors, Jama Connect | PO.1.1, PO.1.2 |
| System design | REQUIRED | Design system architecture | Lucidchart, Enterprise Architect | PO.1.1, PO.1.2 |
| Test audit | REQUIRED | Audit who tests what, when, results | TestRail, Allure | PO.2.1, PS.2.1, PW.1.2 |
| Test plan | REQUIRED | Plan testing and acceptance criteria | TestRail, Zephyr, qTest | PO.1.1, PO.1.2, PW.8.1 |
| Threat modeling | PREFERRED | Identify threats, weaknesses, mitigations | Microsoft Threat Modeling Tool, OWASP Threat Dragon, IriusRisk | PW.1.1, PW.2.1 |

### DORA Alignment
- Track **lead time** from requirement creation to development start
- Use planning tools that provide cycle-time analytics (Jira velocity, Linear cycles)

---

## Phase 2: DEVELOP

### Activities

| Activity | Baseline | Description | Tools | SSDF |
|----------|----------|------------|-------|------|
| Application code development | PREFERRED | Application coding | IDE (VS Code, IntelliJ) | PO.1.2, PO.3.1 |
| Code commit | REQUIRED | Commit signed source to version control | Git (GitHub, GitLab, Bitbucket) + GPG signing | PS.1.1, PW.4.4 |
| Code commit logging | REQUIRED | Log and analyze commits for insider threat | GitGuardian, git-secrets | PO.3.1, PO.5.1 |
| Code commit scan | REQUIRED | Pre-push secret/sensitive data scanning | **GitGuardian**, TruffleHog, detect-secrets | RV.1.2 |
| Code review | PREFERRED | Peer review all source code (pair programming counts) | GitHub PR Reviews, GitLab MRs, Gerrit | PW.7.1, PW.7.2 |
| Documentation | REQUIRED | Implementation and API documentation | Swagger/OpenAPI, Javadoc, Sphinx | PO.1.1, PW.7.2 |
| Security code development | REQUIRED | Security policy enforcement coding | IDE with security plugins | PO.1.2, PW.5.1 |
| Static analysis | REQUIRED | SAST - examine code for logic/security issues | **SonarQube**, Semgrep, Checkmarx | RV.1.2, RV.2.1, RV.3.1 |
| Static code scan before commit | REQUIRED | IDE-level security scanning | ESLint Security, Semgrep, IDE plugins | PW.7.1, PW.7.2 |
| Unit test | REQUIRED | Automated unit test execution | Jest, pytest, JUnit, Go test | PW.8.1, PW.8.2 |
| Component test | PREFERRED | Closed-box testing of program behavior | Test suites + coverage tools | RV.8.1, RV.8.2 |
| Database Component Test | REQUIRED | Black-box database behavior testing | DbUnit, pgTAP, tSQLt | RV.8.1, RV.8.2 |
| Database development | PREFERRED | Implement data model, triggers, views, test scripts | Migration tools (Flyway, Alembic) | PO.3.1 |
| Dynamic analysis | PREFERRED | Run code and examine outcome (fuzzing) | AFL, go-fuzz, libFuzzer | RV.1.2, RV.2.1 |
| Functional test | REQUIRED | Verify code meets requirements | Selenium, Cypress, Playwright | PW.8.1, PW.8.2 |
| Infrastructure code development | PREFERRED | IaC and orchestration coding | **Terraform**, **Ansible**, Helm charts | PO.5.1, PW.8.2 |
| Service functional test | PREFERRED | Unit + functional test on services | Service test tools (Pact, Hoverfly) | PW.8.1, PW.8.2 |
| Test development | REQUIRED | Develop test procedures, data, scripts | IDE + test frameworks | PW.9.1, PW.8.2 |

### DORA Alignment
- Measure commit-to-build time as part of **lead time for changes**
- Trunk-based development + small batch sizes improve **deployment frequency**
- Signed commits + branch protection enforce **change failure rate** reduction

---

## Phase 3: BUILD

### Activities

| Activity | Baseline | Description | Tools | SSDF |
|----------|----------|------------|-------|------|
| Build | REQUIRED | Compile and link source (hermetic where possible) | Maven, Gradle, Make, npm, Docker build, Bazel | PO.3.1, PO.3.2 |
| Build configuration control & audit | REQUIRED | Track build results, SAST reports, go/no-go decision | Jenkins, GitLab CI, GitHub Actions, ArgoCD | PS.3.2 |
| Store artifacts | REQUIRED | Store versioned, signed artifacts | **JFrog Artifactory**, Nexus, GitHub Packages, Harbor | PO.3.1, PO.3.3 |
| Dependency vulnerability checking | REQUIRED | Scan open-source dependencies for known CVEs | **Snyk**, OWASP Dependency-Check, Dependabot, Grype | PO.3.1, PW.4.4, RV.1.1 |
| Static application security test (SAST) | REQUIRED | Full SAST on software system | **SonarQube**, Checkmarx, Semgrep | PO.3.1, PO.4.1 |
| API Security Tests | REQUIRED | Test API compliance with security requirements | Postman, OWASP ZAP, Burp Suite | PO.3.2, PW.1.3, PW.4.4 |
| Component Test | REQUIRED | Black-box component testing | JUnit, pytest, Mocha | RV.8.1, RV.8.2 |
| Regression Test | REQUIRED | Re-run functional & non-functional tests | Test suite (CI-triggered) | RV.8.1, RV.8.2 |
| Software Integration Test | REQUIRED | Test combined modules | Robot Framework, Cypress | RV.8.1, RV.8.2 |
| System Test | PREFERRED | Test complete system with external dependencies | Selenium Grid, Cypress | PW.8.1, PW.8.2 |
| Release packaging | REQUIRED | Package artifacts with checksums & digital signatures | Docker, Helm, **cosign (Sigstore)** | PS.2.1, PS.3.1 |
| Build provenance attestation | REQUIRED | Cryptographic proof of build origin | **SLSA**, in-toto, Sigstore | PS.2.1, PS.3.2 |
| SBOM Software Composition Analysis | REQUIRED | Analyze provenance of all components | **Syft**, **Grype**, CycloneDX, SPDX tools | PS.3.2 |

### CI Pipeline Definition

```yaml
# CI Pipeline Structure
stages:
  - pre-flight          # verify signed commit, branch protection
  - lint-and-sast       # SonarQube / Semgrep
  - build               # compile (hermetic, pinned deps)
  - unit-test           # run unit + component tests
  - dependency-scan     # Snyk / Grype
  - container-scan      # Trivy / Grype on container image
  - sbom-generation     # Syft -> CycloneDX
  - provenance          # SLSA provenance attestation
  - integration-test    # integration + API tests
  - artifact-sign       # cosign sign artifact + SBOM
  - artifact-publish    # push to Artifactory / Harbor

quality-gates:                           # ALL must pass to proceed
  sast-findings:     "zero critical/high"
  dependency-vulns:  "zero critical"
  container-vulns:   "zero critical"
  unit-test-pass:    "100%"
  unit-test-coverage: ">= 80%"
  sbom-generated:    true
  provenance-signed: true
  artifact-signed:   true
  secrets-detected:  "zero"

runner-security:
  ephemeral:         true                # destroy after each job
  network-isolated:  true                # no access to prod
  privileged:        false               # no Docker-in-Docker privilege
  actions-pinned:    "sha-only"          # no mutable tags
```

### DORA Alignment
- Automate everything to minimize **lead time for changes**
- Quality gates directly reduce **change failure rate**
- Hermetic builds + provenance attestation ensure reproducibility

---

## Phase 4: TEST

### Activities

| Activity | Baseline | Description | Tools | SSDF |
|----------|----------|------------|-------|------|
| System Test | REQUIRED | Test entire system as a whole | Selenium Grid, Cypress, k6 | RV.8.1, RV.8.2 |
| Functional Test | REQUIRED | Verify functional requirements | Cucumber, Robot Framework | PW.8.1, PW.8.2 |
| Performance Test | PREFERRED | Load, stress, scalability testing | **k6**, Gatling, JMeter, Locust | PO.3.1, PO.3.2 |
| Regression Test | REQUIRED | Confirm no adverse effects from changes | CI-triggered test suites | PW.4.4, PW.7.2 |
| Compliance Scan | REQUIRED | License + regulatory compliance audit | FOSSA, Black Duck, OpenSCAP | RV.1.2 |
| Dynamic Application Security Test (DAST) | PREFERRED | Test running application for vulnerabilities | **OWASP ZAP**, Burp Suite, Nuclei | RV.1.2, RV.2.1 |
| Interactive Application Security Test (IAST) | PREFERRED | Runtime security analysis during testing | Contrast Security, Hdiv | PO.4.1, PS.2.1 |
| Manual Security Test (Penetration Test) | REQUIRED | Authorized simulated cyber-attacks | Metasploit, Burp Suite Pro, Kali toolkit | PO.4.1, PS.2.1 |
| Database Security Test | PREFERRED | Security scan of database layer | DbProtect, sqlmap (authorized) | PW.8.1, PW.9.2 |
| Service Security Test | REQUIRED | Security scan of services | OWASP ZAP, Nuclei | PO.3.1, PO.3.2 |
| SBOM Composition Analysis | REQUIRED | Verify component provenance per release | Syft, Grype, CycloneDX | PS.3.2 |
| Acceptance Test | REQUIRED | Validate user acceptance criteria | Cucumber, FitNesse | PW.8.1, PW.8.2 |
| Suitability Test | PREFERRED | Accessibility, usability, failover, recovery | Pa11y, Lighthouse, Chaos Toolkit | n/a |
| Test Audit | REQUIRED | Track who tests what, when, results | TestRail, Allure | PO.2.1, PW.1.2 |

### Test Stages (Progressive)

```
Development:     unit test, component test, SAST (in Build phase)
System Test:     DAST, IAST, integration test, system test
Pre-Production:  manual security test, performance test, regression test,
                 acceptance test, container policy enforcement, compliance scan
Production:      operational test & evaluation with mission users
All Stages:      test audit
```

### DORA Alignment
- Thorough automated testing reduces **change failure rate**
- Fast, parallelized test suites reduce **lead time for changes**
- Performance tests establish baselines for **reliability** SLOs

---

## Phase 5: RELEASE

### Activities

| Activity | Baseline | Description | Tools | SSDF |
|----------|----------|------------|-------|------|
| Release go/no-go decision | REQUIRED | Automated gate based on all test/scan results | CI/CD orchestrator | PW.2.1, RV.3.4 |
| SBOM Composition Analysis | REQUIRED | Final provenance check for all components | Syft, CycloneDX | PS.3.2 |
| Software Factory Risk Continuous Monitoring | REQUIRED | Monitor factory controls, alert on anomalies | ISCM dashboards, factory metrics | PS.3.2 |
| User Story Review & Demonstration | PREFERRED | Demo completed work, confirm acceptance | Jira, video demos | n/a |
| Development Tests | PREFERRED | Final dev-environment testing | CI test suites | PW.8.1 |
| Developmental Cyber Tests | PREFERRED | Test in dev/ops environments against known CVEs | Pentest + compliance tools | PO.4.1, PS.2.1 |
| Artifacts replication | PREFERRED | Replicate to regional artifact repos | Artifactory replication, Harbor replication | PS.2.1, PS.3.1 |
| Test Audit | REQUIRED | Record who tested what, when, results | TestRail, Allure | PO.2.1, PW.1.2 |

### Release Gate Checklist

```
AUTOMATED GATES (must all pass - no manual override without audit):
  [ ] All unit tests pass
  [ ] Integration tests pass
  [ ] SAST: zero critical/high findings
  [ ] DAST: zero critical findings
  [ ] Dependency scan: zero critical CVEs
  [ ] Container scan: zero critical vulnerabilities
  [ ] Secret scan: zero findings
  [ ] SBOM generated, signed, and published
  [ ] Build provenance attestation (SLSA) attached
  [ ] Compliance scan: pass
  [ ] Performance test: within SLO thresholds
  [ ] Code review: approved (author != approver)
  [ ] Artifacts signed (cosign/Sigstore)
  [ ] Change failure rate trend: acceptable

EXCEPTION PROCESS (when a gate must be overridden):
  [ ] Exception documented in issue tracker
  [ ] Risk owner identified and approved
  [ ] Time-bound remediation plan attached (max 30 days)
  [ ] Exception logged in audit trail
  [ ] Cannot override: secret scan, artifact signing, provenance
```

---

## Phase 6: DELIVER

### Activities

| Activity | Baseline | Description | Tools | SSDF |
|----------|----------|------------|-------|------|
| Configuration Integration Testing | REQUIRED | Test fully integrated system meets requirements | CI/CD + integration test suites | PO.4.1, PS.2.1 |
| Deliver released artifacts | REQUIRED | Push signed artifacts to production artifact repo | Artifactory, Harbor, ECR/GCR | PS.2.1, PS.3.1 |
| Delivery Results Review | REQUIRED | Review release package, configs, recommendations | Automated reports + manual review | PO.3.3, RV.3.2 |
| Operations Team Acceptance | REQUIRED | Ops team validates operational readiness | Runbook verification, healthcheck scripts | PO.4.1, PS.2.1 |
| Operational Cyber Tests | PREFERRED | Test in operational environments | Pentest + compliance tools | PO.4.1, PS.2.1 |
| SBOM Composition Analysis | REQUIRED | Final component verification | Syft, CycloneDX | PS.3.2 |
| Software Factory Risk Continuous Monitoring | REQUIRED | Monitor factory controls | Monitoring tool suite | PS.3.2 |
| Test Audit | REQUIRED | Record all test activity | TestRail, Allure | PO.2.1, PW.1.2 |

---

## Phase 7: DEPLOY

### Activities

| Activity | Baseline | Description | Tools | SSDF |
|----------|----------|------------|-------|------|
| Infrastructure provisioning automation | PREFERRED | Auto-provision via IaC | **Terraform**, **Ansible**, Pulumi | PO.3.1, PO.5.1 |
| Image provenance verification | REQUIRED | Verify artifact signature + provenance at admission | Kyverno, Connaisseur, cosign verify | PS.3.2, PW.4.1 |
| Compliance Tests | REQUIRED | Verify regulatory/specification compliance | InSpec, OpenSCAP, OPA/Gatekeeper | PO.3.1, PO.3.2 |
| Post-deployment security scan | REQUIRED | Scan deployed infrastructure for misconfig | Prowler, ScoutSuite, Trivy | PO.4.1, PW.4.1 |
| Post-deployment checkout | PREFERRED | Smoke tests and operational validation | Custom scripts, Selenium smoke suite | PW.4.1, PW.4.2 |
| Performance Tests | REQUIRED | Validate production performance | k6, Gatling (canary traffic) | PO.3.1, PO.3.2 |
| Interoperability Tests | REQUIRED | Test system-to-system communication | Custom integration test suites | PO.3.1, PO.3.2 |
| User Evaluation / Feedback | REQUIRED | Collect user feedback post-deploy | Surveys, bug trackers, APM tools | PO.4.2 |
| Test Audit | REQUIRED | Record all test activity | TestRail, Allure | PO.2.1, PW.1.2 |

### Deployment Strategies

| Strategy | Use Case | Rollback Speed | Risk Level |
|----------|----------|---------------|------------|
| **Blue-Green** | Zero-downtime, instant rollback | Immediate (switch LB) | Low |
| **Canary** | Gradual rollout, risk reduction | Fast (route traffic back) | Low |
| **Rolling** | Kubernetes-native, progressive | Moderate (rollback revision) | Medium |
| **Feature Flags** | Decouple deploy from release | Instant (toggle flag) | Low (deploy), varies (flag) |
| **GitOps Pull-Based** | ArgoCD syncs from Git; no push access to prod | Fast (revert Git commit) | Low |

### Container / Kubernetes Security at Deploy

| Control | Tool |
|---------|------|
| Pod Security Standards (Restricted) | Kubernetes Pod Security Admission, OPA/Gatekeeper |
| Image admission control | Kyverno, Connaisseur (verify cosign signatures) |
| Runtime security | **Falco**, Sysdig Secure |
| CIS Kubernetes Benchmark | kube-bench |
| Network policies (default deny) | Calico, Cilium |
| Resource limits enforcement | LimitRange, ResourceQuota |
| Read-only root filesystem | Pod Security Context |

### DORA Alignment
- Automated deployments directly improve **deployment frequency**
- Blue-green/canary + automated rollback reduce **change failure rate** and **MTTR**
- Image provenance verification prevents supply-chain-injected failures

---

## Phase 8: OPERATE

### Activities

| Activity | Baseline | Description | Tools |
|----------|----------|------------|-------|
| Business Operations | REQUIRED | Manage resource usage and billing | Kubecost, CloudHealth, Datadog cost analytics |
| Capacity Management | PREFERRED | Manage CSP service capacity | Kubernetes HPA/VPA, AWS Auto Scaling, Karpenter |
| Chaos Engineering | PREFERRED | Fault injection to test resilience | **Litmus**, Gremlin, Chaos Toolkit |
| Cyber OT&E | REQUIRED | Evaluate operational effectiveness in contested cyber | Purple team exercises |
| Logging | REQUIRED | Log all system events | ELK Stack, **Datadog**, Fluentd, Loki |
| Sustainment & Chaos Testing | PREFERRED | Continuous random failure injection | Litmus, Chaos Monkey |
| Roll Forward/Roll Back | PREFERRED | Validate backup/recovery procedures | Velero, database point-in-time recovery |
| Cooperative & Adversarial Tests | AS REQUIRED | Red/blue/purple team exercises | Caldera, Atomic Red Team |
| Persistent Cyber Operations Tests | AS REQUIRED | Continuous cybersecurity assessment | Continuous pentest platforms |

### SRE Practices Integration

| SRE Practice | Implementation | Tools |
|-------------|---------------|-------|
| **SLO/SLI Definition** | Define SLIs (latency, availability, throughput) and SLO targets per service | Prometheus + **Sloth** or **Pyrra** (SLO controllers) |
| **Error Budgets** | Remaining budget = SLO - actual error rate; when exhausted, freeze features and fix reliability | Prometheus alerting + Grafana burn-rate dashboards |
| **Error Budget Policy** | Documented agreement: what happens when budget burns (feature freeze, oncall focus) | Team policy doc, tracked in Grafana |
| **On-Call Management** | Fair rotation, documented escalation, protected off-hours | **PagerDuty**, Opsgenie, **Incident.io** |
| **Incident Response** | Coordinated response with war rooms and role assignment | PagerDuty + Slack/Teams, Rootly, Incident.io |
| **Blameless Post-Mortems** | After every SEV1/SEV2: timeline, root cause, action items, no blame | Post-mortem templates in Confluence/Notion |
| **Runbooks** | Standardized operational procedures for every alert | Confluence / Notion / Git-versioned markdown |
| **Toil Reduction** | Identify and automate repetitive operational work; target < 50% toil | **Ansible** automation, custom tooling |
| **Capacity Planning** | Predict and prevent resource exhaustion | **Datadog** / Grafana forecasting |

### Disaster Recovery & Business Continuity

| Control | Implementation | RTO/RPO Target |
|---------|---------------|----------------|
| Multi-region deployment | Active-passive or active-active across regions | RTO: < 1 hour |
| Database replication | Synchronous or async replication to standby | RPO: < 5 minutes |
| Backup schedule | Automated daily full + continuous WAL/binlog | RPO: < 1 hour |
| Backup verification | Weekly automated restore test to isolated environment | N/A (validation) |
| DR runbook | Documented, tested quarterly | N/A (process) |
| Failover testing | Automated failover test monthly | RTO: < 15 min (automated) |
| Immutable backups | Backup storage with object lock / WORM | Ransomware protection |

| DR Tool | Purpose |
|---------|---------|
| **Velero** | Kubernetes backup and restore |
| Cloud-native snapshots | EBS snapshots, Cloud SQL backups, Azure disk snapshots |
| Database replication | PostgreSQL Patroni, MySQL Group Replication, MongoDB Atlas |
| DNS failover | Route 53 health checks, Cloudflare load balancing |

---

## Phase 9: MONITOR

### Activities

| Activity | Baseline | Description | Tools | SSDF |
|----------|----------|------------|-------|------|
| Asset Inventory (SBOMs) | REQUIRED | Inventory IT assets continuously | ServiceNow, Netbox + Syft | PS.3.2, PW.4.1 |
| Compliance Monitoring (COTS) | REQUIRED | Monitor COTS compliance against STIGs | OpenSCAP, Compliance as Code | PO.3.1 |
| Compliance Monitoring (resources) | REQUIRED | Monitor cloud resources against NIST SP 800-53 | Prowler, AWS Config, Azure Policy | PO.3.1, PO.3.2 |
| Database monitoring & security auditing | PREFERRED | Monitor database performance and security | pganalyze, Datadog DBM | PO.3.1, PO.3.2 |
| Log Analysis & Auditing | REQUIRED | Filter, aggregate, correlate, analyze logs | **ELK Stack**, Splunk, Loki + Grafana | PO.3.1, PO.3.2 |
| Log auditing | REQUIRED | Ensure possession of logs and correct aggregation | Log aggregator + auditing | PO.3.1, PO.3.2 |
| Runtime Application Self-Protection (RASP) | PREFERRED | Runtime attack detection and blocking | Contrast Protect, Imperva RASP | PW.8.2 |
| System configuration monitoring | PREFERRED | Compliance checking and drift detection | **Ansible** + InSpec, AWS Config | PO.3.1, PO.3.2 |
| System performance monitoring | PREFERRED | Monitor hardware, software, network performance | **Prometheus** + **Grafana**, **Datadog** | PO.3.1, PO.3.2 |
| System Security monitoring | REQUIRED | Continuous vulnerability assessment, ISCM | Qualys, Tenable, **Wazuh** (SIEM) | PO.3.1, PO.5.1, RV.1.1 |
| Test Audit | REQUIRED | Track test and security scan results | TestRail, Allure | PO.2.1, PW.1.2 |
| Test configuration audit | PREFERRED | Track test and security scan results over time | Audit dashboards | PO.3.3 |

### Three Pillars of Observability

```
┌─────────────────────────────────────────────────────────────────┐
│                     OBSERVABILITY STACK                          │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              OpenTelemetry (Instrumentation)              │   │
│  │  Auto-instrument apps for metrics, logs, and traces       │   │
│  │  Vendor-neutral, single SDK for all three signals         │   │
│  └────────────┬──────────────┬──────────────┬───────────────┘   │
│               │              │              │                    │
│               ▼              ▼              ▼                    │
│  ┌────────────────┐ ┌──────────────┐ ┌───────────────┐          │
│  │   METRICS      │ │    LOGS      │ │   TRACES      │          │
│  │                │ │              │ │               │          │
│  │  Prometheus    │ │  ELK Stack   │ │  Jaeger       │          │
│  │  (collection   │ │  -OR-        │ │  -OR-         │          │
│  │   + storage)   │ │  Loki        │ │  Tempo        │          │
│  │                │ │  (+ Fluentd/ │ │  (+ Grafana   │          │
│  │  Alertmanager  │ │   Fluent Bit │ │   for viz)    │          │
│  │  (alerting)    │ │   for ship)  │ │               │          │
│  └───────┬────────┘ └──────┬───────┘ └───────┬───────┘          │
│          │                 │                  │                   │
│          ▼                 ▼                  ▼                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                  Grafana (Unified Viz)                     │   │
│  │                                                            │   │
│  │  Dashboards:                                               │   │
│  │  - SLO/SLI + Error Budget Burn Rate                       │   │
│  │  - DORA Metrics (all 5)                                    │   │
│  │  - Infrastructure Health                                   │   │
│  │  - Security Posture                                        │   │
│  │  - Cost Analytics                                          │   │
│  │  - Distributed Trace Explorer                              │   │
│  └─────────────────────────┬────────────────────────────────┘   │
│                            │                                     │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │            Alerting & Incident Response                    │   │
│  │                                                            │   │
│  │  Alertmanager ──▶ PagerDuty / Opsgenie / Incident.io      │   │
│  │                                                            │   │
│  │  - Multi-channel (SMS, email, push, Slack, Teams)         │   │
│  │  - Escalation policies with timeout                        │   │
│  │  - On-call rotation with fair scheduling                   │   │
│  │  - Auto-create incident channels                           │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │            Status Communication                            │   │
│  │  Instatus / Statuspage                                     │   │
│  │  - Public/private status pages                             │   │
│  │  - Automated incident updates from PagerDuty               │   │
│  │  - Historical uptime data + SLA reporting                  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │            Security Monitoring (SIEM/SOAR)                 │   │
│  │  Wazuh / Splunk                                            │   │
│  │  - Log correlation + threat detection rules                │   │
│  │  - Automated response playbooks (SOAR)                     │   │
│  │  - MITRE ATT&CK mapping                                   │   │
│  │  - Compliance dashboards (NIST 800-53, STIGs)             │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### DORA Metrics Dashboard

| Panel | Data Source | Query | Alert Threshold |
|-------|-----------|-------|-----------------|
| Deployment Frequency | CI/CD API (Jenkins/GitLab/ArgoCD) | Deployments per day/week | Below team target |
| Lead Time for Changes | Git + CI/CD timestamps | Commit ts -> deploy ts | > 1 week (warning) |
| Change Failure Rate | Incident tracker + deploy count | Failed deploys / total deploys | > 15% (critical) |
| MTTR | PagerDuty / Incident.io | Incident start -> resolution | > 1 day (critical) |
| Reliability | Prometheus SLO metrics (Sloth/Pyrra) | Error budget remaining % | < 20% budget (warning) |
| Error Budget Burn Rate | Prometheus + Grafana | Budget consumption rate | Fast burn alert |

---

## Phase 10: FEEDBACK

### Activities

| Activity | Baseline | Description | Tools |
|----------|----------|------------|-------|
| Revise Product Backlog | REQUIRED | Update backlog with bugs, improvements, vulnerabilities, performance data, collected metrics | Jira, Azure Boards, Linear |
| User Evaluation / Feedback | REQUIRED | Collect and analyze user evaluations | Surveys, NPS tools, APM user analytics |

### Feedback Loop Integration

```
DORA Metrics Analysis ──────────────┐
                                     │
SRE Post-Mortems + Action Items ────┤
                                     │
Error Budget Status ────────────────┤
                                     ├──▶ Prioritized Backlog ──▶ Next Sprint
Security Scan Findings ────────────┤
                                     │
Vulnerability Remediations ─────────┤
                                     │
User Feedback & Bug Reports ────────┤
                                     │
Performance / Reliability Trends ───┤
                                     │
Pipeline Health Metrics ────────────┘

Decision Framework:
  - Error budget exhausted?  → Freeze features, prioritize reliability
  - Critical CVE discovered? → Patch immediately (out-of-band)
  - DORA regression?        → Investigate root cause in retro
  - SLO breach?             → Trigger incident review process
```

---

## Governance & Audit Trail

### Pipeline Governance

| Control | Implementation |
|---------|---------------|
| Pipeline config changes | Reviewed via PR (CODEOWNERS), same rigor as app code |
| Quality gate overrides | Logged in issue tracker, requires risk owner approval, time-bound (30 days max) |
| Deploy approvals | Automated for staging; manual approval for production (author != approver) |
| Access reviews | Quarterly review of all pipeline tool access; remove stale accounts |
| Audit log retention | Pipeline execution logs retained for compliance period (1-7 years) |
| Change audit | Every production change traceable: who, what, when, why, approved-by |

### Exception Management

| Severity | Process | Max Duration |
|----------|---------|-------------|
| Critical finding override | VP/CISO approval + incident created + daily review | 7 days |
| High finding override | Engineering manager approval + ticket created | 30 days |
| Medium finding deferral | Team lead approval + ticket in backlog | 90 days |
| Non-overridable | Secrets in code, unsigned artifacts, missing provenance | Never |

---

## Recommended Tool Stack

### Selection Guidance

> Choose **one** tool per category. The table below provides tiers:
> - **Open Source First**: For teams with limited budget or strong OSS preference
> - **Commercial**: For teams needing enterprise support, SLAs, and managed services
> - Do not adopt tools from multiple tiers in the same category without clear justification

### Core Pipeline

| Category | Open Source | Commercial | Notes |
|----------|-----------|------------|-------|
| Source Control | GitLab CE | GitHub Enterprise, GitLab EE | Must support branch protection + signed commits |
| CI/CD | GitLab CI, Jenkins, Tekton | GitHub Actions, GitLab EE, CircleCI | Prefer pull-based CD (ArgoCD, Flux) |
| GitOps / CD | **ArgoCD**, Flux | ArgoCD Enterprise | Pull-based; CD env never has push access to prod |
| Artifact Repository | Nexus OSS, **Harbor** | JFrog Artifactory | Must support signing verification |
| IaC | **Terraform** (BSL), OpenTofu | Terraform Cloud, Pulumi Cloud | State file must be encrypted + locked |
| Config Management | **Ansible** | Ansible Automation Platform | Agentless preferred |
| Container Orchestration | Kubernetes | Managed K8s (EKS, GKE, AKS) | CNCF Certified required |

### Security Toolchain

| Category | Open Source | Commercial | Notes |
|----------|-----------|------------|-------|
| Secret Scanning | detect-secrets, TruffleHog | **GitGuardian** | Must run as pre-commit hook + CI |
| SAST | **Semgrep**, SonarQube CE | Checkmarx, Fortify | Pick one; don't run four SAST tools |
| DAST | **OWASP ZAP**, Nuclei | Burp Suite Pro, HCL AppScan | Run against staging, not prod |
| SCA / Dependency | **Grype**, OWASP Dep-Check | **Snyk**, Mend (WhiteSource) | Must scan transitive deps |
| Container Scanning | **Trivy**, Grype | Snyk Container, Prisma Cloud | Scan in CI + admission control |
| SBOM | **Syft** + CycloneDX | Anchore Enterprise | Generate at build, verify at deploy |
| Artifact Signing | **cosign (Sigstore)** | Venafi CodeSign Protect | Non-negotiable for supply chain |
| Build Provenance | **SLSA** + in-toto | - | Target SLSA Level 3 |
| Compliance as Code | OpenSCAP, **InSpec**, OPA | Chef Compliance, Prisma Cloud | Must cover CIS + STIG benchmarks |
| RASP | - | Contrast Protect, Imperva | Optional; adds runtime defense |
| SIEM / SOAR | **Wazuh** | Splunk, Sentinel, Chronicle | Must ingest pipeline + app logs |
| Secrets Management | **HashiCorp Vault** (BSL) | AWS Secrets Mgr, Azure Key Vault | Centralized, dynamic, rotated |
| WAF | ModSecurity | AWS WAF, Cloudflare WAF | Protect public endpoints |
| Runtime Security | **Falco** | Sysdig Secure | Container runtime threat detection |
| Network Policy | Calico, **Cilium** | Cilium Enterprise | Default-deny in all namespaces |
| Service Mesh | **Linkerd**, Istio | Consul Connect | mTLS for east-west traffic |

### SRE / Observability Toolchain

| Category | Open Source | Commercial | Notes |
|----------|-----------|------------|-------|
| Instrumentation | **OpenTelemetry** | Datadog APM agent | OTel is the standard; vendor-neutral |
| Metrics | **Prometheus** + **Alertmanager** | Datadog, New Relic | Prometheus is the K8s standard |
| Logs | **Loki** + Fluent Bit | Datadog Logs, Splunk | Loki is cost-effective for K8s |
| Traces | **Jaeger** or **Tempo** | Datadog APM, Honeycomb | Must have distributed tracing |
| Visualization | **Grafana** | Datadog Dashboards | Grafana unifies all three pillars |
| SLO Management | **Sloth** or **Pyrra** | Nobl9 | Auto-generate Prometheus rules from SLO defs |
| Incident Management | - | **PagerDuty**, Opsgenie, **Incident.io** | Must have escalation + on-call rotation |
| Status Pages | - | **Instatus**, Statuspage | Public + private pages |
| Chaos Engineering | **Litmus**, Chaos Toolkit | Gremlin | Start in staging, graduate to prod |
| Backup & Recovery | **Velero** | Cloud-native backups | Test restores regularly |
| Cost Management | Kubecost (OSS) | CloudHealth, Datadog Cost | Track per-team/service costs |

---

## NIST SSDF Alignment Summary

| SSDF Practice Group | Description | Pipeline Coverage |
|---------------------|------------|-------------------|
| **PO - Prepare the Organization** | Define security requirements, roles, tooling | Plan, Build, Deploy, Monitor |
| **PS - Protect the Software** | Protect code, builds, and releases from tampering | Develop (signed commits), Build (hermetic, signed artifacts), Release (provenance), Deploy (admission control) |
| **PW - Produce Well-Secured Software** | Design, develop, and test software securely | Develop, Build, Test, Release |
| **RV - Respond to Vulnerabilities** | Identify, triage, and remediate vulnerabilities | Test, Monitor, Feedback |

---

## Implementation Maturity Model

### Level 1: Foundation
**Criteria**: Basic automation exists; security is partially manual.

| Area | Requirement | Measurable |
|------|------------|------------|
| CI/CD | Basic pipeline: build, test, deploy | Pipeline exists and runs on every commit |
| Source Control | Version control with branch protection | All code in Git; PRs required |
| Security | Manual security reviews; secret scanning in CI | Secret scan runs; SAST runs (findings may not block) |
| Monitoring | Basic uptime checks | Healthcheck endpoint monitored |
| DORA | Measurement started | Can report deployment frequency |
| SRE | Informal on-call | Someone is reachable |

### Level 2: Intermediate
**Criteria**: Automated security gates; observability in place; DORA tracked.

| Area | Requirement | Measurable |
|------|------------|------------|
| CI/CD | Automated SAST + dependency scan in CI; findings block merge | Zero critical/high findings in main branch |
| IaC | All infrastructure defined as code | No manual infra changes |
| Secrets | Centralized vault; no secrets in code/config | Vault in use; secret scan = zero findings |
| Monitoring | Prometheus + Grafana + log aggregation | Dashboards exist for all services |
| Alerting | PagerDuty on-call rotation | Documented escalation policy |
| DORA | All 5 metrics tracked in dashboard | Dashboard exists and is reviewed weekly |
| SRE | SLOs defined for critical services | SLO documents reviewed quarterly |
| Network | Basic network policies | Default-deny in at least one namespace |

### Level 3: Advanced
**Criteria**: Full DevSecOps pipeline; SRE practices embedded; proactive resilience.

| Area | Requirement | Measurable |
|------|------------|------------|
| Security | Full pipeline: SAST + DAST + IAST + SBOM + container scan | All scans run; all gate on critical |
| Supply Chain | Artifacts signed; SBOM published; SLSA Level 2+ | cosign verify passes for all prod images |
| Compliance | Automated compliance gates (STIGs, CIS, NIST) | Compliance scan in CI; drift detection in prod |
| Chaos | Chaos engineering in pre-production | Monthly chaos experiments with documented results |
| DORA | Metrics drive sprint planning | DORA review in every retro |
| SRE | Error budgets govern release velocity | Feature freeze triggered when budget exhausted |
| Observability | All three pillars (metrics + logs + traces) | Can trace a request end-to-end across services |
| Incident | Automated playbooks for top 5 alerts | Playbook exists and tested for each |
| DR | Documented DR plan; tested quarterly | Successful DR test in last 90 days |

### Level 4: Elite (Target State)
**Criteria**: Continuous ATO; zero-touch deploys; proactive defense.

| Area | Requirement | Measurable |
|------|------------|------------|
| cATO | Continuous Authority to Operate pipeline | ATO evidence auto-generated from pipeline |
| Deploy | Zero-touch deployments with automated rollback | No human in deploy loop; rollback < 5 min |
| DORA | Elite-level across all services | DF: multiple/day, LT: < 1hr, CFR: < 5%, MTTR: < 1hr |
| Supply Chain | SLSA Level 3; provenance verified at admission | Hermetic builds; non-falsifiable provenance |
| Chaos | Proactive chaos engineering in production | Continuous chaos with automatic halt on SLO breach |
| Detection | ML-driven anomaly detection | Anomaly alerts with < 5% false positive rate |
| SRE | Toil < 50%; error budgets; blameless post-mortems | Toil tracked and trending down |
| Zero Trust | Full ZTA: mTLS, SDP, dynamic authorization | Zero implicit trust in network |
| Pipeline | Pipeline self-defense: hermetic, audited, signed | No unapproved pipeline changes possible |

---

## Quick-Start: Minimum Viable Pipeline

For teams starting from scratch, implement in this order. Each step builds on the previous.

```
Phase 1 - Source Control & Identity (Week 1-2)
  1. Git repo + branch protection + signed commits
  2. SSO/MFA for all pipeline tools
  3. RBAC: least-privilege for all accounts

Phase 2 - Basic CI + Security (Week 3-4)
  4. CI pipeline: build + unit test + SAST (Semgrep)
  5. Secret scanning (detect-secrets pre-commit + CI)
  6. Secrets vault (Vault or cloud-native)
  7. Dependency scanning (Grype)

Phase 3 - Containers & Artifacts (Week 5-6)
  8. Container scanning (Trivy)
  9. Artifact signing (cosign)
  10. SBOM generation (Syft)
  11. Artifact repo (Harbor)

Phase 4 - Deploy & Monitor (Week 7-8)
  12. Automated deploy to staging (ArgoCD)
  13. Prometheus + Alertmanager + Grafana
  14. Log aggregation (Loki + Fluent Bit)
  15. PagerDuty on-call rotation

Phase 5 - Advanced Security (Week 9-10)
  16. DAST scanning in staging (OWASP ZAP)
  17. Network policies (default-deny)
  18. Compliance scanning (InSpec or OpenSCAP)
  19. Runtime security (Falco)

Phase 6 - Production & Feedback (Week 11-12)
  20. Production deploy with canary/blue-green
  21. Distributed tracing (Jaeger or Tempo)
  22. SLO definitions (Sloth/Pyrra)
  23. DORA metrics dashboard
  24. Blameless post-mortem process

Then iterate toward Level 3/4:
  → Chaos engineering, IAST, cATO, SLSA Level 3, DR testing
```

---

## Appendix A: Tool Selection Decision Matrix

When choosing between tools in the same category, evaluate against these criteria:

| Criterion | Weight | Question |
|-----------|--------|----------|
| Security posture | High | Does the tool itself have a good security track record? |
| Open standards | High | Does it use open formats (OCI, CycloneDX, SPDX, OpenTelemetry)? |
| Integration | High | Does it integrate with your existing CI/CD and monitoring stack? |
| Community / Support | Medium | Is there active community or commercial support? |
| Cost | Medium | Total cost including license, infra, training, maintenance? |
| Compliance | Medium | Does it satisfy your regulatory requirements (FedRAMP, IL2-5)? |
| Lock-in risk | Low | Can you migrate away if needed? |

## Appendix B: Baseline Classification Reference

Per the DoD guidebook, activities have three baseline levels. This document preserves the original classification.

| Baseline | Meaning | Pipeline Enforcement |
|----------|---------|---------------------|
| **REQUIRED** | Non-negotiable; must be in MVP release | Quality gate: blocks pipeline |
| **PREFERRED** | Aspirational; adopt as ecosystem matures | Quality gate: warning, does not block |
| **AS REQUIRED** | Context-dependent per mission/contract | Configurable gate per project |

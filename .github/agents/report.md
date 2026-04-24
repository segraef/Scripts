# AVM Triage Report for owner `segraef` - 2026-04-24

## Triage summary

```
Total open:              26
Copilot-ready now:       8  (31%)   - mechanical / well-specified, assignable today
Copilot-ready (blocked): 3          - waiting on another in-module issue or PR
Needs owner:             15 (58%)   - design, investigation, or judgement calls
```

### Module issues analysed

| Repo | Open | 🔴 High | 🟡 Medium | ⚪ Low | Copilot-ready now | Copilot-ready (blocked) | Needs owner |
|------|------|---------|-----------|--------|-------------------|-------------------------|-------------|
| app-managedenvironment | 9 | 2 | 6 | 1 | 4 | 1 | 4 |
| aiml-ai-foundry | 10 | 8 | 2 | 0 | 3 | 2 | 5 |
| databricks-workspace | 3 | 3 | 0 | 0 | 0 | 1 | 2 |
| bicep-registry-modules | 4 | 3 | 1 | 0 | 1 | 1 | 2 |
| **Total** | **26** | **16** | **9** | **1** | **8** | **5** | **13** |

---

## All Issues - Flat List (26 total)

| # | Module | Title | Type | Priority | Action | Dependencies / Constraints |
|---|--------|-------|------|----------|--------|---------------------------|
| [#160](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/160) | app-managedenvironment | `log_analytics_destination_type` state drift | bug | 🔴 High | Copilot-ready | @AmeyParle volunteered; patch drafted in thread |
| [#157](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/157) | app-managedenvironment | `metric` deprecated → `enabled_metric` | provider-update | 🟡 Medium | Copilot-ready | Standalone; mechanical rename |
| [#142](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/142) | app-managedenvironment | Retries for sleeping container environments | feature-request | 🟡 Medium | Copilot-ready | Already assigned to Copilot; schema documented |
| [#141](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/141) | app-managedenvironment | `ephemeral` block error with OpenTofu 1.10 | duplicate | 🟡 Medium | **Duplicate → close** | Dup of #139 (owner-labeled) |
| [#139](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/139) | app-managedenvironment | Support OpenTofu 1.9+ | feature-request | 🟡 Medium | Needs design decision | Wait for tofu 1.11 vs add `.tofu` shims; #141 closes as dup |
| [#131](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/131) | app-managedenvironment | Ability to change subnet id | feature-request | 🟡 Medium | Copilot-ready | azapi pattern, upstream spec linked |
| [#126](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/126) | app-managedenvironment | Add `dynamicJsonColumns` in LogAnalyticsConfiguration | feature-request | 🟡 Medium | Copilot-ready *(after 0.3 GA)* | Preview API; owner deferred post-0.3 |
| [#121](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/121) | app-managedenvironment | `publicNetworkAccess` not available | feature-request | 🟡 Medium | **Blocked** | Post-0.3 GA per owner |
| [#25](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/25) | app-managedenvironment | Validation for dapr component name | enhancement | ⚪ Low | Copilot-ready | Good-first-issue; regex validator |
| [#73](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/73) | aiml-ai-foundry | Connection names not unique across projects | bug | 🔴 High | Copilot-ready | Category prefix on 3 `azapi_resource` names |
| [#72](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/72) | aiml-ai-foundry | Cosmos DB SQL role assignments miss 4th (dynamic) collection | bug | 🔴 High | Needs design decision | Cluster B (RBAC); must ship with/before #65 |
| [#65](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/65) | aiml-ai-foundry | Support for user-assigned managed identity | feature-request | 🔴 High | **Blocked** | [SvenAelterman branch](https://github.com/SvenAelterman/terraform-azurerm-avm-ptn-aiml-ai-foundry/tree/svaelter/65-uami-support); align with #72 |
| [#60](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/60) | aiml-ai-foundry | DINE/Modify policy friction | bug/design | 🔴 High | Needs design decision | Cluster A (PE/DNS) |
| [#59](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/59) | aiml-ai-foundry | Multi-region Foundry + PE guidance | bug/design | 🔴 High | Needs design decision | Cluster A (PE/DNS) |
| [#58](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/58) | aiml-ai-foundry | Expose `networkAcls` variable | feature-request | 🔴 High | Copilot-ready | Ship with #56 |
| [#57](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/57) | aiml-ai-foundry | Key-based storage auth used internally | bug | 🔴 High | Needs investigation | Soft-blocks #56/#58 |
| [#56](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/56) | aiml-ai-foundry | Expose `public_network_access_enabled` | feature-request | 🔴 High | Copilot-ready | Ship with #58 |
| [#50](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/50) | aiml-ai-foundry | PE in given resource group | feature-request | 🔴 High | Needs design decision | Cluster A (PE/DNS); segraef assigned |
| [#49](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/49) | aiml-ai-foundry | Optional PE location property | feature-request | 🔴 High | Needs design decision | Cluster A (PE/DNS) |
| [#128](https://github.com/Azure/terraform-azurerm-avm-res-databricks-workspace/issues/128) | databricks-workspace | Support Serverless deployment | feature-request | 🔴 High | Needs design decision | AzApi refactor required per segraef |
| [#125](https://github.com/Azure/terraform-azurerm-avm-res-databricks-workspace/issues/125) | databricks-workspace | `enhanced_security_compliance` block not expected | bug | 🔴 High | Needs investigation | 6 months stale; needs repro |
| [#114](https://github.com/Azure/terraform-azurerm-avm-res-databricks-workspace/issues/114) | databricks-workspace | `default_storage_firewall_enabled` / `access_connector_id` conflict | bug | 🔴 High | **Blocked** | [PR #115](https://github.com/Azure/terraform-azurerm-avm-res-databricks-workspace/pull/115) pending review |
| [#6518](https://github.com/Azure/bicep-registry-modules/issues/6518) | bicep / avm/res/consumption/budget | Fine control for notification thresholds | feature-request | 🟡 Medium | Copilot-ready *(after #6395)* | User supplied full impl; fix pipeline first |
| [#6395](https://github.com/Azure/bicep-registry-modules/issues/6395) | bicep / avm/res/consumption/budget | [Failed pipeline] daily for 4 months | bug | 🔴 High | Needs investigation | Blocks #6518 |
| [#6393](https://github.com/Azure/bicep-registry-modules/issues/6393) | bicep / avm/res/compute/disk | [Failed pipeline] daily for 4 months | bug | 🔴 High | Needs investigation | Blocks #5561 |
| [#5561](https://github.com/Azure/bicep-registry-modules/issues/5561) | bicep / avm/res/compute/disk | Missing `securityProfile` / `securityEncryptionType` | feature-request | 🔴 High | Copilot-ready *(after #6393)* | ConfidentialVM support; fix pipeline first |

**Excluded (false positive):** `bicep-registry-modules#5994` - title says "SQL Database"; body `### Module Name` = `avm/res/sql/server`; `avm/res/network/private-endpoint` appears only in stack trace.

---

## Combined Action Plan

### 🔴 Act now
| Repo | # | Action |
|------|---|--------|
| aiml-ai-foundry | [#57](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/57) | Investigate key-based storage auth (soft-blocks #56/#58) |
| aiml-ai-foundry | [#49](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/49)/[#50](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/50)/[#59](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/59)/[#60](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/60) | Open consolidated PE/DNS design thread (Cluster A) |
| aiml-ai-foundry | [#72](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/72) | Decide RBAC scope (DB-level vs container-level); pair with #65 |
| databricks-workspace | [#125](https://github.com/Azure/terraform-azurerm-avm-res-databricks-workspace/issues/125) | Investigate `enhanced_security_compliance` block (6 months stale) |
| databricks-workspace | [#114](https://github.com/Azure/terraform-azurerm-avm-res-databricks-workspace/issues/114) | Review/merge [PR #115](https://github.com/Azure/terraform-azurerm-avm-res-databricks-workspace/pull/115) |
| bicep-registry-modules | [#6393](https://github.com/Azure/bicep-registry-modules/issues/6393), [#6395](https://github.com/Azure/bicep-registry-modules/issues/6395) | Investigate daily CI failures; fixes unblock #5561 and #6518 |

### 🤖 Copilot-ready batch (pending approval per issue)
| Repo | Issues |
|------|--------|
| app-managedenvironment | [#25](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/25), [#131](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/131), [#142](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/142), [#157](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/157), [#160](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/160); [#126](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/126) *(after 0.3 GA)* |
| aiml-ai-foundry | [#73](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/73); [#58](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/58)+[#56](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/56) *(after #57)* |
| bicep-registry-modules | [#6518](https://github.com/Azure/bicep-registry-modules/issues/6518) *(after #6395)*; [#5561](https://github.com/Azure/bicep-registry-modules/issues/5561) *(after #6393)* |

### 🔗 PR-in-flight - review before assigning Copilot
| Repo | Issue | Note |
|------|-------|------|
| aiml-ai-foundry | [#65](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/65) | [SvenAelterman branch](https://github.com/SvenAelterman/terraform-azurerm-avm-ptn-aiml-ai-foundry/tree/svaelter/65-uami-support) - review and align with #72 fix |
| databricks-workspace | [#114](https://github.com/Azure/terraform-azurerm-avm-res-databricks-workspace/issues/114) | [PR #115](https://github.com/Azure/terraform-azurerm-avm-res-databricks-workspace/pull/115) by reporter - review and merge |

### ⚠️ Duplicates to close (after primary resolves)
| Primary | Close as dup |
|---------|-------------|
| app-managedenvironment [#139](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/139) | [#141](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/141) |

### ⛓️ Ordering / "ship-together" chains
- **aiml-ai-foundry PE/DNS cluster (A):** [#49](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/49) ↔ [#50](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/50) ↔ [#59](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/59) ↔ [#60](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/60) - resolve with one design doc, ship together
- **aiml-ai-foundry RBAC cluster (B):** [#72](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/72) (scope fix) → [#65](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/65) (UMI via external branch)
- **aiml-ai-foundry network exposure pair:** [#57](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/57) (investigate auth) → [#58](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/58) + [#56](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/56) (expose together)
- **app-managedenvironment preview-API cluster:** [#121](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/121), [#126](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/126), [#131](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/131) all depend on 0.3 GA; only #126 safe to plan post-0.3
- **Bicep pipeline gates:** [#6393](https://github.com/Azure/bicep-registry-modules/issues/6393) → [#5561](https://github.com/Azure/bicep-registry-modules/issues/5561) (disk); [#6395](https://github.com/Azure/bicep-registry-modules/issues/6395) → [#6518](https://github.com/Azure/bicep-registry-modules/issues/6518) (budget) - pipeline must be green first

---

## Open questions for you

1. **ai-foundry Cluster A ([#49](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/49)/[#50](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/50)/[#59](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/59)/[#60](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/60)):** open one consolidated design thread I draft for your approval, or handle them individually?
2. **ai-foundry [#72](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/72) vs [#65](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/65) ordering:** confirm we land #72 (Cosmos RBAC scope) before reviewing SvenAelterman's #65 branch to avoid regression.
3. **databricks [#125](https://github.com/Azure/terraform-azurerm-avm-res-databricks-workspace/issues/125):** owner-silent for 6 months with `Immediate Attention` label - ping reporter for a fresh repro or stale-close?
4. **Bicep failed pipelines ([#6393](https://github.com/Azure/bicep-registry-modules/issues/6393)/[#6395](https://github.com/Azure/bicep-registry-modules/issues/6395)):** you investigate directly, or want me to open the linked workflow runs and draft a diagnosis comment?

---

## Next steps

These issues are ready to assign to GitHub Copilot today - scope is clear, no in-module blockers, PR will run against the canonical AVM pipeline:

- [#160](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/160) - `log_analytics_destination_type` state drift
- [#157](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/157) - `metric` → `enabled_metric` rename
- [#131](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/131) - change `subnet_id` via azapi
- [#25](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/25) - Dapr component name validator
- [#73](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/73) - unique connection names across projects
- [#58](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/58) + [#56](https://github.com/Azure/terraform-azurerm-avm-ptn-aiml-ai-foundry/issues/56) - expose `networkAcls` and `public_network_access_enabled` (assign **#58**, group #56 into the same PR)

[#142](https://github.com/Azure/terraform-azurerm-avm-res-app-managedenvironment/issues/142) is already assigned to Copilot.

Reply "go" to assign all of the above in one batch, or list the numbers you want (for example `go: 160, 157, 73`).

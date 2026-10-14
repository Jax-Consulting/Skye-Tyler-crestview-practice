# Crestview Community Health — Patient Intake Initiative
## CONTEXT.md · Tier 1 (Program)
**Repo root · maintained throughout the engagement**

---

> **How to use this file:**
> This file records what we learned the hard way so the next session — or the next person — does not have to relearn it. It is NOT documentation of how the system works. Read it before starting any session. Add to it when something costs you more than an hour, surprises you, or settles a design argument. Never add current state (e.g., "we are on v12 of the agent") — that goes stale immediately and is worse than nothing. Use the query or the org, not this file, for current state.
>
> **To add an entry:** copy the template at the bottom of this file, fill it in, and commit it in the same PR as the code change that produced the lesson. Not a follow-up ticket — it never gets done.

---

## Project Overview

**Client:** Crestview Community Health
**Initiative:** Patient Intake — Staff Intake Form & Case Routing
**Scenario:** Staff currently manage patient intake via Google Sheets. The engagement delivers a Salesforce-native solution: a patient lookup / creation flow, a Case record capturing each intake, and automatic routing to one of three internal queues (Insurance, Counseling, Medical).
**Volume:** ~25 intakes per day (calls + emails combined)
**Salesforce edition:** Developer Edition (trainee-provisioned)
**Go-live target:** 2 months from kickoff

---

## Environment & Infrastructure

| Item | Value | Notes |
|------|-------|-------|
| Salesforce org alias | `skyejaxdev` | Set with `sf alias set skyejaxdev=<Skye Tyler org username>` |
| Jira project key | `IPOP` | |
| Your trainee epic | `IPOP-47` | |
| GitHub repo | `Jax-Consulting/Skye-Tyler-crestview-practice` | |
| Salesforce API version | 62.0 | Pin in `.forceignore` and `sfdx-project.json` |
| Default branch | `main` | Never commit directly to `main` |
| Feature branch prefix | `feature/IPOP-<ticket>-short-description` | e.g., `feature/IPOP-47-case-object-setup` |
| CONTEXT.md updates branch | `feature/Practice-context-setup` | All edits to this file are committed here, never to `main`; they reach `main` by PR |

---

## Architecture Decisions

### ADR-001 · Use standard Case object for intake records
**Date:** 2026-10-01
**Decision:** Map each patient intake to a standard Salesforce **Case** record, not a custom object.
**Reasoning:** Crestview just onboarded Salesforce. Standard Case gives them queue management, assignment rules, and email-to-case out of the box — all without custom code to maintain. A custom object would require building all of that from scratch, which contradicts the client's maintainability requirement ("I'm not hiring a developer to update a picklist").
**Impact:** All intake-specific fields live on Case as custom fields.

---

### ADR-002 · Use Contact (not Person Account) for patient records
**Date:** 2026-10-02
**Decision:** Patients are modeled as standard **Contact** records. Person Accounts are explicitly off the table.
**Reasoning:** Person Accounts must be enabled by Salesforce Support and cannot be disabled once on. Enabling them on a Developer Edition org changes the data model in ways that are hard to reverse. Contacts link to Cases natively through the `ContactId` lookup.
**Impact:** Do not propose or prototype Person Accounts. If a future requirement genuinely needs them, open a new ADR and get Mentor approval before touching org settings.

---

### ADR-003 · LWC for the intake form, not a Screen Flow
**Date:** 2026-10-02
**Decision:** The patient intake form is built as a **Lightning Web Component**.
**Reasoning:** The form has a patient search/match step requiring dynamic server-side lookup before branching — possible in Screen Flow but brittle at the interactivity level Crestview needs. LWC gives a faster, app-like experience. Maintainability is addressed by keeping the field list in a Custom Metadata Type (`Intake_Form_Config__mdt`) so IT can add/remove/reorder fields without touching code.
**Impact:** The LWC has no business logic — all logic is in an Apex controller. The Custom Metadata Type pattern is required; do not hardcode the field list.

---

### ADR-004 · Queue-based routing with OWD = Private on Case
**Date:** 2026-10-05
**Decision:** Case OWD is set to **Private**. Three queues handle routing: `Insurance_Questions_Queue`, `Counseling_Sessions_Queue`, `Medical_Attention_Queue`.
**Reasoning:** Queue membership achieves read-within-queue + read-only cross-queue without row-level Apex sharing logic. An assignment rule fires on Case creation and routes based on `Type_of_Request__c` picklist value.
**Impact:** Intake Coordinators have Create access on Case but no Edit access after submission — enforced via Profile restriction + permission set.

---

## Platform Behavior Notes

### Queue membership does not grant record access by default — you need the sharing rule too
Queue members can be assigned a record, but without a sharing rule they cannot see records assigned to the queue unless they own them. Create one criteria-based sharing rule per queue. Test this explicitly; it is the most common misconfiguration on queue-based setups.

### Assignment rules only fire on Case insert, not update
If a Case is re-routed after creation, the new queue assignment must be set explicitly in code, not via the assignment rule re-firing.

### Custom Metadata Types: use getAll(), not SOQL
`CustomMetadataType.getAll()` returns all records regardless of the running user's access. `[SELECT ... FROM Intake_Form_Config__mdt]` is subject to the running user's permissions. Since Intake Coordinators have limited profiles, always use `getAll()` in the Apex controller. A SOQL query here will silently return zero rows for restricted users with no error.

### Standard objects first: use the standard data model
Use standard Salesforce objects (Contact, Account, Case) before proposing a custom object. When in doubt, check the Salesforce documentation before proposing a custom solution.

---

## Failure Modes & Their Tells

### Symptom: LWC search returns zero results even though the Contact exists
**Likely cause:** SOQL in the Apex controller is using `WITH SECURITY_ENFORCED` and the running user's profile does not have FLS on one of the queried fields.
**Fix:** Remove `WITH SECURITY_ENFORCED` from user-context Apex controllers. Use `Schema.sObjectType.Contact.fields.Birthdate.isAccessible()` checks. Verify the Intake Coordinator permission set includes FLS on all Contact fields the LWC displays.
**Tell:** Zero results, no error. Not a query logic problem — a permissions problem.

### Symptom: Case is created but not assigned to any queue
**Likely cause:** The assignment rule was not set as Active, OR the `DMLOptions.assignmentRuleHeader.useDefaultRule` flag was not set to `true`.
**Fix:** Confirm the assignment rule is Active in Setup → Case Assignment Rules. In Apex, set `Database.DMLOptions opts = new Database.DMLOptions(); opts.assignmentRuleHeader.useDefaultRule = true;` before insert.
**Tell:** Case is created but `OwnerId` is the running user, not a queue.

### Symptom: Orchestrate returns empty results or behaves as if metadata doesn't exist
**Likely cause:** Orchestrate is running as your connected user. If your user doesn't have access to a Flow, field, or metadata type in Setup, Orchestrate can't see it either.
**Fix:** Verify your connected user's permissions in Setup → Users → Permission Sets before assuming a bug in Orchestrate. Grant yourself the necessary access, then retry.

---

## Standards This Work Must Meet

### Code
- All Apex in a trigger handler class — no logic directly in the trigger file
- No SOQL or DML inside loops
- All Apex controllers for user-facing LWCs use `with sharing`
- Test classes: minimum 80% coverage, bulk test (200+ records), negative path, profile/permission boundary test
- Commit message format: `[JIRA-KEY] verb short description` — e.g., `[IPOP-47] add patient lookup Apex controller`

### Security model (confirm on every deploy)
- Intake Coordinator profile: Create on Case, Read on Contact — no Edit on Case after creation
- Queue member permission sets: Edit on Cases in own queue, Read on Cases in other queues (via sharing rule)
- All fields containing patient information: FLS restricted

### UI / LWC
- Intake form must work on both desktop and Salesforce mobile
- All form inputs must have `aria-label` attributes — accessibility is not optional
- Patient search input must debounce at 300ms — do not fire a server call on every keystroke

### Definition of Done (every story)
- [ ] Code deployed to dev org and manually verified in the UI
- [ ] Apex test class passing at 80%+ coverage, including a bulk test
- [ ] Security model verified: logged in as Intake Coordinator, then as queue member — both personas behave as expected
- [ ] CONTEXT.md updated if anything was learned the hard way
- [ ] Jira story transitioned to Done with a close-out comment stating the measured result

---

## How to Add a Context Entry

**Where to commit it:** commit every CONTEXT.md change to the `feature/Practice-context-setup` branch, not to `main` and not to a new branch. Before editing, sync that branch with `main` so the PR merges cleanly. Changes reach `main` only through a pull request that a reviewer merges.

```
### [Short title — what was the lesson]
**Date:** [When you learned this]
**Decision/Observation:** [What is true]
**Reasoning / Why it surprised us:** [Why it wasn't obvious, or what went wrong]
**Impact / Fix:** [What to do next time]
**Source:** [Jira ticket or PR — e.g., IPOP-47]
```

**Cite the ticket.** Anyone reading this entry should be able to walk from the rule back to the incident.

---

*Last updated: [Date] · [Your name]*
*Cite this file in every Jira story description: "Read CONTEXT.md before starting."*

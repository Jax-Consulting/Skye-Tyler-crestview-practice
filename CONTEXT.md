# Crestview Community Health — Patient Intake Initiative
## CONTEXT.md · Tier 1 (Program)
**Repo root · maintained throughout the engagement**

---

> **How to use this file:**
> This file records what we learned the hard way so the next session — or the next person — does not have to relearn it. It is NOT documentation of how the system works. Read it before starting any session. Add to it when something costs you more than an hour, surprises you, or settles a design argument. Never add current state (e.g., "we are on v12 of the agent") — that goes stale immediately and is worse than nothing. Use the query or the org, not this file, for current state.
>
> **To add an entry:** copy the template at the bottom of this file, fill it in, and commit it in the same PR as the code change that produced the lesson. Not a follow-up ticket — it never gets done.
>
> **Verification tags:** entries marked **[UNVERIFIED]** come from platform knowledge or planning documents and have not been proven in the dev org. Prove them in the sandbox, then remove the tag (or correct the entry).

---

## Project Overview

**Client:** Crestview Community Health
**Initiative:** Patient Intake — Staff Intake Form & Case Routing
**Scenario:** Staff currently manage patient intake via Google Sheets. The engagement delivers a Salesforce-native, **declarative (no custom code)** solution: a patient search / create flow on the standard Contact object, a Case record capturing each intake, and automatic routing to one of three internal queues (Insurance Navigation, Counseling, Medical Coordination).
**Volume:** ~25 intakes per day (calls + emails combined, entered manually by coordinators)
**Salesforce edition:** Developer Edition (trainee-provisioned)
**Go-live target:** 2 months from kickoff
**Source of requirements:** Discovery session of Sept 15, 2026, reconciled against the SOW; user stories v1.2 (Epics A–E, IPOP-128 to IPOP-146 under epic IPOP-47).

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
| Feature branch prefix | `feature/IPOP-<ticket>-short-description` | e.g., `feature/IPOP-135-case-fields-status` |

---

## Locked Decisions (from user stories v1.2)

These settle design arguments. Do not reopen without a new ADR.

| # | Decision |
|---|----------|
| D1 | SOW user counts govern (3 Intake Coordinators, 3 follow-up teams, IT admins). Stories are role-based; the design does not depend on licence counts. |
| D2 | Reporting = the SOW's 3 reports only: daily intake volume, request status by team, open requests by priority. |
| D3 | Patient search is native-declarative, with a feasibility spike first (see ADR-003). |
| D4 | Status **Incomplete** = started, not submitted. Coordinators can create Cases and edit a Case **only while Incomplete**. Once Submitted, it routes and coordinators can no longer edit. |
| D5 | Standard **Contact** is the patient record. No Person Accounts, no custom Patient object. |
| D6 | Team name is **Medical Coordination** (SOW). "Medical Response" is retired. |
| D7 | Case Status values (final): Incomplete, Submitted, In Progress, Pending Patient, Resolved. |
| D8 | Cleanup of Incomplete Cases is out of scope (manual Crestview process). Only an "Incomplete Cases" list view is built. No automation, ageing report or scheduled deletion without a change order. |
| D9 | In-app notification to queue members when a Case is assigned to a queue **and** Priority = Urgent (initial routing or re-route). Non-urgent: no notification. |
| D10 | Follow-up teams may correct data-entry errors on Submitted Cases in their own queue. Coordinators cannot edit after submission. |
| D11 | `Intake_Date__c` is a custom **Date/Time** field, separate from CreatedDate, stamped by the intake flow at submission, not editable by anyone afterwards (including admins). Incomplete Cases have no Intake Date. The daily volume report groups by it. |

**Priority values:** Low (not time-sensitive), Medium (next few days), High (within 24 hours), Urgent (same day).
**Type of Request values:** Insurance, Counseling, Medical.
**Queues:** Insurance Navigation, Counseling (Behavioral Health), Medical Coordination.

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
**Impact:** Do not propose or prototype Person Accounts. If a future requirement genuinely needs them, open a new ADR and get Mentor approval before touching org settings. **Open:** how Contacts with no Account are shared across users (see Open Questions #1) — blocks the search story.

---

### ADR-003 · Declarative build: Screen Flow, no custom code
**Date:** 2026-10-16
**Decision:** The intake experience is built with **Screen Flow and other declarative tools only** (Flow, duplicate/matching rules, assignment rules or flow-based owner assignment, custom notifications, validation rules, reports). No Apex and no Lightning Web Components in phase one. This replaces the earlier decision to build the form as an LWC.
**Reasoning:** The SOW assumes a standard declarative build, and Crestview IT must be able to maintain it without a developer. A custom-coded search is a change order.
**Impact:**
- Patient search = native "criteria + results table": Name/DOB/Phone screen inputs → Get Records on Contact → single-select Data Table (Name, DOB, Phone, Address) → selected row carried forward. This is **not** true type-ahead across three fields; Mary and Clint must be told before UAT.
- A spike in the sandbox must prove the refresh pattern (reactive vs Search button), what the Data Table search covers, and its 1,500-row cap against expected patient volume. **[UNVERIFIED]**
- A custom LWC is allowed only if the spike proves native tools cannot meet the need, and then only via change order.
- Third-party flow components are rejected (unsupported dependencies hurt IT maintainability).

---

### ADR-004 · Queue-based routing; Case OWD = Private
**Date:** 2026-10-05 · **Revised:** 2026-10-16
**Decision:** Case OWD is **Private**. Three queues route by `Type_of_Request__c`: Insurance Navigation, Counseling, Medical Coordination. Incomplete Cases are owned by an **Intake Coordinators queue** (design option, to prove) and are not routed until submitted.
**Reasoning:** Queue ownership plus sharing gives follow-up teams read on all Submitted Cases and edit on their own queue's Cases, without Apex sharing.
**Impact:**
- Coordinators: create Case/Contact; edit Case only while Incomplete; set Status only to Incomplete or Submitted; no delete.
- Follow-up teams: read all Submitted-and-later Cases and patient Contacts; edit own-queue Cases (including data-entry corrections); cannot set Status to Incomplete; re-route is allowed only from the owning queue.
- Changing Type alone does **not** re-route a Case; re-routing is an explicit owner change.
- Intake Date cannot be edited by anyone after submission (validation rule, since FLS alone does not stop admins). **[UNVERIFIED for admins]**

---

## Platform Behavior Notes

### Queue membership does not grant record access by default — you need the sharing rule too
Queue members can be assigned a record, but without a sharing rule they cannot see records assigned to the queue unless they own them. Create one criteria-based sharing rule per queue as needed. Test this explicitly; it is the most common misconfiguration on queue-based setups.

### Assignment rules only fire on Case insert, not update
Routing happens at **submission**, and an Incomplete Case is submitted by an **update**, so the assignment rule may not fire for it. Prove in the sandbox how an Incomplete→Submitted Case gets routed (for example, flow-based owner assignment). Also applies to re-routes: set the new queue explicitly. **[UNVERIFIED for the Incomplete→Submitted path]**

### Contacts with no Account are private to their owner
This would hide patients from other coordinators and from follow-up teams. Decide and prove how patient Contacts are shared (for example, a single default Account for all patients) before building search. **[UNVERIFIED in this org]**

### Custom notification recipients: queue vs members
Prove that all members of a queue receive the Urgent notification (queue as recipient vs expanding to members). **[UNVERIFIED]**

### Field history limits
Check the current per-object field history tracking limit before choosing the tracked Case and Contact fields. **[UNVERIFIED]**

### Standard objects first: use the standard data model
Use standard Salesforce objects (Contact, Account, Case) before proposing a custom object. When in doubt, check the Salesforce documentation before proposing a custom solution.

---

## Failure Modes & Their Tells

### Symptom: Patient search returns zero results even though the Contact exists
**Likely cause:** The Contact is owned by another user and the Contact sharing approach is not in place, or the coordinator permission set lacks FLS on a searched field.
**Fix:** Check Contact sharing/ownership and field access for the coordinator permission set.
**Tell:** Zero results, no error. A visibility problem, not a query logic problem.

### Symptom: Case is created but not assigned to any queue
**Likely cause:** The assignment rule is not Active, or (for an Incomplete Case submitted later) the rule did not fire because the Case was updated, not inserted.
**Fix:** Confirm the rule is Active in Setup → Case Assignment Rules, and confirm how routing is triggered on submission.
**Tell:** `OwnerId` is the running user or the Intake Coordinators queue instead of a team queue.

### Symptom: Orchestrate returns empty results or behaves as if metadata doesn't exist
**Likely cause:** Orchestrate is running as your connected user. If your user doesn't have access to a Flow, field, or metadata type in Setup, Orchestrate can't see it either.
**Fix:** Verify your connected user's permissions in Setup → Users → Permission Sets before assuming a bug in Orchestrate. Grant yourself the necessary access, then retry.

---

## Standards This Work Must Meet

### Build
- Declarative only (ADR-003). Any proposal to add Apex or LWC needs a new ADR and a change order.
- Picklist values, layouts, queue membership and routing must be editable by Crestview IT in Setup without a deployment.
- Commit message format: `[JIRA-KEY] verb short description` — e.g., `[IPOP-135] add Intake_Date__c and status values`

### Security model (confirm on every deploy)
- Intake Coordinator: Create on Case and Contact; edit Case only while Incomplete; no delete.
- Follow-up team permission sets: read all Submitted Cases; edit Cases in own queue only.
- All fields containing patient information: FLS restricted.
- Security matrix and HIPAA-conscious security documentation updated with every access change.

### UI
- Intake Case entry is a single screen (no multi-step wizard); target is "faster than the spreadsheet" (measurable target still to be agreed).
- Intake flow must work on both desktop and Salesforce mobile.
- Input labels must be accessible.

### Definition of Done (every story)
- [ ] Configuration built in the dev org and manually verified in the UI
- [ ] Tests executed and passed (the scenarios in the story's DoD, including negative and permission-boundary cases)
- [ ] Security model verified: logged in as Intake Coordinator, then as a follow-up team member — both behave as expected
- [ ] Documentation updated (configuration workbook, runbook, or security documentation as the story states)
- [ ] Deployed per the cut-over plan with a smoke test
- [ ] CONTEXT.md updated if anything was learned the hard way
- [ ] Jira story transitioned to Done with a close-out comment stating the measured result

---

## Open Questions (block or shape specific stories)

1. **Contact visibility** (blocks IPOP-130 search): how patient Contacts are shared across coordinators and follow-up teams.
2. **Urgent notification** (IPOP-140): confirm one trigger (assigned AND Urgent); should raising Priority to Urgent later also notify?
3. **Coordinator patient edits** (IPOP-131): phone and address confirmed; name and DOB not stated.
4. **Follow-up demographic corrections** (IPOP-137): may follow-up teams correct Contact demographics, and which fields?
5. **Status transitions** (IPOP-135, IPOP-136): confirm definitions and any restricted transitions (e.g., Resolved back to In Progress).
6. **Incomplete Cases in reports** (IPOP-144 to 146): currently excluded; confirm.
7. **Type value for Medical team:** keep "Medical" while the queue is named Medical Coordination?
8. **Search performance target and patient volume** (IPOP-130, IPOP-133): needed to choose the search approach.
9. **Data migration** (SOW): no story yet. Intake Date must be set to each historical row's original contact date by a one-time admin load.
10. **Training** (SOW): no story yet. US-15 (IT administration) and US-17 (security documentation) are in the story set but not yet in Jira.
11. **Intake channels:** confirm no email-to-case automation is expected.
12. **Licensing confirmation:** SOW Define deliverable; track in the project plan.

---

## How to Add a Context Entry

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

*Last updated: 2026-10-16 · aligned to user stories v1.2 (Orchestrate planning session)*
*Cite this file in every Jira story description: "Read CONTEXT.md before starting."*

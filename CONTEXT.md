# Crestview Community Health — Patient Intake Initiative
## CONTEXT.md · Tier 1 (Program)
**Repo root · maintained throughout the engagement**

---

> **How to use this file:**
> This file records what we learned the hard way so the next session — or the next person — does not have to relearn it. It is NOT documentation of how the system works. Read it before starting any session. Add to it when something costs you more than an hour, surprises you, or settles a design argument. Never add current state (e.g., "we are on v12 of the agent") — that goes stale immediately and is worse than nothing. Use the query or the org, not this file, for current state.
>
> **Then read the build plan:** [`context/build-plan.md`](context/build-plan.md) holds the ordered build steps, which story belongs to which step, and what each step must prove before the next starts. It holds the sequence, not the status — status lives in Jira and the org.
>
> **To add an entry:** copy the template at the bottom of this file, fill it in, and commit it in the same PR as the code change that produced the lesson. Not a follow-up ticket — it never gets done.
>
> **Verification tags:** entries marked **[UNVERIFIED]** come from platform knowledge or planning documents and have not been proven in the dev org. Prove them in the sandbox, then remove the tag (or correct the entry).

---

## Where things live

| What | Where |
|------|-------|
| Locked decisions, ADRs, lessons, open questions | This file (`CONTEXT.md`) |
| Build step sequence, story-to-step map, dependencies, entry and exit checks | `context/build-plan.md` |
| Running status and measured results per story | Jira, IPOP-128 to IPOP-146 under epic IPOP-47 |
| Session-to-session notes | `context/handoff.md` |
| Requirements source | User stories v1.2 (Jira) and the planning document |

Every Jira story description begins with: "Read CONTEXT.md and context/build-plan.md before starting. This story belongs to Build Step N."

---

## Project Overview

**Client:** Crestview Community Health
**Initiative:** Patient Intake — Staff Intake Form & Case Routing
**Scenario:** Staff currently manage patient intake via Google Sheets. The engagement delivers a Salesforce-native, **declarative (no custom code)** solution: a patient search / create flow on the standard Contact object, a Case record capturing each intake, and automatic routing to one of three internal queues (Insurance Navigation, Counseling, Medical Coordination).
**Volume:** ~25 intakes per day (calls + emails combined, entered manually by coordinators)
**Salesforce edition:** Developer Edition (trainee-provisioned)
**Go-live target:** 2 months from kickoff
**Source of requirements:** Discovery session of Sept 15, 2026, reconciled against the SOW; user stories v1.2 (Epics A–E, IPOP-128 to IPOP-146 under epic IPOP-47).
**Build sequence:** see `context/build-plan.md` (Build Steps 1–6).

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
| Build plan | `context/build-plan.md` | Read after this file, before any build work |

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
- A spike in the sandbox (Build Step 1 in `context/build-plan.md`) must prove the refresh pattern (reactive vs Search button), what the Data Table search covers, and its 1,500-row cap against expected patient volume. **[UNVERIFIED — hands-on test pending]** A throwaway `SPIKE_SF_Patient_Search` Screen Flow is deployed in the dev org (2026-10-19) for this test; see `spikes/build-step-1/README.md` for the steps.
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
- Intake Date cannot be edited by anyone after submission (validation rule, since FLS alone does not stop admins). **Proven 2026-10-19:** a lock validation rule blocks a System Administrator; a migration insert that sets the value is allowed; the first stamp on update when the prior value was blank is allowed. See Platform Behavior Notes.
- **Org is not yet at this OWD (2026-10-19):** Case OWD is currently Public Read/Write/Transfer and Contact OWD is Public Read/Write. Moving Case to Private is Build Step 3 work.

---

### ADR-005 · The build sequence lives in a repo file; status lives in Jira
**Date:** 2026-10-19
**Decision:** The ordered build steps, story-to-step map, dependencies and entry/exit checks are kept in `context/build-plan.md`. Running status and measured results are kept in Jira and the org, not in the repo. Each Jira story description points to both files and names its build step.
**Reasoning:** This file must not hold current state, so a step-by-step plan cannot live here. Orchestrate loads `CONTEXT.md` and `context/` at the start of every session, so a plan in `context/` is seen by a Build session without being pointed at it, while Jira stays the live record.
**Impact:** Change `context/build-plan.md` only when the plan itself changes, in the same PR as the work that caused the change. A Build session treats any progress statement in the plan as a claim to check against Jira and the org. The `orchestrate/context` branch must be merged to `main` before Build Step 1 starts, because Build sessions branch from `main`.
**Source:** IPOP-47

### ADR-006 · One Household Account per patient Contact
**Date:** 2026-10-19
**Decision:** each patient Contact gets its own Account (a "household" Account named after the patient), created by the intake flow when a new patient is created. Patient Contacts are never left without an Account.
**Reasoning:** Contacts with no Account are private to their owner, which would hide patients from other coordinators and follow-up teams. A single shared default Account was the alternative; it concentrates every patient under one parent record (account data skew once it passes about 10,000 child records, slower sharing recalculation) and makes a later move to a household model harder. One Account per patient avoids both and keeps the standard data model (ADR-002).
**Impact:** IPOP-132 (new patient) creates the Account and the Contact together. Search and reports work off Contact, not Account. Proving that a second user can see the patient is still open (needs a non-admin user). Answers Open Question 1.
**Source:** IPOP-47 (Skye's decision in the 2026-10-19 Build session)

### ADR-007 · Retire the old sample Case picklist values by deactivating them
**Date:** 2026-10-19
**Decision:** in Build Step 2, Case Status, Type and Priority hold exactly the D7 / Type / Priority values. The org's sample values (Status New/Working/Escalated/Closed; Type Mechanical/Electrical/…; old Priority values) are **deactivated**, not deleted, so the 26 sample Cases keep their history.
**Reasoning:** deleting a used picklist value forces a replace on existing records; deactivating keeps the data and removes the value from new entry.
**Impact:** Build Step 2 work. Recorded here only; nothing was changed in this session.
**Source:** IPOP-47 (Skye's decision in the 2026-10-19 Build session)

---

## Platform Behavior Notes

### Queue membership does not grant record access by default — you need the sharing rule too
Queue members can be assigned a record, but without a sharing rule they cannot see records assigned to the queue unless they own them. Create one criteria-based sharing rule per queue as needed. Test this explicitly; it is the most common misconfiguration on queue-based setups.

### Assignment rules do not fire for Flow-created or Flow-updated Cases — route in the flow
**Date:** 2026-10-19 · **Source:** IPOP-47 (Build Step 1 spike, `spikes/build-step-1/scripts/01_routing_spike.apex`, rolled back)
**Observation:** Against the org's active Case assignment rule, with a matching Account: a Case created by Flow Create Records stayed with the running user; a plain insert stayed; a plain update stayed. The rule fired only when the assignment-rule header was passed explicitly (on insert **and** on update). Flow has no option to pass that header, so neither the intake flow's insert nor the Incomplete→Submitted update will trigger an assignment rule.
**Also surprised us:** the "use default rule" header (`useDefaultRule = true`) did **not** fire the active rule in this org; only passing the rule's Id did. Do not rely on the default-rule checkbox behaviour when testing.
**Impact / Fix:** do routing in the flow. On submission (and on re-route) the flow sets `OwnerId` to the queue for the Type of Request, looked up by queue DeveloperName, never a hard-coded Id. Do not build a Case assignment rule for intake routing; it would never fire for flow-entered Cases.

### Contacts with no Account are private to their owner
This would hide patients from other coordinators and from follow-up teams. **Decided 2026-10-19:** a Household Account per patient (ADR-006). Org facts on 2026-10-19: Account OWD Public Read/Write, Contact OWD Public Read/Write, 20 sample Contacts all linked to an Account. **[UNVERIFIED — second-user test pending]** The "can a second user see it" test needs a non-admin user, which Skye is creating by hand; the steps are in `spikes/build-step-1/README.md`.

### Custom notification recipients: queue vs members
Prove that all members of a queue receive the Urgent notification (queue as recipient vs expanding to members). **Partly proven 2026-10-19:** the Send Custom Notification action **accepts a queue Id as a recipient** without error (Flow action and Apex API both). **Delivery to members is NOT confirmed:** the Notifications API returned an empty list for the only queue member, including the user-addressed control, so the check itself is in doubt. Confirm by the bell icon, then repeat with a second user who is a member but not the sender. **[UNVERIFIED — delivery]**

### Send Custom Notification action fails if you store its output automatically
**Date:** 2026-10-19 · **Source:** IPOP-47 (Build Step 1 spike)
**Observation:** At API 68.0, a Flow action call to `customNotificationAction` with "store output automatically" on fails every time with a generic "unhandled fault". The real error (visible only with Workflow logging at FINER) is: `In Apex action "Send Urgent Notification", type mapping "SuccessMessage" is not a supported type.`
**Impact / Fix:** in Flow Builder leave the action's output unstored (the action has no useful output). If a flow fails with only the generic fault, raise Workflow logging to FINER before guessing.

### Field history limits
Check the current per-object field history tracking limit before choosing the tracked Case and Contact fields. **Checked 2026-10-19:** Case already tracks 10 standard fields (ContactId, AssetId, Type, Status, Reason, Origin, Subject, Priority, Description, OwnerId); Contact tracks none. Salesforce documents a standard limit of 20 fields per object, so Case has about 10 slots left; prune unused tracked fields (e.g. AssetId, Reason) if IPOP-143 needs more. **[Limit value is documented, not tested in this org]**

### Contact has no standard Gender field in this org
**Date:** 2026-10-19 · **Source:** IPOP-47 (Build Step 1 spike)
**Observation:** describing Contact shows `Birthdate` (Date) but no Gender or pronoun field.
**Impact / Fix:** IPOP-128 needs a custom picklist (a global value set, so values stay admin-editable) on Contact.

### Test users: only 2 full licences are usable
**Date:** 2026-10-19 · **Source:** IPOP-47 (Build Step 1 spike)
**Observation:** Salesforce licence 2 of 4 used (2 free). Salesforce Platform licence 0 of 6 used, but Platform licences do not include Case access, so they cannot stand in for coordinators or follow-up teams. Users can be deactivated but never deleted.
**Impact / Fix:** the org cannot hold separate users for coordinator plus three teams at once. Decision (2026-10-19): Skye creates test users by hand; reuse a user across personas by swapping permission sets and queue membership between test runs.

### Standard objects first: use the standard data model
Use standard Salesforce objects (Contact, Account, Case) before proposing a custom object. When in doubt, check the Salesforce documentation before proposing a custom solution.

---

## Failure Modes & Their Tells

### Symptom: Patient search returns zero results even though the Contact exists
**Likely cause:** The Contact is owned by another user and the Contact sharing approach is not in place, or the coordinator permission set lacks FLS on a searched field.
**Fix:** Check Contact sharing/ownership and field access for the coordinator permission set.
**Tell:** Zero results, no error. A visibility problem, not a query logic problem.

### Symptom: Case is created but not assigned to any queue
**Likely cause:** Routing relies on a Case assignment rule. Assignment rules do not fire for Cases created or updated by Flow (proven 2026-10-19), so the intake flow must set the owner itself.
**Fix:** Check the flow's submission path sets `OwnerId` to the queue for the Type of Request, and that the queue DeveloperName it looks up exists.
**Tell:** `OwnerId` is the running user or the Intake Coordinators queue instead of a team queue.

### Symptom: Orchestrate returns empty results or behaves as if metadata doesn't exist
**Likely cause:** Orchestrate is running as your connected user. If your user doesn't have access to a Flow, field, or metadata type in Setup, Orchestrate can't see it either.
**Fix:** Verify your connected user's permissions in Setup → Users → Permission Sets before assuming a bug in Orchestrate. Grant yourself the necessary access, then retry.

---

## Standards This Work Must Meet

### Build
- Declarative only (ADR-003). Any proposal to add Apex or LWC needs a new ADR and a change order.
- Read this file and `context/build-plan.md` before starting; confirm your story's build step entry checks are met.
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
- [ ] CONTEXT.md updated if anything was learned the hard way; `context/build-plan.md` updated only if the plan changed
- [ ] Jira story transitioned to Done with a close-out comment stating the measured result

---

## Open Questions (block or shape specific stories)

1. **Contact visibility** (blocks IPOP-130 search): **decided 2026-10-19, Household Account per patient (ADR-006)**; second-user proof still pending.
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

*Last updated: 2026-10-19 · Build Step 1 spike findings added (Orchestrate Build session)*
*Cite both files in every Jira story description: "Read CONTEXT.md and context/build-plan.md before starting."*

# Crestview Patient Intake — Build Plan
## context/build-plan.md

> **What this file is:** the *sequence* of the build — which build step each story belongs to, what depends on what, and what each step must prove before the next starts.
> **What it is not:** a status report. Whether a step or story is done is recorded in Jira (IPOP-128 to IPOP-146) and in the org — never here. Treat anything in this file about progress as a claim to check.
> **Companion file:** `CONTEXT.md` holds the locked decisions (D1–D11), ADRs, platform lessons and open questions. Read `CONTEXT.md` first, then this file.
> **Change rule:** edit this file only when the plan itself changes (a story moves step, a dependency is found, an exit check changes). Do it in the same PR as the work that caused the change.

---

## How every Build session uses this plan

1. Read `CONTEXT.md`, then this file.
2. Find your story's **build step** below (also in the story's description).
3. Check Jira and the org for what is already done. Do not trust recorded status.
4. Confirm the **entry checks** for your step are met. If not, stop and say so.
5. Build declaratively only (ADR-003). Branch `feature/IPOP-<n>-short-description`, PR to `main`, commit format `[IPOP-<n>] verb short description`.
6. Verify by retrieving the deployed metadata and testing as each persona (Intake Coordinator, each follow-up team member, admin). A "Succeeded" deploy alone is not proof.
7. Close out: post a measured-result comment on the Jira story, add any surprise to `CONTEXT.md`, and change this file only if the plan changed.

---

## Build steps at a glance

| Build step | Purpose | Stories |
|---|---|---|
| Build Step 1 | Spikes — prove the unverified platform behaviours | Proofs feeding IPOP-128, IPOP-130, IPOP-135, IPOP-140, IPOP-138 |
| Build Step 2 | Data model and foundation | IPOP-128, IPOP-135, queues from IPOP-138 |
| Build Step 3 | Security and sharing | IPOP-141, IPOP-142, IPOP-143, sharing part of IPOP-134 |
| Build Step 4 | Intake flow | IPOP-129, IPOP-130, IPOP-131, IPOP-132, IPOP-133, IPOP-134 |
| Build Step 5 | Routing and case work | IPOP-138, IPOP-139, IPOP-140, IPOP-136, IPOP-137 |
| Build Step 6 | Reports and handoff | IPOP-144, IPOP-145, IPOP-146, runbook, security documentation, smoke tests |

Steps run in order 1 → 2 → 3 → 4 → 5 → 6. Within Build Step 4 and Build Step 5, stories can run in parallel once that step's entry checks are met.

---

## Build Step 1 — Spikes

**Session type:** Build (throwaway configuration in the dev org; nothing carried to the customer).
**Goal:** replace every **[UNVERIFIED]** tag in `CONTEXT.md` that a later step depends on.

| Spike | Question to answer | Feeds |
|---|---|---|
| Contact visibility | With a default Account (or other approach) and the chosen OWD, can a second user see a patient created by another user? | IPOP-128, IPOP-130, IPOP-142 |
| Search pattern | Does Name/DOB/Phone inputs → Get Records → single-select Data Table work? Which refresh pattern? What does Data Table search cover? Behaviour at the 1,500-row cap? | IPOP-130 |
| Intake Date lock | Does a validation rule on `Intake_Date__c` also block a system administrator? How does a one-time migration load set it? | IPOP-135 |
| Incomplete → Submitted routing | Does an assignment rule fire when an Incomplete Case is updated to Submitted, or is flow-based owner assignment needed? | IPOP-138, IPOP-134 |
| Queue notification | Does a custom notification reach every member of a queue, or must the flow expand to members? | IPOP-140 |
| Gender field | Is there a standard Gender field on Contact in this org? | IPOP-128 |
| Test users | Can the Developer Edition org hold the test users for coordinator, three follow-up teams and admin? | All later steps |
| Field history limit | What is the current per-object field history tracking limit? | IPOP-143 |

**Exit check:** each spike has a dated entry in `CONTEXT.md` (the tag removed or the entry corrected). Any spike that disproves an assumption gets a new ADR or a change-order note before Build Step 2 starts.

---

## Build Step 2 — Data model and foundation

**Stories:** IPOP-128 (Contact), IPOP-135 (Case fields and Status), the three queues and the Intake Coordinators queue (from IPOP-138).
**Entry checks:** Build Step 1 exit check met, in particular Contact visibility and Intake Date lock.
**Build:**
- Contact fields, layout and FLS; the chosen Contact sharing approach.
- Case fields: Type of Request, Priority, Status (D7 values), `Intake_Date__c` (Date/Time, read-only, validation rule that also blocks admins).
- Queues: Insurance Navigation, Counseling, Medical Coordination, plus Intake Coordinators.
**Exit check:** a second user can see a patient created by another; picklist values are admin-editable without a deployment; Intake Date cannot be changed after it is set, including by an admin.

---

## Build Step 3 — Security and sharing

**Stories:** IPOP-141 (coordinator permissions), IPOP-142 (follow-up team permissions), IPOP-143 (audit trail), and the ownership and sharing part of IPOP-134.
**Entry checks:** Build Step 2 exit check met; test users exist.
**Build:**
- Permission sets per persona; Case OWD Private; queue-based sharing so follow-up teams read all Submitted Cases and edit only their own queue's.
- Incomplete Cases owned by the Intake Coordinators queue and invisible to follow-up queues.
- Field history tracking on Case and Contact.
- Security matrix started (updated at every later step).
**Exit check:** negative tests pass per persona — coordinator cannot edit or delete after submit and can only set Incomplete or Submitted; follow-up user cannot edit another team's Case and cannot set Incomplete; field history records edits.

---

## Build Step 4 — Intake flow

**Stories:** IPOP-129 (duplicate warning), IPOP-130 (search), IPOP-131 (confirm phone), IPOP-132 (new patient), IPOP-133 (single-screen Case entry), IPOP-134 (Incomplete save and the "Incomplete Cases" list view).
**Entry checks:** Build Step 3 exit check met; search approach confirmed by the Build Step 1 spike; open questions 1, 3 and 8 in `CONTEXT.md` answered or consciously deferred.
**Build:** one Screen Flow experience — search, select or create, confirm phone, Case entry on one screen, Submit or save as Incomplete. Matching and duplicate rules on Contact (alert, not block). `Intake_Date__c` stamped at submission, including when an Incomplete Case is submitted later.
**Exit check:** works on desktop and Salesforce mobile; coordinator A can start and coordinator B can finish an Incomplete Case; entry time measured against the agreed target (open question 8). Mary and Clint have been told that search is criteria plus results table, not type-ahead.

---

## Build Step 5 — Routing and case work

**Stories:** IPOP-138 (routing by Type), IPOP-139 (re-route), IPOP-140 (Urgent notification), IPOP-136 (work a Case), IPOP-137 (corrections after submission).
**Entry checks:** Build Step 4 exit check met; routing-on-update and queue-notification spikes recorded.
**Build:**
- Routing at submission, including the Incomplete → Submitted path.
- Explicit re-route (owner change from the owning queue only); changing Type alone does not re-route.
- Urgent notification on assignment and on re-route; non-Urgent sends nothing.
- Follow-up layouts, status path, notes, and correction rights (Intake Date stays locked).
**Exit check:** each Type routes to the right queue; Incomplete → Submitted routes; Urgent reaches every queue member; cross-team edit blocked; coordinator remains read-only after submission.

---

## Build Step 6 — Reports and handoff

**Stories:** IPOP-144 (daily intake volume by Intake Date), IPOP-145 (status by team), IPOP-146 (open requests by priority). Run as an Analytics Build session or a Build session.
**Entry checks:** Build Step 5 exit check met; open question 6 (Incomplete Cases excluded) confirmed.
**Build:** the three SOW reports only (D2). Then the runbook, configuration workbook, security matrix and security documentation, the smoke-test checklist and the cut-over plan.
**Exit check:** reports verified against sample Cases; a Review session confirms the security matrix against the org; smoke tests pass in the target org.

---

## Work not yet in Jira

| Item | Note |
|---|---|
| IT administration story (US-15) | In the story set, not yet in Jira. Belongs with Build Step 6. |
| Security documentation story (US-17) | In the story set, not yet in Jira. Updated at every step, finished in Build Step 6. |
| Data migration | No story. One-time admin load must set `Intake_Date__c` to each historical row's original contact date. Needs a story before Build Step 6. |
| Training | No story. Needs a story before Build Step 6. |

---

## Open questions that can change the build

These live in `CONTEXT.md` (Open Questions). The ones most likely to move a step: 1 (Contact visibility), 2 (Urgent notification on later Priority change), 3 and 4 (who can edit name and DOB), 8 (search performance target and patient volume).

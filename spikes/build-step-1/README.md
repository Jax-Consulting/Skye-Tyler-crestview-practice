# Build Step 1 spikes (IPOP-47) — THROWAWAY

Nothing in this folder is part of the Crestview customer build. Every component is named `SPIKE…`, lives in its own
SFDX project (it is not under the main `force-app`), and is deleted after Build Step 1 closes.
Dated findings are recorded in `CONTEXT.md`; this file holds how to repeat each test.

Run date: 2026-10-19, org `skyejaxdev-dev-ed`, API 68.0, as Skye Tyler (System Administrator).

## What is deployed in the dev org

| Component | Type | State after the session |
|---|---|---|
| `SPIKE_SUB_Create_Case` | Autolaunched flow | Active (used by the routing test) |
| `SPIKE_SUB_Notify_Recipient` | Autolaunched flow | Active (sends the SPIKE notification) |
| `SPIKE_SF_Patient_Search` | Screen flow | Active (for the hands-on search test) |
| `SPIKE_Urgent_Case` | Custom notification type | Present |
| `Case.SPIKE_Intake_Date_Lock_Proxy` | Validation rule | **Inactive** (switched off after the test) |
| `SPIKE Notify Queue` | Case queue, Skye as only member | Present (keep for the second-user notification test) |

## Results

| Spike | Result | Evidence |
|---|---|---|
| Incomplete → Submitted routing | **Proven.** Flow insert, plain insert and plain update do not fire the assignment rule. Only an explicit assignment-rule header fires it (insert and update). `useDefaultRule = true` did not fire it in this org; passing the rule Id did. Route in the flow by setting `OwnerId`. | `scripts/01_routing_spike.apex` — owners A Skye, B Skye, C OrgFarm EPIC, D Skye, E OrgFarm EPIC. Rolled back; 0 SPIKE Cases/Accounts left. |
| Intake Date lock | **Proven.** A lock validation rule blocks a System Administrator (`FIELD_CUSTOM_VALIDATION_EXCEPTION`). Insert with the value set is allowed (migration load path). First stamp on update when prior blank is allowed. | `scripts/02_intake_date_lock_spike.apex` against the proxy rule (Subject `SPIKE-LOCK…`). Rolled back. |
| Queue notification | **Partly proven.** The action accepts a queue Id as recipient (Flow and Apex). Delivery to members not confirmed — the Notifications API list was empty even for the user-addressed control. | `scripts/03a…`, `scripts/03b…`. |
| Gender field | **Proven:** no standard Gender field on Contact. Custom picklist needed. | `sf sobject describe Contact` |
| Field history | Case tracks 10 fields, Contact 0. Documented limit 20 per object. | `FieldDefinition.IsFieldHistoryTracked` |
| Test users | Salesforce licence 2/4 used; Platform 0/6 but no Case access. Skye creates users by hand. | `UserLicense` |
| Contact visibility | Decision: Household Account per patient (ADR-006). OWD Account and Contact both Public Read/Write today. Second-user test pending. | `EntityDefinition` sharing model |
| Search pattern | Pending hands-on test. | `SPIKE_SF_Patient_Search` |

Side finding: `customNotificationAction` with "store output automatically" fails at API 68.0 (`type mapping "SuccessMessage" is not a supported type`). Fixed in `SPIKE_SUB_Notify_Recipient` by not storing output.

## Still to do by hand (needs a person or a second user)

1. **Notification delivery.** Open the bell icon in Lightning. You should see `SPIKE-NOTIFY to QUEUE`, `SPIKE-NOTIFY to USER (control)` and `SPIKE-NOTIFY to QUEUE (API check)`. Then add your second test user to `SPIKE Notify Queue`, run `scripts/03b_notification_send.apex` as yourself, and check that user's bell. That user is a member who is not the sender, which is the real test.
2. **Contact visibility.** As the second (non-admin) user, open a Contact owned by you that has an Account. Repeat with a Contact that has no Account (create one, then delete it afterwards).
3. **Search pattern.** Run `SPIKE – SF – Patient Search` from Setup → Flows → Run. Record: does the result list only refresh on Next (search button) or as you type; what the Data Table search box filters (loaded rows only?); how the flow behaves with more than 1,500 matching Contacts (load test data in the dev org only if needed).

## Clean-up when Build Step 1 closes

Delete the three SPIKE flows, the notification type, the validation rule and the SPIKE queue (destructive deploy plus queue delete).

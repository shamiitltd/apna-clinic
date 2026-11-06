# Apna Clinic --- Monthly Google Sheets Storage & Apps Script Integration

## Feature Product Requirements Document (Feature PRD)

**Version:** 1.1\
**Date:** 4 November 2026\
**Status:** Feature specification for integration into the existing Apna
Clinic application\
**Parent documents:** Existing Apna Clinic PRD v1.0 and TRD v1.0\
**Change type:** Additive feature only

------------------------------------------------------------------------

## 1. Purpose and relationship to the existing product

This document specifies an additional cloud-storage and
data-organization feature for the already-developed Apna Clinic
application.

**This is not a new application specification. It does not replace,
rewrite, or redesign the existing Apna Clinic product.**

The existing PRD and TRD remain the source of truth for: - Product
scope, clinic workflows, roles, permissions, and clinical boundaries. -
Existing Flutter Web UI and navigation. - Existing patient registration,
appointment, queue, visit, consultation-slip, billing, payment,
dashboard, staff, subscription, and reporting behavior. - Existing
local-first IndexedDB behavior and offline workflows. - Existing design
system, state management, routing, and deployment choices. - Existing
security, privacy, and acceptance requirements, except where this
feature adds a more specific requirement.

If this feature document does not explicitly describe a change, the
existing application's behavior remains unchanged. If an implementation
detail conflicts with the existing PRD/TRD, do not silently change the
existing behavior; raise the conflict for approval.

## 2. Feature summary

Add a monthly partitioning and cloud synchronization capability for
patient and operational records:

1.  Keep the existing Flutter application and its local IndexedDB
    database.
2.  Keep existing clinic workflows and local-first operation.
3.  Add a Google Apps Script integration layer for the new cloud-routing
    operations.
4.  Keep Google Sheets as the structured cloud record store and Google
    Drive as the file/backup store.
5.  Maintain one clinic master workbook for stable patient records and
    routing/index metadata.
6.  Create one transaction workbook per clinic per calendar month for
    monthly operational records.
7.  Maintain a patient-history index so the application can find a
    patient's records across months without scanning every workbook.
8.  Sync local changes in batches and show their sync status in the
    existing UI.
9.  Preserve the existing app's offline behavior; cloud connectivity
    must not become a prerequisite for ordinary local workflows.

The feature is intended to support approximately **4,000--5,000 patients
registered and handled per month across all participating clinics**.
This is a planning volume, not a confirmed number of clinics or
concurrent users.

## 3. Goals

-   Avoid one ever-growing transaction workbook for all operational
    history.
-   Keep patient identity stable across months.
-   Retrieve a patient's administrative history across multiple monthly
    workbooks.
-   Reduce cloud API traffic through batching and local-first workflows.
-   Improve backup, restore, and data organization.
-   Keep existing screens and workflows intact wherever possible.
-   Add safe retry and duplicate prevention for cloud synchronization.
-   Make monthly workbook creation and routing automatic.

## 4. Explicit non-goals

This feature does not: - Rebuild Apna Clinic or replace its Flutter Web
frontend. - Replace the existing IndexedDB schema wholesale. - Replace
the current state-management, routing, UI, or printing implementation. -
Rewrite patient registration, appointment, queue, visit, billing, or
payment modules. - Change existing roles or permissions unless a
specific additional permission is approved. - Move every existing local
operation to a new online-only API. - Require continuous internet access
for normal reception workflows. - Introduce multi-device live
collaboration if that is not already supported by the existing
product. - Add diagnosis, treatment advice, electronic prescriptions, or
new clinical features. - Guarantee support for 50,000 clinics or
unlimited Google API usage.

## 5. Existing application behavior to preserve

The feature must integrate with, not replace, the following baseline
behavior documented in the parent PRD/TRD:

-   Flutter Web remains the application client.
-   IndexedDB remains the local operational store and supports
    offline-first work.
-   Existing patient, appointment, visit, queue, billing, payment, and
    reporting workflows remain in place.
-   Existing single-writer MVP assumptions remain in force unless
    separately changed.
-   Existing consultation slip/printing behavior remains unchanged.
-   Existing role-based access and clinical/privacy boundaries remain in
    force.
-   Existing local transaction behavior remains authoritative for
    unsynced work.
-   Existing Google OAuth, Sheets, and Drive integration remains the
    baseline integration. Apps Script is introduced as a narrowly scoped
    integration/service layer for monthly workbook routing, index
    maintenance, and batch synchronization---not as a reason to rebuild
    the app.

## 6. Feature architecture at product level

### 6.1 Responsibility split

  -----------------------------------------------------------------------
  Existing application                New feature addition
  ----------------------------------- -----------------------------------
  Flutter UI and workflows            No redesign; add sync
                                      status/history access where needed

  Existing IndexedDB and local domain Add/extend outbox, cloud IDs, month
  logic                               routing metadata and sync
                                      checkpoints only where needed

  Existing patient and transaction    Add stable cloud identifiers/index
  entities                            metadata only where required

  Existing OAuth/session behavior     Reuse the approved existing
                                      identity flow; add only the
                                      authorization needed by the Apps
                                      Script integration

  Existing Sheets/Drive integration   Add monthly workbook registry,
                                      provisioning and cross-month
                                      history routing

  Existing reports and dashboards     Continue to use existing behavior;
                                      add cross-month source retrieval
                                      only where a report/history view
                                      needs it
  -----------------------------------------------------------------------

### 6.2 Data flow

-   The user continues to perform normal work in the existing
    application.
-   The app saves local changes using its existing local-first
    mechanisms.
-   A sync service packages eligible changes into bounded batches.
-   Apps Script validates the request and resolves the correct clinic
    and monthly workbook.
-   The service writes operational records to the appropriate monthly
    workbook and updates the master index.
-   The app receives the canonical IDs and sync result, then updates its
    local sync metadata.
-   A patient-history request first resolves the patient's month
    references from the master index and then fetches only those months.

## 7. Data organization requirements

### 7.1 Clinic master workbook

One master workbook per clinic, using the existing clinic Drive
ownership/access model, stores relatively stable records and routing
metadata.

New or adapted tabs:

-   `Patients_Master` --- permanent patient identity and the approved
    patient master fields.
-   `Patient_History_Index` --- patient-to-month routing index.
-   `Spreadsheet_Registry` --- mapping from clinic/month to monthly
    transaction workbook ID.
-   `Sync_Manifest` --- sync checkpoints, batch IDs, schema version, and
    reconciliation status.

Existing tabs and data must not be removed merely because new monthly
workbooks are introduced. Migration of any existing tab's records
requires an approved migration plan and verification.

### 7.2 Monthly transaction workbooks

Create one workbook per clinic per calendar month. Proposed name:

`ApnaClinic_<clinic_id>_Transactions_YYYY_MM`

Initial transaction tabs:

-   `Appointments`
-   `Visits`
-   `Billing`
-   `Payments`

Additional tabs such as `Queue_Events`, `Invoice_Items`, `Refunds`, and
`Expenses` may be included when those existing modules are routed to
monthly storage. Their inclusion must preserve the exact existing
business rules and canonical fields from the parent TRD.

Do not remove existing master workbook tabs or change existing app
behavior as a side effect of adding monthly workbooks. The
migration/routing plan must explicitly state which record types are
moved, mirrored, or retained in their current location.

### 7.3 Patient identity

-   Each patient keeps the existing permanent `patient_id`/identifier
    used by the application.
-   Month partitioning must not create a new patient identity.
-   Every transaction record references the same patient ID.
-   Existing IDs must not be regenerated during migration.
-   If the existing ID format differs from a proposed cloud ID, add a
    mapping; do not replace the existing identifier without approval.

## 8. Functional requirements

  --------------------------------------------------------------------------
  ID                      Requirement                Priority
  ----------------------- -------------------------- -----------------------
  F-001                   Existing application       Must
                          workflows continue to work 
                          without UI or              
                          business-logic regression. 

  F-002                   The feature provisions or  Must
                          resolves a monthly         
                          workbook for the correct   
                          clinic and month.          

  F-003                   Monthly workbook IDs are   Must
                          stored in a master         
                          `Spreadsheet_Registry`.    

  F-004                   Existing patient IDs       Must
                          remain stable across       
                          months.                    

  F-005                   Transaction records are    Must
                          routed to the correct      
                          month without changing     
                          their business meaning.    

  F-006                   Patient history is         Must
                          resolved through           
                          `Patient_History_Index`.   

  F-007                   Cloud writes are batched   Must
                          and idempotent.            

  F-008                   Existing                   Must
                          local-first/offline        
                          workflows continue to      
                          operate.                   

  F-009                   Existing UI displays       Must
                          pending, syncing, synced,  
                          and failed status using    
                          the current design system. 

  F-010                   Failed sync does not       Must
                          discard local records.     

  F-011                   Existing permissions are   Must
                          enforced for new cloud     
                          operations.                

  F-012                   Existing data can be       Must
                          migrated or backfilled     
                          without losing IDs or      
                          history.                   

  F-013                   Monthly history can be     Must
                          retrieved across multiple  
                          months.                    

  F-014                   Backup/restore includes    Must
                          master and monthly         
                          workbooks.                 

  F-015                   The feature provides       Must
                          reconciliation for partial 
                          failures and stale         
                          indexes.                   
  --------------------------------------------------------------------------

## 9. Patient history behavior

1.  Search and selection continue through the existing patient module.
2.  The selected patient retains the existing patient ID.
3.  When the history view needs cloud records, the app requests the
    patient's index entries.
4.  The index identifies only the relevant months and record categories.
5.  The service retrieves records from those workbooks and returns a
    chronological result.
6.  Existing patient profile and history presentation should be reused;
    only the data source/retrieval capability is extended.
7.  If some months are unavailable or fail to load, show a clear
    partial-history state rather than silently presenting incomplete
    history as complete.

## 10. Offline and sync behavior

-   Existing local writes remain available according to the current
    offline design.
-   The new feature adds or extends a durable outbox; it must not
    introduce a second competing source of truth.
-   Each cloud-bound operation has a stable operation/idempotency key.
-   The app marks a record as synced only after backend confirmation.
-   Retryable failures use bounded exponential backoff with jitter.
-   Authorization, validation, and permanent conflict errors are
    surfaced for correction rather than retried forever.
-   A partially completed server write must be repairable through
    reconciliation.
-   Existing local data must remain accessible when Apps Script, Sheets,
    Drive, or the network is unavailable.

## 11. Security and permissions

-   Reuse the existing sign-in and role model where technically
    possible.
-   Apps Script must not trust client-supplied clinic IDs, role claims,
    or spreadsheet IDs.
-   New backend operations must verify the caller's existing clinic
    membership and permission.
-   The existing Drive ownership and access model remains in force.
-   Do not expose privileged credentials or unrestricted owner tokens to
    the browser.
-   Do not broaden access to existing workbooks merely to make monthly
    routing easier.
-   Existing privacy, encryption, audit, and clinical-boundary
    requirements remain applicable.
-   The exact Apps Script deployment identity/token-validation design is
    a release gate and must be proven before production use.

## 12. Volume, quotas, and cost

Planning volume: 4,000--5,000 patients registered/handled monthly across
all clinics.

This number alone does not determine API capacity. Measure: - Number of
clinics and devices. - Peak concurrent users. - Average appointments,
visits, invoices, and payments per patient. - Requests and spreadsheet
operations per workflow. - Peak requests per minute. - Backup size and
frequency.

Requirements: - Batch reads and writes. - Avoid network calls for every
keystroke, local search, print, or ordinary local calculation. - Use
caching and bounded history queries. - Add per-clinic and platform-level
rate controls. - Handle quota errors without losing local data or
creating duplicates. - Validate current Apps Script, Sheets, and Drive
quotas against the actual deployment/account model. - Measure hosting,
storage, backup, and support costs in a pilot. No fixed monthly cost is
guaranteed.

## 13. Migration and rollout

This is an additive rollout:

1.  Inspect the existing live/local data model and identify the
    authoritative current records.
2.  Add registry/index structures without deleting existing tables or
    tabs.
3.  Provision monthly workbooks in a test clinic.
4.  Backfill a controlled sample while preserving IDs.
5.  Verify record counts, references, patient history, and financial
    reconciliation.
6.  Enable monthly routing behind a feature flag for internal testing.
7.  Pilot with a small number of clinics.
8.  Expand only after sync, restore, quota, and regression tests pass.

The feature must support rollback to the prior sync path during the
pilot. Rollback must not delete data already written to monthly
workbooks.

## 14. Acceptance criteria

1.  Existing patient registration, appointments, queue, visit, printing,
    billing, payment, and reporting workflows pass regression tests.
2.  No existing screen/module is removed or replaced by this feature.
3.  Existing patient IDs remain unchanged.
4.  A monthly workbook is created/resolved for the correct clinic and
    month.
5.  Records are written to the intended monthly workbook.
6.  A patient with records in multiple months has complete,
    chronologically ordered history.
7.  Retrying the same operation does not create duplicates.
8.  Offline work continues when cloud services are unavailable.
9.  Sync status is visible and accurate.
10. Partial writes/index failures are repaired by reconciliation.
11. Existing role restrictions apply to the new operations.
12. Master and monthly workbooks can be backed up and restored.
13. Existing acceptance tests remain green, and new feature tests pass.

## 15. Dependencies and unresolved decisions

-   Confirm exact existing patient and transaction IDs and canonical
    field names.
-   Confirm which existing tabs remain authoritative during the
    transition.
-   Confirm whether monthly routing applies to all four transaction
    categories at once or in staged increments.
-   Confirm whether `Billing` includes line items in the same tab or
    uses the existing `Invoice_Items` model.
-   Confirm Apps Script deployment mode and secure caller identity
    validation.
-   Confirm clinic Drive ownership model and sharing permissions.
-   Confirm migration/backfill date range and retention policy.
-   Confirm peak concurrency and number of clinics.
-   Confirm whether the existing product's single-writer assumption
    remains unchanged.

## 16. Change-control rule

Any change to existing modules, screens, workflows, permissions, local
database authority, technology stack, or clinical scope must be
documented as a separate change request and approved before
implementation. This feature PRD authorizes only the additive monthly
storage, index, sync, and backup integration described above.

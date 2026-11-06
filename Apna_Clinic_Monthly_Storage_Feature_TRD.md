# Apna Clinic --- Monthly Google Sheets Storage & Apps Script Integration

## Feature Technical Requirements Document (Feature TRD)

**Version:** 1.1\
**Date:** 4 November 2026\
**Status:** Feature specification for integration into the existing Apna
Clinic application\
**Parent documents:** Existing Apna Clinic PRD v1.0 and TRD v1.0\
**Change type:** Additive feature only

------------------------------------------------------------------------

## 1. Purpose and relationship to the existing technical design

This document describes how to add monthly Google Sheets storage, Apps
Script routing, patient-history indexing, and sync enhancements to the
already-developed Apna Clinic application.

**It is not a replacement architecture.** The existing TRD remains
authoritative for the current Flutter Web app, state management,
routing, local database, domain modules, Google OAuth baseline,
printing, security, and deployment.

Implement only the extensions specified here. Do not rebuild the
frontend, replace the local database, rewrite existing modules, or
change existing data semantics as part of this feature.

If a proposed integration conflicts with the current implementation,
stop and document the conflict. Do not silently replace the current
implementation.

## 2. Existing architecture to retain

The parent TRD establishes the existing baseline, including:

-   Flutter Web and the current Dart application structure.
-   Existing state management, navigation, and UI implementation.
-   Browser IndexedDB/local-first storage and the existing sync/outbox
    approach.
-   Existing Google OAuth flow and Google Sheets/Drive integration.
-   Existing clinic master workbook and canonical tab schemas.
-   Existing patient, appointment, visit, queue, billing, payment,
    refund, expense, follow-up, reporting, and backup modules.
-   Existing single-writer MVP constraint.
-   Existing security, privacy, encryption, and clinical boundaries.

The feature must integrate with these components through
adapters/services. It must not create parallel duplicate patient,
billing, or appointment modules.

## 3. Target integration architecture

``` text
Existing Flutter Web application
  |
  +-- Existing UI and domain modules (unchanged)
  |
  +-- Existing IndexedDB/local repositories (retained)
  |      |
  |      +-- Existing local records and cache
  |      +-- Existing outbox, extended if required
  |      +-- New month-routing/sync metadata
  |
  +-- Existing Google sign-in/session context
  |
  +-- New MonthlyStorageSyncAdapter
         |
         | authenticated, versioned, batched request
         v
      Google Apps Script integration service
         |
         +-- caller/clinic authorization
         +-- idempotency and request validation
         +-- master workbook resolver
         +-- monthly workbook registry/provisioner
         +-- transaction batch writer
         +-- patient-history index updater
         +-- reconciliation and sync manifest
         |
         +--> Existing clinic master workbook (extended, not replaced)
         |
         +--> Monthly transaction workbooks
         |
         +--> Existing Google Drive backup/export structure
```

### 3.1 Architectural boundary

Apps Script is introduced as a narrowly scoped cloud integration/service
layer for: - Resolving or provisioning monthly workbooks. - Routing
batches to the correct workbook. - Updating patient-to-month indexes. -
Maintaining sync manifests and reconciliation metadata. - Returning
records for cross-month patient-history retrieval.

It does not own UI behavior, local validation UX, patient workflow state
machines, printing, or all application business logic. Existing
client-side/domain logic remains in place unless a specific server-side
validation is required for data integrity/security.

### 3.2 Existing direct Google API usage

The parent TRD currently describes direct Google OAuth/Sheets/Drive
access from the Flutter Web application. Adding Apps Script introduces a
second access path unless deliberately scoped.

For this feature: - New monthly workbook provisioning, registry changes,
batch routing, and cross-month index operations should go through the
Apps Script adapter. - Existing direct Sheets/Drive operations must not
be removed or redirected globally as part of this feature. - Avoid
writing the same logical record through both paths. - Define one
authoritative write path per record type during each rollout phase. - If
a record type is migrated to Apps Script routing, disable only its
previous cloud-write path after parity and rollback tests pass. -
Existing backup/export operations remain on their current path until
explicitly integrated.

This hybrid transition is intentional and must be documented per
operation to prevent duplicate writes.

## 4. Code-level integration points

Add new modules alongside the existing code; adapt names to the
repository's actual conventions.

Suggested Flutter additions:

-   `monthly_storage/models/month_registry_entry.dart`
-   `monthly_storage/models/patient_history_index_entry.dart`
-   `monthly_storage/models/sync_batch.dart`
-   `monthly_storage/data/monthly_storage_api.dart`
-   `monthly_storage/data/apps_script_client.dart`
-   `monthly_storage/data/monthly_storage_repository.dart`
-   `monthly_storage/domain/month_resolver.dart`
-   `monthly_storage/domain/patient_history_router.dart`
-   `monthly_storage/domain/monthly_sync_coordinator.dart`
-   `monthly_storage/domain/reconciliation_service.dart`

Suggested Apps Script additions:

-   `EntryPoint.gs`
-   `RequestRouter.gs`
-   `CallerAuthService.gs`
-   `ClinicAccessService.gs`
-   `MonthlyWorkbookRegistry.gs`
-   `MonthlyWorkbookProvisioner.gs`
-   `PatientHistoryIndexService.gs`
-   `TransactionBatchService.gs`
-   `IdempotencyService.gs`
-   `SyncManifestService.gs`
-   `ReconciliationService.gs`
-   `SheetsRepository.gs`
-   `DriveRepository.gs`
-   `Validation.gs`

These are additive module suggestions, not a mandate to reorganize
existing folders or rename existing classes.

## 5. Data model changes

### 5.1 Preserve existing entity schemas

The parent TRD's canonical headers remain the baseline. Do not rename or
remove existing fields. The new monthly storage design should reuse
existing identifiers and field names.

Before implementing, map each existing entity to its current source
table/tab and confirm exact headers from the code and template workbook.

### 5.2 Master workbook extensions

Add the following tabs to the existing clinic master workbook only if
equivalent structures do not already exist:

#### `Spreadsheet_Registry`

Suggested columns:

``` csv
clinic_id,year_month,spreadsheet_id,status,schema_version,created_at,created_by,last_verified_at
```

Purpose: map a clinic and calendar month to the monthly transaction
workbook's immutable spreadsheet ID.

#### `Patient_History_Index`

Suggested columns:

``` csv
clinic_id,patient_id,year_month,record_type,first_record_at,last_record_at,record_count,last_updated_at
```

Purpose: route a patient history request to the months and record types
that contain the patient's data. One row per patient/month/record type
is preferred over a large serialized month list.

#### `Sync_Manifest` extension

Reuse the existing `Sync_Manifest` tab defined in the parent TRD. Add
fields only if absent:

``` csv
batch_id,clinic_id,device_id,first_event_id,last_event_id,event_count,checksum,schema_version,status,created_at,confirmed_at,last_error_code
```

Do not create a duplicate `Sync_Manifest` if the current one already
contains equivalent fields. Map the existing schema first.

### 5.3 Monthly transaction workbooks

Naming convention:

`ApnaClinic_<clinic_id>_Transactions_YYYY_MM`

Initial tabs for the requested partitioning:

-   `Appointments`
-   `Visits`
-   `Billing`
-   `Payments`

Where the existing implementation stores related data separately,
preserve that structure. For example, if invoice line items, refunds,
expenses, and queue events are already separate entities, decide
explicitly whether they are stored in the same monthly workbook in
separate tabs or remain in their existing workbook during the first
phase.

Do not collapse existing `Invoices` and `Invoice_Items` into one
`Billing` table if doing so would change the current data model.
`Billing` may be a workbook label or tab name only after a field-level
mapping is approved.

### 5.4 Patient master data

The existing `Patients` tab is the source schema in the parent TRD. Do
not create a second independent patient directory unless a migration
design requires it.

If the master tab is renamed or mirrored as `Patients_Master`, the
change must be handled as a schema migration: - Preserve every existing
`patient_id`. - Preserve consent and audit metadata. - Verify record
counts and field mappings. - Maintain a rollback copy. - Keep one
clearly defined authoritative patient master after cutover.

## 6. Month resolution and workbook provisioning

### 6.1 Month resolution

-   Resolve month using the clinic's configured timezone, not the
    browser's arbitrary timezone.
-   Use the business date associated with the existing record/workflow.
-   Store the month key in `YYYY-MM` format.
-   Define handling for late-entered records and edits to records from a
    previous month; do not automatically route them to the current month
    if their business date belongs to an earlier month.

### 6.2 Provisioning algorithm

1.  Receive authenticated clinic context and target `yearMonth`.
2.  Validate clinic membership and permission.
3.  Look up `(clinic_id, year_month)` in `Spreadsheet_Registry`.
4.  If a valid active entry exists, return its registered spreadsheet
    ID.
5.  Otherwise acquire a short critical-section lock.
6.  Recheck the registry after acquiring the lock.
7.  Create a workbook in the clinic's existing Drive folder.
8.  Create required tabs and exact versioned headers using the approved
    schema mapping.
9.  Apply the existing clinic Drive sharing policy.
10. Validate workbook structure and permissions.
11. Write the registry row with `ACTIVE` status.
12. Release the lock and return the workbook reference.

Provisioning must be idempotent. If creation fails midway, mark the
entry `ERROR`/`PROVISIONING` or discover the partially created file by a
deterministic provisioning marker before retrying. Do not create
multiple active workbooks for the same clinic/month.

## 7. Transaction routing

For each cloud-bound batch:

1.  Validate caller, clinic membership, role, request schema, and
    payload size.
2.  Validate every operation's stable ID and idempotency key.
3.  Determine target month using the record's business date and clinic
    timezone.
4.  Group operations by clinic, month, and destination tab.
5.  Resolve workbook IDs from `Spreadsheet_Registry`.
6.  Provision missing monthly workbooks where permitted.
7.  Batch append/update operations to the correct tabs.
8.  Update `Patient_History_Index` for affected patients.
9.  Update the existing `Sync_Manifest` checkpoint.
10. Return per-operation canonical results and failures.
11. Client updates local sync state only after confirmed response.

The service must not treat an entire batch as successful if some
operations failed. Return per-operation status or a clearly defined
atomic batch result. Keep batch sizes bounded to fit Apps Script
execution and Sheets request limits.

## 8. Patient-history retrieval

1.  The existing patient module supplies the existing `patient_id`.
2.  Apps Script validates caller and patient access.
3.  Query `Patient_History_Index` for that patient and clinic.
4.  Group index entries by month and record type.
5.  Resolve monthly workbook IDs from `Spreadsheet_Registry`.
6.  Read only the relevant records.
7.  Normalize results to the existing client entity models.
8.  Sort chronologically and return pagination/partial-result metadata.
9.  The existing UI presents the result using its current
    patient-history patterns.

Do not scan every monthly workbook. If the index is missing or
inconsistent, return a partial/unavailable status and schedule
reconciliation; do not silently claim history is complete.

## 9. API contract for the new adapter

Use the existing project's request conventions where possible. The
following is a logical contract; adapt transport details to the actual
deployed Apps Script web app and existing networking client.

### 9.1 Request envelope

``` json
{
  "apiVersion": "v1",
  "action": "monthlyStorage.syncBatch",
  "requestId": "uuid",
  "clinicId": "existing-clinic-id",
  "idempotencyKey": "stable-batch-id",
  "payload": {
    "operations": []
  }
}
```

The client-supplied clinic ID is context only. The backend must
independently verify access.

### 9.2 Response envelope

``` json
{
  "apiVersion": "v1",
  "requestId": "uuid",
  "ok": true,
  "data": {
    "results": []
  },
  "error": null,
  "meta": {
    "traceId": "server-trace-id",
    "serverTime": "ISO-8601"
  }
}
```

Errors must use stable codes, for example: - `UNAUTHENTICATED` -
`FORBIDDEN` - `INVALID_REQUEST` - `DUPLICATE_OPERATION` -
`IDEMPOTENCY_CONFLICT` - `MONTH_WORKBOOK_UNAVAILABLE` - `QUOTA_LIMIT` -
`TEMPORARY_FAILURE` - `PARTIAL_FAILURE`

Do not return stack traces, privileged IDs, tokens, or internal secrets
to the client.

### 9.3 Minimum actions

-   `monthlyStorage.resolveMonth`
-   `monthlyStorage.provisionMonth`
-   `monthlyStorage.syncBatch`
-   `monthlyStorage.getPatientHistory`
-   `monthlyStorage.getSyncStatus`
-   `monthlyStorage.reconcilePatientIndex`
-   `monthlyStorage.listMonthsForClinic`

These actions extend the existing API surface; they do not replace
unrelated endpoints or client repositories.

## 10. Idempotency and partial-failure handling

-   Each outbox operation retains its existing stable local operation
    ID.
-   The adapter sends a stable idempotency key on every retry.
-   The server stores operation key, clinic, action, payload hash,
    processing state, and canonical result ID.
-   Same key and same payload returns the original result.
-   Same key with different payload returns `IDEMPOTENCY_CONFLICT`.
-   A transaction append and index update are not a true cross-workbook
    transaction. Record the transaction's immutable ID first, then
    update index/manifest, and reconcile incomplete secondary updates.
-   Reconciliation must be repeatable and safe.
-   Do not delete local outbox entries until the server has confirmed
    the operation and the local mapping/checkpoint is persisted.

## 11. IndexedDB and existing sync integration

Do not replace the current IndexedDB database or sync coordinator.

Inspect the existing schema first. Add only the missing metadata, for
example: - `yearMonth` - `cloudWorkbookId` (only if safe and useful;
registry remains authoritative) - `syncBatchId` - `cloudSyncStatus` -
`lastCloudSyncAt` - `serverRecordId` (only if existing local IDs are not
already canonical)

Extend the existing outbox payload with versioned routing metadata only
where necessary. Do not duplicate the same pending operation in two
outboxes.

Existing local writes remain available offline. The new sync coordinator
should be invoked by the existing sync lifecycle and respect existing
single-writer rules.

## 12. Direct Sheets/Drive calls and migration of write paths

The parent TRD describes direct Google API usage. The feature adds Apps
Script for monthly routing; this requires a controlled hybrid boundary.

Create an operation ownership matrix before coding:

  ------------------------------------------------------------------------
  Operation         Existing path      Feature path      Cutover rule
  ----------------- ------------------ ----------------- -----------------
  Existing clinic   Existing           No change unless  Keep existing
  onboarding        OAuth/Drive flow   provisioning      
                                       integration is    
                                       needed            

  Existing local    Existing           Cloud batch route Keep local flow
  patient           IndexedDB/domain   after local       
  registration      flow               commit            

  Patient master    Existing Sheets    Apps Script only  One writer at a
  cloud write       path               after             time
                                       parity/cutover    

  Monthly           Existing Sheets    Apps Script       Feature-flagged
  transaction cloud path               monthly router    migration
  write                                                  

  Patient history   Existing/local     Master index +    Fall back during
  lookup            path               month resolver    pilot

  Existing          Existing Drive     Integrate monthly Do not remove
  backup/export     path               files into backup existing backup
                                       manifest          
  ------------------------------------------------------------------------

No record may be written to both the old and new cloud path unless a
temporary shadow-write mode is explicitly enabled for testing, with
deduplication and reconciliation. Shadow writes must not be treated as
production authority.

## 13. Security and Apps Script deployment

Security must preserve the parent TRD's OAuth, least-privilege,
encryption, privacy, and role rules.

Before release, prove: - How the Apps Script endpoint identifies the
caller. - How the existing Google sign-in/session is validated. - How
clinic membership and role are loaded from trusted data. - Whether the
script executes as the accessing user or owner, and the implications. -
How Drive/Sheets permissions prevent cross-clinic access. - How
deployment versioning, revocation, and rollback work.

Do not assume that an Apps Script web app deployed to execute as its
owner automatically provides safe user-level authorization. Do not send
an owner refresh token or privileged service credential to the browser.

## 14. Quota and performance controls

The parent TRD's local-first API-minimization principles remain in
force.

-   No cloud call per keystroke, local search, token generation,
    printing, or local calculation.
-   Batch writes by clinic/month/tab.
-   Cache registry entries with bounded validity and revalidation.
-   Query history through the index.
-   Apply bounded payload and batch sizes.
-   Add per-clinic and global rate controls.
-   Retry transient quota/server errors with exponential backoff and
    jitter.
-   Avoid tight retry loops.
-   Record request counts, execution duration, error class, and quota
    failures without logging patient payloads.
-   Verify current Apps Script, Sheets, and Drive quotas for the actual
    account and deployment configuration.
-   Load-test at 4,000--5,000 patients/month and an agreed
    peak-concurrency profile. Monthly volume alone is not a capacity
    test.

## 15. Backup and restore integration

Extend the existing backup process rather than replacing it.

-   Include the existing master workbook and every active monthly
    transaction workbook.
-   Store workbook IDs, month keys, schema versions, checksums, and
    backup timestamps in the backup manifest.
-   Preserve existing encrypted snapshot and key-recovery behavior.
-   Apply existing Drive folder ownership and access controls.
-   Restore the master workbook and monthly workbooks as one logical
    clinic dataset.
-   Verify registry references, patient-history index, patient counts,
    transaction counts, and invoice/payment/refund reconciliation.
-   Do not enable writes after restore until integrity checks pass.

## 16. Migration plan

### Phase A --- Discovery and mapping

-   Inspect actual Flutter repositories, IndexedDB schema, sync
    coordinator, Google API calls, and workbook templates.
-   Map current entity fields and identifiers to monthly tabs.
-   Identify all existing write paths.
-   Decide which tabs remain master data and which transaction records
    move monthly.

### Phase B --- Additive foundation

-   Add registry/index tabs or extend equivalent existing tabs.
-   Add Apps Script endpoint and authorization proof.
-   Add client adapter and feature flag.
-   Do not change current production write path yet.

### Phase C --- Controlled test migration

-   Provision monthly workbooks in a test clinic.
-   Backfill a bounded sample.
-   Compare source and destination row counts, IDs, amounts, dates, and
    references.
-   Test cross-month history and rollback.

### Phase D --- Feature-flagged cutover

-   Enable monthly routing for one transaction type at a time.
-   Ensure exactly one authoritative cloud writer per record type.
-   Monitor failures, duplicates, quota consumption, and history
    completeness.
-   Retain rollback path until acceptance criteria pass.

### Phase E --- Pilot and rollout

-   Pilot with limited clinics.
-   Run restore drills and peak-load tests.
-   Expand gradually after product and engineering sign-off.

## 17. Testing requirements

### 17.1 Regression tests

All existing parent-TRD test areas must continue to pass: - Patient
registration and lookup. - Appointment booking and rescheduling. -
Queue/token allocation. - Consultation slip generation and printing. -
Billing, partial payments, refunds, and reconciliation. - Dashboard and
reports. - Staff roles and permissions. - Offline operation and local
persistence. - Existing backup/restore. - Existing
subscription/licensing behavior.

### 17.2 Feature tests

-   Correct month resolution at timezone boundaries.
-   Month workbook provisioning and idempotent retry.
-   Registry uniqueness for clinic/month.
-   Batch routing by record date.
-   Patient ID preservation.
-   Cross-month history retrieval and pagination.
-   Index repair after partial failure.
-   Duplicate request replay and payload mismatch.
-   Quota and timeout behavior.
-   Feature-flag rollback.
-   Backup/restore across multiple months.
-   Cross-clinic authorization attempts.

### 17.3 Acceptance gate

The feature cannot be released if any existing core workflow regresses,
any patient ID changes unexpectedly, any transaction is duplicated/lost,
or a user can access another clinic's workbook.

## 18. Rollback strategy

-   Feature flags must disable new monthly routing without disabling the
    existing application.
-   Existing local records remain intact.
-   Monthly workbooks already created must be retained and reconciled;
    rollback must not delete them.
-   Re-enable the prior cloud write path only after verifying which
    records were committed to the new path.
-   Use idempotent import/replay to avoid duplicates during rollback.
-   Keep a migration ledger showing each clinic, month, record type,
    cutover state, and last verified checkpoint.

## 19. Open technical decisions

1.  Exact current IndexedDB schema and outbox shape.
2.  Exact existing patient/transaction identifiers and field headers.
3.  Which existing tabs remain authoritative after rollout.
4.  Apps Script caller authentication and deployment identity.
5.  Which transaction types move first.
6.  Whether old and new cloud paths can be shadow-tested safely.
7.  Month handling for late edits and backdated records.
8.  Peak concurrency and clinic count.
9.  Backup manifest format and retention.
10. Criteria for moving beyond Sheets/Apps Script if quotas or
    concurrency become limiting.

## 20. Change-control rule

No changes to the existing Flutter architecture, local database
authority, UI modules, domain workflows, role model, printing,
subscription logic, or clinical scope are authorized by this feature TRD
unless separately approved. All implementation must be additive,
feature-flagged where practical, regression-tested, and reversible
during rollout.

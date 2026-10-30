# Firebase Architecture

**Status:** Draft v1 — 30 Oct 2026
**Companion to:** [FEATURES.md](FEATURES.md). Feature behaviour is defined there; this document defines how it is stored and secured.

---

## 1. Decisions

| Topic | Decision |
|---|---|
| Firebase project | One new project, Blaze plan. No separate dev project; test data is created and cleaned by hand before go-live. |
| Region | `asia-south1` (Mumbai) for Firestore, Storage, and Functions. Closest region to Pakistan. |
| Structure | Top-level collections. Every record carries `branchId`. One branch document exists today. |
| Auth | Firebase Auth, email and password. Roles stored in custom claims and mirrored in the user document. Admin creates users through a Cloud Function. |
| Patient ID | `YY-NNNNN`, e.g. `26-00341`. Assigned by a Cloud Function on sync. Offline, a temporary ID `T-XXXXX` is shown. |
| Token | Department code plus daily sequence per doctor, e.g. `E-12`, `H-5`. Resets at midnight Asia/Karachi. Generated on the client. |
| Visit types | Each belongs to one department. |
| Appointments | Date plus free-text time. No slot grid, no working hours. |
| Deletes | Soft delete with reason. `deleted: true` hides the record from lists and totals. |
| Dashboard | Reads only `dailySummaries`, which a Cloud Function recomputes whenever a visit, sale, or expense for that day changes. |
| Inventory | No batch or expiry tracking. Suppliers and purchase bills are tracked; a purchase creates an expense. |
| Payouts | Admin chooses any date range. Payout = salary amount entered by Admin (prefilled with monthly salary) plus share of fees in the range. |
| Family rules | Patient may have a personal phone. Patient can be moved between families. Family phone can be changed. |
| Queue | Doctor sees only their own queue. |
| Timezone | Asia/Karachi for day boundaries. |
| Backup | Daily Firestore export at 02:00 Karachi to a Cloud Storage bucket, 30-day retention. |
| Reminders | No reminders collection. The "due today" list is a query over appointments. Sent state is stored on the appointment. |

---

## 2. Services Used

| Service | Purpose |
|---|---|
| Firestore | All application data. Offline persistence enabled on reception web. |
| Authentication | Email/password login, custom claims for roles. |
| Cloud Storage | Report files, prescription photos, clinic logo. |
| Cloud Functions (2nd gen, TypeScript, Node 22) | User management, patient number assignment, daily summaries, audit log, scheduled backup. |
| Hosting | Reception and Admin web app. |
| App Check | Enabled for web and mobile to block requests from outside the app. |

---

## 3. Conventions

- Document IDs are Firestore auto-IDs unless stated.
- `branchId` on every business document. Default branch ID is `main`.
- Dates that mean "a clinic day" are stored as strings `YYYY-MM-DD` computed in Asia/Karachi, so they are queryable and unambiguous offline.
- Timestamps use `createdAt: serverTimestamp()` plus `createdAtLocal` (client clock) because `serverTimestamp` is null in the local cache until sync.
- Money is stored as integer PKR. No decimals.
- Names denormalised onto visits (`patientName`, `doctorName`, `visitTypeName`) so lists and receipts need one read and keep history even if the source is renamed.
- Fields `deleted`, `deletedAt`, `deletedBy`, `deleteReason` appear on any soft-deletable document. Queries always filter `deleted == false`.
- `searchKeys` is an array of lowercase prefixes used for name search (first 3 to 12 characters of each word) because Firestore has no substring search.

---

## 4. Collections

### 4.1 `branches/{branchId}`
```
name, address, phone, active, createdAt
```

### 4.2 `settings/general`  (single document)
```
clinicName, logoUrl, address, phone, receiptFooter,
defaultReceiptCopies: 1,
followUpReminderDays: 0,
reminders: { appointment: true, followUp: true, postOp: true },
whatsappTemplates: { appointment: "...", followUp: "...", postOp: "...", adhoc: "..." },
timezone: "Asia/Karachi",
updatedAt, updatedBy
```

### 4.3 `users/{uid}`
ID is the Auth UID.
```
email, displayName, roles: ["reception" | "doctor" | "admin"],
doctorId (nullable), active, branchIds: ["main"],
mustChangePassword, createdAt, createdBy
```
Roles are also written to Auth custom claims `{ roles: [...], doctorId, branchIds }` by the `setUserRoles` function. Security rules read claims, not this document.

### 4.4 `departments/{departmentId}`
```
name: "Eye", code: "E", sortOrder, active, createdAt
```
Seeded with Eye (`E`) and Homeopathy (`H`). `code` must be unique; it prefixes tokens.

### 4.5 `doctors/{doctorId}`
```
userId, name, departmentId, departmentCode, specialisation,
salary (monthly PKR), sharePercent, shareBasis: "gross" | "net",
fees: { [visitTypeId]: amount },        // fee schedule embedded
active, branchId, createdAt, updatedAt
```
Fee schedule is a map on the doctor so reception loads one document per doctor. Fee changes are audited by the `auditDoctors` trigger.

### 4.6 `visitTypes/{visitTypeId}`
```
departmentId, name, isOperation, isFollowUp, sortOrder, active,
defaultPreOpChecklist: [ { id, label } ],     // operation types only
defaultPostOpDays: [1, 7, 30],                 // operation types only
createdAt, updatedAt
```
Each department is seeded with Checkup and Follow-up (`isFollowUp: true`). Eye also gets Eye Test. Operation types are added by Admin.

### 4.7 `families/{familyId}`
```
phone, headName, address, patientCount, branchId, createdAt, updatedAt
```
`phone` is indexed and unique in practice (checked on client before create; a Function flags duplicates created offline).

### 4.8 `patients/{patientId}`
```
patientNo (nullable until assigned, e.g. "26-00341"),
tempNo ("T-7K3M9"),
familyId, name, gender, dateOfBirth (nullable), ageYears (nullable),
personalPhone (nullable),
phones: [familyPhone, personalPhone],   // denormalised for array-contains search
address, notes, searchKeys: [],
visitCount, lastVisitAt, lastDoctorId,
branchId, createdAt, createdAtLocal, createdBy, updatedAt
```
Moving a patient to another family updates `familyId` and `phones`, and adjusts `patientCount` on both families in one batch. Changing a family phone fans out to `phones` on every patient of that family (client batch, families are small).

### 4.9 `counters/{counterId}`
```
patients_2026: { value: 341 }
```
Only Cloud Functions write here. Tokens do not use counters.

### 4.10 `appointments/{appointmentId}`
```
patientId, patientName, patientNo, phone,
doctorId, doctorName, departmentId,
date ("YYYY-MM-DD"), time ("10:30" or ""), 
source: "manual" | "followUp" | "postOp",
operationId (nullable), prescriptionId (nullable),
status: "booked" | "arrived" | "cancelled" | "noShow",
visitId (set when arrived),
reminderSentAt (nullable), reminderSentBy (nullable),
notes, branchId, createdAt, createdBy, updatedAt
```
Follow-ups from a prescription and post-op follow-ups are appointments with `source` set and `time` empty. The reminders-due-today screen is three queries over this collection.

### 4.11 `visits/{visitId}`
```
patientId, patientName, patientNo, phone, familyId,
doctorId, doctorName, departmentId, departmentCode,
visitTypeId, visitTypeName, isOperation, isFollowUp,
token: 12, tokenLabel: "E-12",
date ("YYYY-MM-DD"), createdAt, createdAtLocal,
fee, discountAmount, discountReason, netAmount,
paymentMethod: "cash" | "bank" | "jazzcash" | "easypaisa", paymentRef,
status: "waiting" | "inProgress" | "completed",
startedAt, completedAt,
appointmentId, operationId, saleId, hasPrescription,
receiptCopies,
deleted: false, deletedAt, deletedBy, deleteReason, editReason,
branchId, createdBy
```
Visits are written by reception and only edited by Admin, except `status`, `startedAt`, `completedAt`, `hasPrescription`, which the assigned doctor may update. Rules enforce this field by field.

**Token generation (client):** query the local cache for `visits` where `doctorId == X and date == today`, take `max(token) + 1`, label with `departmentCode`. Single reception device, so no conflict handling in v1.

### 4.12 `prescriptions/{visitId}`
ID equals the visit ID. Separate from the visit so doctor writes never collide with reception writes.
```
visitId, patientId, doctorId, departmentId, date,
mode: "typed" | "photo" | "both",
eye: { od: { sph, cyl, axis, add, va }, os: { sph, cyl, axis, add, va } },  // Eye only
homeo: [ { medicine, potency, dosage, duration } ],                          // Homeo only
diagnosis, advice,
photoPaths: [ "patients/{patientId}/prescriptions/{visitId}/1.jpg" ],
followUpDate (nullable), followUpAppointmentId (nullable),
createdAt, updatedAt
```

### 4.13 `reports/{reportId}`
```
patientId, visitId (nullable), title,
storagePath, downloadUrl, mimeType, sizeBytes,
uploadedBy, uploadedAt, branchId, deleted
```

### 4.14 `operations/{operationId}`
```
patientId, patientName, visitId, visitTypeId, visitTypeName,
surgeonDoctorId, surgeonName, departmentId,
scheduledDate, status: "scheduled" | "done" | "cancelled",
checklist: [ { id, label, done, doneBy, doneAt } ],   // copied from visit type, patient items may be added
checklistOverrideReason (nullable),
postOpDays: [1, 7, 30],                                 // copied from visit type, editable
followUpAppointmentIds: [],
notes, createdAt, createdBy, updatedAt, branchId
```
When `scheduledDate` is set or `postOpDays` changes, the client regenerates the post-op appointments (cancels old, creates new) in one batch.

### 4.15 `inventoryItems/{itemId}`
```
category: "medicine" | "frame" | "lens" | "consumable",
name, brand, unit, purchasePrice, salePrice,
stock, lowStockThreshold,
lens: { type: "singleVision" | "bifocal" | "progressive", sph, cyl },   // lens only
lensKey: "singleVision|-1.25|-0.50",                                      // lens only, unique per power
searchKeys, active, branchId, createdAt, updatedAt
```
Stock is changed only with `FieldValue.increment` inside a batch that also writes a `stockMovements` document. This stays correct offline.

### 4.16 `suppliers/{supplierId}`
```
name, phone, address, notes, active, createdAt
```

### 4.17 `purchases/{purchaseId}`
```
supplierId, supplierName, billNo, date,
items: [ { itemId, name, qty, unitCost, lineTotal } ],
total, note, expenseId, createdBy, createdAt, branchId
```
Client batch: create purchase, one `stockMovements` per line, increment each item's `stock`, create an `expenses` document with `source: "purchase"`.

### 4.18 `stockMovements/{movementId}`
```
itemId, itemName, qty (positive in, negative out),
type: "purchase" | "sale" | "operationUse" | "adjustment",
refId (purchaseId | saleId | operationId), reason,
createdBy, createdAt, branchId
```

### 4.19 `sales/{saleId}`
```
patientId (nullable), patientName, visitId (nullable), date,
items: [ { itemId, name, category, qty, unitPrice, lineTotal, lensKey } ],
subtotal, discountAmount, discountReason, total,
paymentMethod, paymentRef,
deleted, deletedAt, deletedBy, deleteReason,
createdBy, createdAt, createdAtLocal, branchId
```

### 4.20 `expenses/{expenseId}`
```
category: "rent" | "salary" | "utilities" | "supplies" | "purchase" | "payout" | "other",
amount, date, note,
source: "manual" | "purchase" | "payout", refId,
deleted, createdBy, createdAt, branchId
```

### 4.21 `payouts/{payoutId}`
```
doctorId, doctorName, periodStart, periodEnd,
salaryAmount, grossFees, discounts, netFees,
shareBasis, sharePercent, shareAmount, total,
paid, paidAt, paidBy, expenseId, note, createdAt, branchId
```
Fees in range are computed by the client from `dailySummaries.byDoctor` for the days in the period.

### 4.22 `dailySummaries/{YYYY-MM-DD}`
Written only by the `recomputeDailySummary` function.
```
date, branchId,
visits, newPatients, returningPatients,
grossFees, discounts, netFees,
byPayment: { cash, bank, jazzcash, easypaisa },
byDepartment: { [departmentId]: { visits, gross, discounts, net } },
byDoctor: { [doctorId]: { visits, gross, discounts, net } },
discountsByUser: { [uid]: { count, amount } },
discountsByReason: { [reason]: { count, amount } },
salesTotal, salesDiscounts, salesByCategory: { medicine, frame, lens, consumable },
expensesTotal, expensesByCategory: {},
netProfit,
updatedAt
```
Dashboard ranges sum these documents. A month is at most 31 reads.

### 4.23 `auditLogs/{logId}`
Written only by Cloud Functions.
```
collection, docId, action: "create" | "update" | "delete",
userId, userName, reason,
before: {}, after: {}, changedFields: [],
createdAt
```
Audited collections: `visits`, `sales`, `expenses`, `doctors`, `visitTypes`, `inventoryItems` (stock and prices), `users`, `settings`, `payouts`. The acting user is taken from `updatedBy` on the document, which rules force to equal `request.auth.uid`.

---

## 5. Cloud Functions

| Function | Trigger | Does |
|---|---|---|
| `createUser` | callable, Admin only | Creates Auth user with temporary password, writes `users/{uid}`, sets custom claims. |
| `setUserRoles` | callable, Admin only | Updates roles on the user doc and custom claims. Deactivation disables the Auth account. |
| `assignPatientNo` | `patients` onCreate | Transaction on `counters/patients_{YY}`, writes `patientNo`. |
| `recomputeDailySummary` | `visits`, `sales`, `expenses` onWrite | Reads all non-deleted documents for that `date` and rewrites `dailySummaries/{date}`. Idempotent, so retries are safe. Also counts new vs returning patients by comparing `patients.createdAt` date. |
| `audit*` | onWrite on audited collections | Writes `auditLogs` with before, after, and changed fields. |
| `checkDuplicateFamilyPhone` | `families` onCreate | If another family has the same phone, flags both with `duplicatePhone: true` for Admin to merge. |
| `dailyBackup` | scheduled 02:00 Asia/Karachi | `firestore.export` to `gs://<project>-backups/YYYY-MM-DD`. Bucket lifecycle rule deletes objects after 30 days. |

Functions never write to collections that clients also write, except `patientNo` and the duplicate flag. This keeps offline writes free of conflicts.

---

## 6. Security Rules (summary)

Roles come from `request.auth.token.roles`. Helper functions: `isAdmin()`, `isReception()`, `isDoctor()`, `isOwnDoctor(doctorId)`.

| Collection | Read | Create | Update | Delete |
|---|---|---|---|---|
| `settings`, `departments`, `visitTypes`, `doctors` | any signed-in | Admin | Admin | never |
| `users` | own doc, or Admin | Functions only | Admin (non-role fields), Functions (roles) | never |
| `families`, `patients` | any signed-in | Reception, Admin | Reception, Admin | never (soft) |
| `appointments` | any signed-in | Reception, Doctor, Admin | Reception, Doctor, Admin | never |
| `visits` | any signed-in | Reception, Admin | Admin any field; Doctor only `status`, `startedAt`, `completedAt`, `hasPrescription` on own visits | never (soft) |
| `prescriptions` | any signed-in | Doctor (own visit), Admin | Doctor (own), Admin | never |
| `reports` | any signed-in | Reception, Admin | Reception, Admin | never (soft) |
| `operations` | any signed-in | Doctor, Admin | Doctor, Reception (only `postOpDays`, `followUpAppointmentIds`), Admin | never |
| `inventoryItems` | any signed-in | Admin | Admin; Reception only `stock` via increment | never |
| `suppliers`, `purchases` | Admin | Admin | Admin | never |
| `stockMovements` | Admin | Reception, Admin | never | never |
| `sales` | any signed-in | Reception, Admin | Admin | never (soft) |
| `expenses`, `payouts` | Admin | Admin | Admin | never |
| `dailySummaries`, `auditLogs`, `counters` | Admin (`counters`: nobody) | Functions | Functions | never |

Additional rule checks:
- `branchId` must be in `request.auth.token.branchIds`.
- `createdBy` and `updatedBy` must equal `request.auth.uid`.
- `visits.discountAmount > 0` requires non-empty `discountReason`.
- `visits.netAmount == fee - discountAmount`.
- `deleted` may only be set to `true` by Admin with non-empty `deleteReason`.
- `dailySummaries` and `auditLogs` are read-only for clients.

---

## 7. Cloud Storage Layout

```
clinic/logo.png
patients/{patientId}/reports/{reportId}.{pdf|jpg|png}
patients/{patientId}/prescriptions/{visitId}/{n}.jpg
```
Rules: any signed-in user reads. Reception and Admin write under `reports`. Doctor and Admin write under `prescriptions`. Max 10 MB per file. Images are resized on the client to a maximum of 1600 px before upload.

---

## 8. Composite Indexes

| Collection | Fields |
|---|---|
| `visits` | `doctorId asc, date asc, deleted asc, token asc` (doctor queue) |
| `visits` | `patientId asc, deleted asc, createdAt desc` (history) |
| `visits` | `date asc, deleted asc, createdAt desc` (reception day list) |
| `appointments` | `doctorId asc, date asc, status asc` |
| `appointments` | `date asc, status asc, reminderSentAt asc` (reminders due) |
| `appointments` | `patientId asc, date desc` |
| `patients` | `phones array-contains, deleted asc` |
| `patients` | `searchKeys array-contains, name asc` |
| `patients` | `familyId asc, name asc` |
| `reports` | `patientId asc, deleted asc, uploadedAt desc` |
| `operations` | `surgeonDoctorId asc, status asc, scheduledDate asc` |
| `stockMovements` | `itemId asc, createdAt desc` |
| `inventoryItems` | `category asc, active asc, name asc` |
| `inventoryItems` | `category asc, lens.type asc, lens.sph asc, lens.cyl asc` (lens grid) |
| `sales` | `date asc, deleted asc, createdAt desc` |
| `expenses` | `date asc, deleted asc` |

Firestore will also prompt for any missing index on first use; the list above is the expected set.

---

## 9. Offline Strategy (Reception Web)

- Firestore persistence is enabled with `persistentLocalCache`. Single tab assumed.
- On login reception attaches live listeners to: `settings`, `departments`, `doctors`, `visitTypes`, `inventoryItems`, today's `visits`, today's and tomorrow's `appointments`, and the full `families` and `patients` collections. The full patient set is kept in the cache so phone and name search work offline. At 20,000 patients this is roughly 20 MB and a one-time read cost per device.
- Writes go to the local cache first and sync in the background. The UI shows an online/offline badge and a pending-write count from `waitForPendingWrites`.
- New patients get `tempNo` immediately; `patientNo` arrives after sync and the next receipt shows it.
- Tokens are computed from the cache. Receipt PDFs are generated on the client, so printing works offline.
- Uploads (reports) are queued by the app and sent when online; the report document is created only after the file upload succeeds.

---

## 10. Seed Data

On first deploy an Admin-only "Initial setup" screen creates: `branches/main`, `settings/general`, departments Eye and Homeopathy, visit types Checkup and Follow-up for each plus Eye Test, and the first Admin user is created with the Firebase console.

---

## 11. Cost Expectations

At 100 visits a day: roughly 15,000 reads and 3,000 writes a day from reception and doctors, plus function invocations. This is inside the free quota for Firestore; expected monthly bill is dominated by Storage egress for report files and the backup bucket, likely under 5 USD. The one-time cost of caching all patients on a new reception device is one read per patient.

---

## 12. Open Points

1. If a second reception device is ever added, token generation must move to a transaction or a Function. Not needed in v1.
2. `recomputeDailySummary` reads every visit of the day on each write. Fine at clinic scale; revisit above 1,000 visits a day.
3. Firestore cannot search by substring. Name search uses prefix keys; "contains" search would require Algolia or Typesense later.

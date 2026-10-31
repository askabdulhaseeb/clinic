# Clinic Management App — Feature Specification

**Status:** Draft v6 — 31 Oct 2026. All requirement questions resolved; Eye prescription form design deferred to UI phase. v6: budget decisions — prescriptions are typed only (no photos), no managed backup, dashboard totals kept by increments, Storage bucket in a US region for the no-cost quota. Storage design is in [FIREBASE_ARCHITECTURE.md](FIREBASE_ARCHITECTURE.md).
**Project:** `ramzan` (Flutter). Clinic name is not hard-coded; Admin sets it in Settings and it appears on receipts and the app header.

This document is the source of truth for what the app does. Code follows this document. Anything not written here is not a requirement yet.

---

## 1. Overview

A clinic management system for a single clinic with two departments today, **Eye** and **Homeopathy**, and more departments addable later by Admin. Multiple doctors work in each department.

Three user roles: **Reception**, **Doctor**, **Admin**. One person may hold more than one role and switches between them inside the app.

Reception runs on the **web** at the front desk and must keep working **offline**. Doctors and Admin use a **mobile app** (Android and iOS) and the **web**.

---

## 2. Decisions Summary

| Topic | Decision |
|---|---|
| Departments | Eye, Homeopathy. Admin can add more later. |
| Branches | One clinic now. Data model carries a branch ID so branches can be added later. |
| Platforms | Reception: web. Doctor and Admin: Android, iOS, web. |
| Offline | Reception web must work offline and sync when internet returns. |
| Backend | Firebase, Blaze plan, one project. Firestore, Auth, Storage, Cloud Functions, Hosting. |
| Cost target | Run inside Firebase no-cost quotas at up to 500 visits a day. Every design choice that costs reads, writes or storage is checked against this. See FIREBASE_ARCHITECTURE §11. |
| Backup | No managed backup in v1. Firestore's built-in replication is relied on. Admin can export any report to CSV. Decided 31 Oct 2026. |
| Language | English only. |
| Currency | PKR. |
| Payment methods | Cash, bank transfer, JazzCash, Easypaisa. |
| Partial payments | Not supported. Full payment at the visit. |
| Login | Email and password. Admin creates every account. |
| Roles per user | One user can hold multiple roles. |
| Patient arrival | Walk-in and booked appointments. Appointments have a date and a free-text time; no slot grid. |
| Patient lookup | Phone number search, printed patient ID (format 26-00341, assigned on sync). One phone covers a family. A patient may also have a personal phone, can be moved to another family, and a family phone can be changed. |
| Queue | Token per doctor with department prefix, e.g. E-12, H-5. Resets daily. Doctor sees only their own queue. |
| Fee setup | Per doctor and per visit type. |
| Follow-up | Separate reduced follow-up fee per doctor. |
| Discounts | Reception can give any amount. Reason is required. Admin sees every discount. |
| Receipts | A4 print. One copy by default; reception can change the copy count before printing. |
| Prescriptions | Typed with structured fields only. No photo of paper prescriptions (decided 31 Oct 2026 to stay inside free storage). |
| Reports | Reception uploads reports the patient brings in. |
| History visibility | Every doctor sees the patient's full history across all departments. |
| Operations | Schedule a date, pre-op checklist (Admin and doctors maintain the default list), post-op follow-up reminders (default days per operation type, changeable per patient). |
| Inventory | Homeo medicines, frames, lenses stocked by power (SPH/CYL), consumables. No batch or expiry tracking. Suppliers and purchase bills tracked; a purchase creates an expense. |
| Doctor pay | Salary plus percentage of fees. Admin chooses per doctor whether the percentage applies to gross fee or net fee after discount. Payouts are for any date range Admin picks. |
| Analytics | Revenue, patient counts, discounts, expenses and net profit. Read from daily summaries, updated within seconds of each transaction. Timezone Asia/Karachi. |
| Patient reminders | WhatsApp via WhatsApp Web already open on the reception PC. App opens a pre-filled message, staff press send. No Business API. Admin can turn each reminder type on or off. |
| Edit/delete visits | Admin only. Delete is a soft delete with a reason; the record stays visible to Admin. |
| Old data | None. New clinic, start fresh. |
| Reception devices | One reception device for now. Offline token conflicts between devices are not handled in v1. |
| Doctor sees money | Yes. Doctor sees fee, discount, and net paid on each visit. |

---

## 3. Roles and Permissions

| Action | Reception | Doctor | Admin |
|---|:-:|:-:|:-:|
| Register and edit patients | ✓ | | ✓ |
| Create visit, issue token, take payment | ✓ | | ✓ |
| Give discount (reason required) | ✓ | | ✓ |
| Book, reschedule, cancel appointments | ✓ | | ✓ |
| Upload patient reports | ✓ | | ✓ |
| Print receipt | ✓ | | ✓ |
| Sell inventory items | ✓ | | ✓ |
| View own queue | | ✓ | ✓ |
| View patient full history | | ✓ | ✓ |
| Write prescription and notes | | ✓ | |
| Schedule operation, fill pre-op checklist | | ✓ | ✓ |
| Edit default pre-op checklist and default post-op days | | ✓ | ✓ |
| Change post-op follow-up days for one patient | ✓ | ✓ | ✓ |
| Send WhatsApp message (opens WhatsApp Web) | ✓ | ✓ | ✓ |
| Edit or delete a saved visit | | | ✓ |
| Manage users, roles, doctors, departments | | | ✓ |
| Manage fee schedule and visit types | | | ✓ |
| Manage inventory stock and prices | | | ✓ |
| Record expenses and salaries | | | ✓ |
| View analytics and reports | | | ✓ |
| Export data | | | ✓ |
| Clinic settings (name, logo, receipt text) | | | ✓ |
| View audit log | | | ✓ |

A user with two roles sees a role switcher. Permissions are the union of their roles.

---

## 4. Core Concepts (Data Model)

- **Branch** — one record now. Every other record stores a `branchId`.
- **Department** — name, active flag. Seeded with Eye and Homeopathy.
- **Doctor** — linked to a user account, department, specialisation, salary, revenue share percentage, share basis (gross fee or net fee after discount), active flag.
- **Visit Type** — belongs to one department. Each department has Checkup and Follow-up; Eye also has Eye Test; operation types such as Cataract Surgery, added by Admin. Each has a flag for whether it is an operation. Operation types also carry a default pre-op checklist and default post-op follow-up days (e.g. 1, 7, 30). Admin and doctors can edit these defaults.
- **Fee Schedule** — one row per doctor per visit type: amount in PKR. Follow-up has its own reduced amount per doctor.
- **Family** — a phone number that groups patients. Head of family name and address.
- **Patient** — patient ID (auto, printed), name, age or date of birth, gender, phone (via family), address, notes, created date.
- **Appointment** — patient, doctor, date, free-text time, source (manual, follow-up, post-op), status (booked, arrived, cancelled, no-show), reminder sent marker.
- **Visit** — patient, doctor, department, visit type, token number, date and time, fee, discount amount, discount reason, net paid, payment method, created by, status (waiting, in progress, completed). Immutable after save except by Admin.
- **Prescription** — belongs to a visit. Typed fields only. Eye: SPH, CYL, AXIS, ADD, VA for right and left eye, plus free notes. Homeo: list of medicine, potency, dosage, duration, plus free notes. Printable.
- **Report** — belongs to a patient, optionally to a visit. Title, file (PDF or image), uploaded by, date.
- **Operation** — linked to a visit of an operation type. Scheduled date, surgeon, pre-op checklist items copied from the type's default with done flags (extra items can be added for this patient), post-op follow-up days copied from the type's default and editable for this patient, status.
- **Inventory Item** — category (medicine, frame, lens, consumable), name, unit, purchase price, sale price, stock on hand, low-stock threshold. Frames and lenses are separate items; a glasses sale is a frame line plus one or two lens lines.
- **Lens Item** — a lens is an inventory item with extra fields: lens type (e.g. single vision, bifocal, progressive), material or brand, SPH, CYL. Stock is tracked per exact power combination. Selling a lens means choosing type and power; the app can pre-select the power from the patient's latest eye prescription.
- **Stock Movement** — item, quantity in or out, reason (purchase, sale, used in operation, adjustment), linked visit if sold.
- **Sale** — items sold to a patient, may or may not be linked to a visit. Total, discount, reason, payment method.
- **Supplier** — name, phone, address.
- **Purchase** — supplier, bill number, date, line items with quantity and unit cost, total. Creates stock movements and an expense.
- **Expense** — category (rent, salary, utilities, supplies, purchase, payout, other), amount, date, note, source (manual, purchase, payout), recorded by.
- **Doctor Payout** — any date range chosen by Admin, salary amount (prefilled with monthly salary, editable), share earned on gross or net basis, total, paid flag. Paid payouts create an expense.
- **Settings** — clinic name, logo, address, phone, receipt footer, follow-up reminder days, WhatsApp reminder toggles per type (appointment, follow-up, post-op), WhatsApp message templates.
- **Audit Log** — who, what, when, before and after values. Written for every edit, delete, discount, fee change, and stock adjustment.
- **User** — email, display name, roles (list), linked doctor ID if any, active flag.

---

## 5. Reception Features

### 5.1 Patient registration
- Search by phone number. Shows the family and every patient under that phone.
- Search by patient ID.
- Add a new patient under an existing family, or create a new family.
- Fields: name, age or date of birth, gender, address, notes.
- Patient ID is generated automatically and printed on the receipt so the patient can bring it next time.

### 5.2 Walk-in visit
1. Find or register the patient.
2. Select department, then doctor. Only active doctors of that department appear.
3. Select visit type. Fee fills in automatically from the fee schedule for that doctor and type.
4. Follow-up type uses the doctor's reduced follow-up fee.
5. Optional discount: enter amount or percentage. Reason is mandatory. Net amount shows.
6. Select payment method: cash, bank transfer, JazzCash, Easypaisa. Bank and wallet payments have an optional reference field.
7. Save. A token number is issued for that doctor for today. Visit appears in the doctor's queue.
8. Print A4 receipt.

### 5.3 Appointments
- Book a patient with a doctor on a date, with an optional free-text time.
- Today's appointments list, with an "Arrived" button that converts the appointment into a visit and issues a token.
- Reschedule or cancel. Mark no-show.
- Calendar view per doctor.

### 5.4 Queue management
- Live waiting list per doctor for today, with token labels like E-12 and status.
- Reception can see which doctor is free and how many are waiting.
- Token numbers reset daily per doctor.

### 5.5 Reports upload
- Open a patient, attach a PDF or photo with a title. Optionally link to a visit.
- Camera capture on devices that have one.

### 5.6 Inventory sales
- Sell items (medicines, frames, lenses, consumables) to a patient, with or without a visit. Frames and lenses are separate line items. For a lens line, reception picks lens type and power; the app suggests the power from the patient's latest eye prescription. Stock decreases for that exact power.
- Stock decreases on sale. Discount with reason allowed. Same payment methods.
- Receipt for sale, or combined on the visit receipt when linked.

### 5.7 Receipt (A4)
- Clinic name, logo, address, phone from Settings.
- Patient name, patient ID, phone, date and time, token number.
- Doctor, department, visit type.
- Fee, discount, net paid, payment method.
- Items sold if any.
- Footer text from Settings.
- Copies: defaults to 1. Reception can increase or decrease the number of copies before printing. Admin can change the default in Settings.
- Reprint from visit history.

### 5.8 Shift summary
- Reception sees today's totals: visits, cash collected, other payment totals, discounts given.

### 5.9 Offline behaviour
- Reception web keeps working without internet: patient search of already-synced data, new patients, visits, tokens, payments, and receipts.
- Data syncs when the connection returns.
- A visible indicator shows online, offline, or pending sync count.
- Token numbers are issued locally while offline. v1 assumes one reception device, so no cross-device token conflict handling is built. If a second reception device is added later, conflict handling must be designed first.

---

## 6. Doctor Features

### 6.1 Today's queue
- Live list of waiting patients for this doctor only, in token order.
- Tap to open. Status moves to in progress, then completed when the doctor finishes.

### 6.2 Patient history
- All past visits across every department and doctor, newest first.
- Each visit shows the prescription, notes, and linked reports.
- All uploaded reports in one tab.
- Operations and their status.

### 6.3 Prescription and notes
- Prescriptions are typed. There is no photo mode.
- Eye form: right and left eye SPH, CYL, AXIS, ADD, VA. Diagnosis and advice as free text.
- Homeo form: rows of medicine, potency, dosage, duration. Diagnosis and advice as free text.
- Print prescription on A4 with clinic header.
- Set a follow-up date. This creates an appointment suggestion visible to reception and, if Admin has enabled it, a pending WhatsApp reminder.

### 6.4 Operations
- From a checkup, schedule an operation: date, surgeon, notes.
- Pre-op checklist: Admin and doctors maintain the default list per operation type. The list is copied onto each operation; the doctor ticks items and can add patient-specific items. Operation cannot be marked done until the checklist is complete, unless the doctor overrides with a reason.
- Post-op follow-ups: each operation type has default days after surgery, e.g. day 1, day 7, day 30, set by Admin or doctors. When an operation is scheduled the days are copied to the patient, and reception, doctor, or Admin can change them for that patient at any time. Follow-ups appear in reception's appointment list and, if enabled, as pending WhatsApp reminders.

### 6.5 Personal summary
- Doctor sees own patients seen today, this week, this month.
- Doctor sees the fee, discount, discount reason, and net paid on every visit they open.
- Clinic-wide money figures (other doctors, expenses, profit) stay Admin only.

---

## 7. Admin Features

### 7.1 Dashboard
- Today, this week, this month, custom range.
- Revenue total, by department, by doctor, by payment method.
- Visits count, new vs returning patients.
- Discounts total and count.
- Expenses total and net profit.
- Low-stock alerts.

### 7.2 Users and roles
- Create user with email and temporary password. Assign one or more roles. Link to a doctor record where applicable.
- Deactivate users. Reset passwords.

### 7.3 Doctors and departments
- Add, edit, deactivate departments.
- Add, edit, deactivate doctors. Set salary, revenue share percentage, and share basis: gross fee or net fee after discount.
- Fee schedule grid: doctors as rows, visit types as columns, amount per cell. Follow-up fee column included.
- Operation types: default pre-op checklist and default post-op follow-up days per type. Doctors can also edit these from their side.

### 7.4 Visits and corrections
- Search any visit. Edit fee, discount, payment method, doctor, or delete. Every change is written to the audit log with the reason.

### 7.5 Inventory
- Add items with category, prices, unit, low-stock threshold.
- Lenses: add stock per type and power (SPH/CYL). A grid view shows stock on hand across the power range for each lens type, with low-stock cells highlighted.
- Suppliers list. Purchases: pick supplier, enter bill number and line items; stock increases and an expense is created automatically.
- Manual stock adjustments with reason.
- Stock movement history per item.
- Low-stock list.

### 7.6 Expenses and doctor payouts
- Record expenses by category with date and note.
- Doctor payout for any date range Admin picks: salary amount (prefilled, editable) plus percentage of that doctor's fees in the range, on gross or net basis as configured. Mark as paid. Paid payouts become expenses automatically.

### 7.7 Analytics and reports
- Revenue by day, week, month, doctor, department, payment method.
- Patient counts: new vs returning, per doctor, per department.
- Discounts: by receptionist, by doctor, by reason.
- Expenses by category. Net profit over time.
- Inventory sales and margins.
- Export any report to Excel (CSV) and PDF.

### 7.8 Settings
- Clinic name, logo, address, phone, receipt footer, default receipt copy count.
- Follow-up reminder days.
- WhatsApp reminders: on or off per reminder type (appointment, follow-up, post-op), and the message template for each.

### 7.9 Audit log
- Filter by user, date, action type. Shows before and after values.

---

## 8. Cross-cutting Features

- **Authentication** — Firebase Auth, email and password. Admin creates accounts. Forced password change on first login.
- **Role switcher** — users with several roles pick the active role; the UI changes accordingly.
- **Audit log** — automatic for edits, deletes, discounts, fee changes, stock adjustments, and user changes.
- **WhatsApp reminders** — no Business API. The reception PC already has WhatsApp Web open. The app shows a "Reminders due today" list (appointments tomorrow, follow-ups due, post-op follow-ups due). Each row has a Send button that opens WhatsApp Web with the patient's number and a pre-filled message from the template; staff press send and the app marks it sent. Admin turns each reminder type on or off in Settings. Any patient record also has a Send WhatsApp button for ad-hoc messages.
- **Printing** — A4 receipts and prescriptions as PDF, printed from the browser or shared from mobile.
- **Branch-ready** — every record carries `branchId`. Adding a second branch later means adding a branch picker and filters, not a data migration.
- **Department-ready** — departments are data, not code. Prescription forms are per department; new departments start with the free-text form until a structured form is added.
- **Offline-first at reception** — Firestore persistence with local writes queued.

---

## 9. Platform and Technology

- Flutter for web, Android, iOS. One codebase.
- Firebase: Firestore (data, offline persistence), Auth, Storage (reports, logo), Cloud Functions (user management, patient numbers, incremental daily totals, audit log), Hosting (web).
- PDF generation in-app for receipts and prescriptions.
- Clean architecture: domain, data, presentation layers per feature.
- Technical choices (Provider, go_router, feature-first folders, testing, build phases): see [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md).

---

## 10. Out of Scope for v1

- Multiple branches (prepared for, not built).
- Partial payments and dues tracking.
- Urdu or any second language.
- SMS reminders.
- Patient-facing app or online booking by patients.
- Lab integration or in-house test machines.
- Accounting export to external software.
- Photo prescriptions (paper prescription captured by camera).
- Managed database backups.

---

## 11. Open Questions

All requirement questions were resolved on 30 Oct 2026 and folded into the sections above.

Deferred by decision:

1. Eye prescription form: detailed field layout will be designed in the UI design phase. Fields confirmed so far: SPH, CYL, AXIS, ADD, VA per eye, plus diagnosis and advice.

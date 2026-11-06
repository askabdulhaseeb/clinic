# Clinic Management App — Feature Specification

**Status:** Draft v15 — 6 Nov 2026. v15: Phase 8B decisions (payouts in two reversible steps, CSV per report section, doctor change allowed after a prescription, Admin visits by day). v14: Phase 8A decisions (two checkpoints, dashboard ranges without a cap, expenses by day, manual expenses editable and others delete-only, same-department doctor change on visit corrections). v13: Phase 6B decisions (reminder sections and sent rows, overdue group, doctor's upcoming page under More). v12: Phase 6A decisions (two checkpoints, Arrived opens the new-visit form, day view per doctor, linked rows, booking from the patient, reception post-op days on the row). v11: Phase 5B decisions (surgery day booked as an appointment, surgeon picker, automatic visit–operation link, soft report deletes by reception, upload from the patient page, strict checklist with override). v10: Phase 5 decisions (two checkpoints 5A/5B, follow-ups become appointments at once, Save and Complete separate, same-day prescription edits, quick follow-up chips, doctor summary with own fees). v9: Phase 4 decisions (reception may move visits through the queue, preset discount reasons, clinic-wide shift summary with a personal toggle, sync badge built with the visit flow). v8: Phase 3 decisions (age stored as an approximate date of birth, family phone clash blocked when online, placeholder tabs on the patient page). v7: Phase 2 decisions (doctor–login link kept by Cloud Functions, first-run setup banner, editable department code, WhatsApp template placeholders). v6: budget decisions — prescriptions are typed only (no photos), no managed backup, dashboard totals kept by increments, Storage bucket in a US region for the no-cost quota. Storage design is in [FIREBASE_ARCHITECTURE.md](FIREBASE_ARCHITECTURE.md).
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
| Inventory | Homeo medicines, frames, lenses stocked by power (SPH/CYL), consumables. No batch or expiry tracking. Suppliers and purchase bills tracked; a purchase creates an expense. Decided 6 Nov 2026: lens grid SPH −20.00 to +20.00, CYL 0.00 to −8.00, step 0.25; a sale with short stock warns but is allowed; purchase bills cannot be edited after saving. |
| Doctor pay | Salary plus percentage of fees. Admin chooses per doctor whether the percentage applies to gross fee or net fee after discount. Payouts are for any date range Admin picks. |
| Analytics | Revenue, patient counts, discounts, expenses and net profit. Read from daily summaries, updated within seconds of each transaction. Timezone Asia/Karachi. Decided 6 Nov 2026: dashboard ranges are Today, This week (from Monday), This month and Custom with no cap on the span; Revenue = visit net fees + sales total, Discounts = visit discounts + sale discounts, Net profit = revenue − expenses; charts drawn with `fl_chart`. |
| Patient reminders | WhatsApp via WhatsApp Web already open on the reception PC. App opens a pre-filled message, staff press send. No Business API. Admin can turn each reminder type on or off. |
| Edit/delete visits | Admin only. Delete is a soft delete with a reason; the record stays visible to Admin. Decided 6 Nov 2026 (for Phase 8B): the doctor may be changed only to one in the same department; Admin finds visits by day with a text filter. |
| Old data | None. New clinic, start fresh. |
| Reception devices | One reception device for now. Offline token conflicts between devices are not handled in v1. |
| Doctor sees money | Yes. Doctor sees fee, discount, and net paid on each visit. |
| Doctor ↔ login link | Decided 3 Nov 2026. A doctor record is created first under Catalog → Doctors; the login is linked from the user form's doctor picker. One login per doctor. Cloud Functions keep `users.doctorId` and `doctors.userId` in step and refuse a doctor that is missing or already linked. |
| First-run setup | Decided 3 Nov 2026. While clinic settings do not exist, Admin pages show a banner leading to an Initial setup page that creates the settings, the branch, the Eye and Homeopathy departments and their visit types. No forced redirect. |
| Department code | Decided 3 Nov 2026. Editable after creation; the form warns that tokens issued from then on use the new prefix. Existing doctors of the department get the new code at once. |
| Patient age | Decided 4 Nov 2026. Reception enters either a date of birth or an age in years. An age is stored as an approximate date of birth (1 January of the birth year) and shown as `~40 y`; a real date of birth gives the exact age. Editing shows the age back as a number. |
| Family phone clash | Decided 4 Nov 2026. When online, changing a family phone to a number another family already uses is blocked with that family's head name; the right fix is to move the patients. Offline the change goes through and a Cloud Function flags both families as duplicates for Admin. |
| Patient page in Phase 3 | Decided 4 Nov 2026. The patient page shows the family card, edit and WhatsApp now; the Visits, Reports and Appointments tabs are placeholders until Phases 4–6. The New visit and Book buttons in search results are disabled until then. |
| Queue status at reception | Decided 4 Nov 2026. Reception may move a visit to in progress and to completed from the queue board (for doctors who do not use the app); doctors do the same from their own queue in Phase 5. Status is the only part of a saved visit reception can change. |
| Discount reasons | Decided 4 Nov 2026. A fixed preset list (Old patient, Staff or family, Poor patient, Doctor's instruction) plus Other with a free-text reason. The chosen text is stored on the visit so Admin's discount report groups by it. |
| Shift summary scope | Decided 4 Nov 2026. Today's totals for the whole clinic, with a "My visits only" switch that keeps the visits the signed-in user created. Computed from the visits already loaded for the queue, no extra reads. |
| Fee on a visit | Decided 4 Nov 2026. The fee comes from the doctor's fee schedule and is read-only at reception. When no fee is set for that doctor and visit type the form says so and will not save; Admin fixes the fee grid. |
| Visits list scope | Decided 4 Nov 2026. The reception Visits page lists today's visits only (one listener shared with the queue, the summary and the sync badge). Older visits are reached from the patient page, which also reprints receipts. |
| Phase 5 checkpoints | Decided 5 Nov 2026. The Doctor phase is reviewed in two parts. 5A: own queue, consultation, Eye and Homeo prescriptions with PDF, patient history, personal summary. 5B: reports upload and view, operations with checklist and post-op follow-ups, doctor edits of operation-type defaults. |
| Follow-ups become appointments | Decided 5 Nov 2026. Setting a follow-up date on a prescription (and, in 5B, post-op days on an operation) writes real `appointments` documents in the same batch (`source: followUp`, time empty). Phase 6 adds the screens; nothing is backfilled. Changing the date updates the same appointment; clearing it cancels it. |
| Saving a prescription | Decided 5 Nov 2026. Save writes the prescription and keeps the visit in progress. Complete saves it again and marks the visit completed in one batch. Complete without a prescription asks for confirmation first. |
| Prescription edits | Decided 5 Nov 2026. The assigned doctor may edit a prescription until the end of its Karachi day, even after the visit is completed. After that it is read-only and can only be reprinted. Rules enforce the day. |
| Follow-up date entry | Decided 5 Nov 2026. Quick chips (3 days, 1 week, 2 weeks, 1 month) plus a calendar picker for any date; stored as `YYYY-MM-DD`, no time. |
| Surgery-day appointment | Decided 5 Nov 2026. Scheduling an operation books one appointment on the surgery date (`source: operation`, the operation type in its notes) plus the post-op follow-ups. Moving the date moves it; cancelling the operation cancels all of them. |
| Surgeon | Decided 5 Nov 2026. Any active doctor of the department can be the surgeon; the scheduling doctor is preselected. The operation appears in the surgeon's list. |
| Visit ↔ operation link | Decided 5 Nov 2026. When reception issues a token with an operation visit type and the patient has a scheduled operation of that type, the new-visit form links it (`visits.operationId`) and shows "Operation scheduled for <date>". The doctor's Operation tab opens that record. |
| Report delete | Decided 5 Nov 2026. Reception and Admin may hide a wrongly uploaded report (soft delete with a reason; the file stays). |
| Phase 6 checkpoints | Decided 5 Nov 2026. Appointments are reviewed in two parts. 6A: booking from a patient, the appointments day view per doctor with Arrived / Reschedule / Cancel / No-show, Arrived opening the new-visit form, the patient page Appointments tab. 6B: reminders due today with WhatsApp send and mark sent, the doctor's upcoming appointments page, reception's post-op days entry point. |
| Arrived | Decided 5 Nov 2026. Arrived opens the new-visit form with the patient and the appointment's doctor preselected; saving the visit marks the appointment arrived with the visit's ID in the same batch, and the visit carries the appointment ID. Reception still chooses the type, fee, discount and payment. Arrived is offered on any booked appointment (early arrivals happen); No-show only on or after the day. |
| Appointments screen | Decided 5 Nov 2026. A day view: a date picker with previous / next, one column per doctor with appointments that day (the queue-board layout). Rows show time, patient, source and status. The Book button sends reception to patient search. |
| Linked appointment rows | Decided 5 Nov 2026. Manual, follow-up and post-op appointments can be rescheduled, cancelled and marked no-show from the appointments screen (moving a post-op appointment does not change the operation's day list). The surgery-day appointment offers Arrived and No-show only; it is moved or cancelled from the operation. |
| Booking entry points | Decided 5 Nov 2026. Booking starts from the patient: the Book button on a patient search row and on the patient page Appointments tab. The appointments screen's Book button opens patient search. The date defaults to tomorrow and may not be in the past. |
| Reminder sections | Decided 6 Nov 2026. "Appointments tomorrow" lists booked manual and surgery-day appointments dated tomorrow; "Follow-ups due" and "Post-op follow-ups due" list booked follow-up and post-op appointments dated today to today + follow-up reminder days; an "Overdue" group lists booked follow-ups and post-ops dated in the last 7 days so reception can chase them. A sent row stays in the list with its sent time (and "by you" for the signed-in user) and a Send again link. Sections whose reminder type Admin switched off are hidden; rows without a phone have Send disabled. |
| Doctor's upcoming appointments | Decided 6 Nov 2026. `/doctor/appointments` lists the doctor's booked appointments for the next 30 days grouped by day, read once when opened with a Refresh button (no listener). On phones it sits under More in the bottom bar; on desktop in the sidebar. Read-only. |
| Reception post-op days | Decided 5 Nov 2026. A post-op appointment row (day view and patient tab) offers "Change post-op days", opening the same day-chips editor the doctor uses; the appointments are regenerated after a confirm (6B). |
| Report upload | Decided 5 Nov 2026. From the patient page's Reports tab: title, file or camera, optional link to one of the patient's visits. Reports show on the doctor's consultation Reports tab and history page. |
| Doctor summary | Decided 5 Nov 2026. The Me tab shows, for today, this week (from Monday) and this month: patients seen (completed visits) and the doctor's own gross fee, discounts and net. Figures come from Firestore aggregate queries (one read per period). Clinic-wide money, other doctors and the doctor's share stay Admin only. |
| Payout lifecycle | Decided 6 Nov 2026 (Phase 8B). A payout is created unpaid (doctor, period defaulting to last month, salary prefilled and editable, share computed from the day summaries). "Mark paid" records the payout expense on that day; "Mark unpaid" needs a reason and deletes that expense with the same reason; an unpaid payout may be deleted with a reason, a paid one may not. Overlapping payouts for the same doctor are flagged, not blocked. |
| Report export | Decided 6 Nov 2026 (Phase 8B). Each report section exports as its own CSV; PDF export is deferred to a later phase. Inventory margins are not in 8B (the summaries hold sales by category only). |
| Visit corrections | Decided 6 Nov 2026 (Phase 8B). Admin may change a visit's fee, discount and reason, payment method and reference, and the doctor (same department only, also when a prescription exists: the prescription keeps the original doctor's name), each save with a reason stored on the visit; soft delete with a reason. Admin finds visits by day with a text filter; deleted visits stay listed, struck through. |

---

## 3. Roles and Permissions

| Action | Reception | Doctor | Admin |
|---|:-:|:-:|:-:|
| Register and edit patients | ✓ | | ✓ |
| Create visit, issue token, take payment | ✓ | | ✓ |
| Give discount (reason required) | ✓ | | ✓ |
| Book, reschedule, cancel appointments | ✓ | | ✓ |
| Upload patient reports | ✓ | | ✓ |
| Hide a wrong report (soft delete, reason) | ✓ | | ✓ |
| Print receipt | ✓ | | ✓ |
| Sell inventory items | ✓ | | ✓ |
| Void a sale (reason required, stock restored) | | | ✓ |
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
- One search field. A phone number shows the family and every patient under it (family phone or a patient's personal phone); a patient ID (`26-00341`) or temporary ID (`T-7K3M9`) finds one patient; any other text is a name prefix search on every word of the name (at least two letters). Results are grouped by family; a family with no patients still appears.
- **New patient** first asks for the family phone: if the family exists it offers "Add to this family", otherwise "New family" opens the registration form with the phone filled in. A family can also be added to from its header in the results or from the patient page.
- Fields: family (phone, head of family, address) and patient (name, gender, age in years or date of birth, personal phone, address, notes). See the age decision in §2.
- Patient ID is generated automatically when the record syncs and printed on the receipt so the patient can bring it next time. Until then the patient carries a temporary ID shown with a "pending" marker.
- Patient page: header (name, age, gender, ID, phones), address and notes, family card (head, phone, other members, Add member, Edit family, Change phone, Move to another family), Edit, Send WhatsApp (ad-hoc template from Settings), and tabs for visits, reports and appointments.
- Moving a patient re-homes them under another family's phone; changing a family phone updates every member. Two families registered with the same phone (possible offline) are marked "Duplicate phone" for Admin.
- Admin has the same patient screens under Admin → Patients.

### 5.2 Walk-in visit
1. Find or register the patient.
2. Select department, then doctor. Only active doctors of that department appear.
3. Select visit type. Fee fills in automatically from the fee schedule for that doctor and type.
4. Follow-up type uses the doctor's reduced follow-up fee.
5. Optional discount: enter amount or percentage. Reason is mandatory: a preset (Old patient, Staff or family, Poor patient, Doctor's instruction) or Other with free text. Net amount shows. The fee itself is read-only (see §2).
6. Select payment method: cash, bank transfer, JazzCash, Easypaisa. Bank and wallet payments have an optional reference field.
7. Save. A token number is issued for that doctor for today. Visit appears in the doctor's queue.
8. Print A4 receipt.

### 5.3 Appointments
- Book a patient with a doctor on a date, with an optional free-text time and notes. Booking starts from the patient (search row or the patient page Appointments tab); the date defaults to tomorrow and may not be in the past (decided 5 Nov 2026).
- Appointments day view: pick a date (today by default, previous / next), one column per doctor with appointments that day. Rows show time, patient, source (manual, follow-up, post-op, operation) and status.
- "Arrived" opens the new-visit form with the patient and doctor preselected; saving the visit issues the token and marks the appointment arrived in the same write (decided 5 Nov 2026).
- Reschedule (date and time) or cancel a manual, follow-up or post-op appointment; mark no-show on or after the day. The surgery-day appointment is moved or cancelled from the operation.
- Patient page Appointments tab: the patient's appointments, upcoming first, with a Book button.
- Reminders due today (`/reception/reminders`, decided 6 Nov 2026): Appointments tomorrow (manual and surgery-day), Follow-ups due and Post-op follow-ups due (today to today + follow-up reminder days), Overdue (last 7 days). Send opens WhatsApp Web with the type's template filled in and marks the row sent; sent rows stay with the time and Send again. Hidden sections for types switched off in Settings.
- Change post-op days: a post-op row on the day view or the patient tab opens the patient's operation days (chips, add, remove); saving re-books the post-op appointments after a confirm. The surgery-day appointment is untouched. Days stay editable after the operation is done (follow-ups continue after surgery); a cancelled operation is read-only.

### 5.4 Queue management
- Live waiting list per doctor for today, with token labels like E-12 and status.
- Reception can see which doctor is free and how many are waiting.
- Reception can mark a visit in progress or completed from the board (decided 4 Nov 2026, see §2); doctors do the same from their queue.
- Token numbers reset daily per doctor.

### 5.5 Reports upload
- Open a patient, attach a PDF or photo with a title. Optionally link to a visit.
- Camera capture on devices that have one.
- PDF, JPEG or PNG up to 10 MB. Photos are resized on the device before upload (longest side 1200 px, JPEG quality 80). The report record is written only after the file upload succeeds, so uploads need a connection.
- Reception and Admin can hide a wrong upload with a reason (decided 5 Nov 2026); the file is kept.

### 5.6 Inventory sales
- Sell items (medicines, frames, lenses, consumables) to a patient, with or without a visit. Frames and lenses are separate line items. For a lens line, reception picks lens type and power; the app suggests the power from the patient's latest eye prescription. Stock decreases for that exact power.
- Stock decreases on sale. Discount with reason allowed. Same payment methods.
- If the stock this device knows about is short (fewer units than the line, or zero), the line shows a warning but the sale goes through (decided 6 Nov 2026, so an offline desk never loses a sale); stock may go negative and Admin corrects it with an adjustment.
- Receipt for sale, or combined on the visit receipt when linked. Decided 6 Nov 2026: the sale always prints its own receipt; when it is linked to a visit, the visit receipt also lists the items sold.
- A walk-in customer without a patient record can buy (decided 6 Nov 2026): reception types the customer name instead of picking a patient. No lens suggestion in that case.
- Admin sells from the same Sales page (`/admin/sales`, under More on phones) and from the visit and patient pages. Admin can void a wrongly entered sale with a reason; stock comes back (decided 6 Nov 2026). Reception cannot void.
- A lens line is lens type + power + quantity (decided 6 Nov 2026): two different powers are two lines, the same power for both eyes is one line with quantity 2. The picker offers Add right / Add left from the latest eye prescription.

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
- Whole clinic by default; a "My visits only" switch narrows it to visits the signed-in user created (decided 4 Nov 2026).

### 5.9 Offline behaviour
- Reception web keeps working without internet: patient search of patients this device has already seen (searched, registered or pulled by the background sync; decided 5 Nov 2026, nothing is downloaded up front), new patients, visits, tokens, payments, and receipts. A patient the device has never seen needs the internet once; after that they are found offline.
- Data syncs when the connection returns.
- A visible indicator in the top bar shows Online, Offline, or Syncing with the number of visits still waiting to reach the server (built in Phase 4 with the visit flow, decided 4 Nov 2026).
- Token numbers are issued locally while offline. v1 assumes one reception device, so no cross-device token conflict handling is built. If a second reception device is added later, conflict handling must be designed first.

---

## 6. Doctor Features

### 6.1 Today's queue
- Live list of waiting patients for this doctor only, in token order.
- Tap to open. Status moves to in progress, then completed when the doctor finishes.
- In-progress visits sit at the top, waiting ones below in token order, and today's completed visits collapse under "Done today". The doctor can also move status from the list (Start / Complete), the same as reception does from the board.

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
- Set a follow-up date with quick chips (3 days, 1 week, 2 weeks, 1 month) or a calendar picker. This creates an appointment (`source: followUp`, no time) visible to reception from Phase 6 and, if Admin has enabled it, a pending WhatsApp reminder. Changing the date moves the same appointment; clearing it cancels it.
- Save stores the prescription and leaves the visit in progress; Complete stores it and completes the visit in one write. Completing without a prescription needs a confirmation. The assigned doctor can edit the prescription until the end of that Karachi day; afterwards it is read-only (decided 5 Nov 2026).
- Departments without a structured form (any department other than Eye and Homeopathy) get diagnosis and advice only.

### 6.4 Operations
- From a checkup, schedule an operation: date, surgeon, notes.
- Pre-op checklist: Admin and doctors maintain the default list per operation type. The list is copied onto each operation; the doctor ticks items and can add patient-specific items. Operation cannot be marked done until the checklist is complete, unless the doctor overrides with a reason.
- Post-op follow-ups: each operation type has default days after surgery, e.g. day 1, day 7, day 30, set by Admin or doctors. When an operation is scheduled the days are copied to the patient, and reception, doctor, or Admin can change them for that patient at any time. Follow-ups appear in reception's appointment list and, if enabled, as pending WhatsApp reminders.
- Decided 5 Nov 2026: the surgeon is any active doctor of the department (the scheduling doctor preselected); the surgery day itself is booked as an appointment; a token issued with that operation type on or after the date links the visit to the operation. Doctors edit their department's operation-type defaults from the Me tab. Reception's own entry point for changing a patient's post-op days arrives with the appointments screens in Phase 6.

### 6.5 Personal summary
- Doctor sees own patients seen today, this week (from Monday), this month: completed visits, plus own gross fee, discounts and net for each period (decided 5 Nov 2026). Needs a connection; the figures are server aggregates.
- Doctor sees the fee, discount, discount reason, and net paid on every visit they open.
- Clinic-wide money figures (other doctors, expenses, profit) stay Admin only.

---

## 7. Admin Features

### 7.1 Dashboard
- Today, this week (from Monday), this month, custom range (any span; decided 6 Nov 2026).
- Revenue total (visit net fees + sales), by department, by doctor, by payment method.
- Visits count, new vs returning patients, visits per day.
- Discounts total (visits and sales).
- Expenses total and net profit (revenue − expenses).
- Low-stock alerts (items at or below their threshold).
- Recompute day: repairs one day's summary from its visits, sales and expenses when a total looks wrong.

### 7.2 Users and roles
- Create user with email and temporary password. Assign one or more roles. Link to a doctor record where applicable.
- Deactivate users. Reset passwords.

### 7.3 Doctors and departments
- Add, edit, deactivate departments. Code is 1 to 3 letters, unique, editable with a warning (see §2).
- Add, edit, deactivate doctors. Set department, specialisation, salary, revenue share percentage (decimals allowed, 0 to 100), and share basis: gross fee or net fee after discount. The doctor form also sets that doctor's fee per visit type of its department. Login linking is done from the user form (§7.2), which lists active doctors that have no login yet.
- Fee schedule grid: doctors as rows, visit types as columns, amount per cell. Follow-up fee column included. Saved one row at a time.
- Visit types per department with flags: follow-up (reduced fee) or operation. Operation types: default pre-op checklist and default post-op follow-up days per type. Doctors can also edit these from their side (Phase 5).
- Deactivation only, no deletes. Inactive records are hidden from pickers and lists unless "Show inactive" is on.

### 7.4 Visits and corrections
- Search any visit: pick a day, filter the day's list by name, number, phone or token (decided 6 Nov 2026). Edit fee, discount, payment method, doctor (same department only), or delete. Every change is written to the audit log with the reason.
- Built 6 Nov 2026 (Phase 8B): the day list reads once (deleted visits included, struck through); the visit page gains Edit and Delete for Admin; the edit form needs a reason for the change and shows only doctors of the visit's department; a deleted visit shows its reason and loses its receipt and sale actions. The reason is stored on the visit (`editReason`, `deleteReason`) until the Phase 9 audit log.

### 7.5 Inventory
- Add items with category, prices, unit, low-stock threshold, brand, and an opening stock on creation (recorded as an "Opening stock" adjustment). Items are deactivated, never deleted.
- Lenses: one item per type and power (SPH/CYL). A grid view per lens type (SPH −20.00 to +20.00 down the side, CYL 0.00 to −8.00 across, 0.25 steps; decided 6 Nov 2026) shows stock on hand with low-stock cells highlighted; tapping a power that has no item yet opens the item form with the power filled in.
- Suppliers list (name, phone, address, notes; deactivate). Purchases: pick supplier, enter bill number, date and line items (item, quantity, unit cost); stock increases and an expense is created automatically. A saved purchase cannot be edited (decided 6 Nov 2026).
- Manual stock adjustments with a signed quantity and a reason.
- Stock movement history per item (last 50 movements).
- Low-stock filter on each category list (stock at or below the item's threshold); the dashboard card arrives in Phase 8.

### 7.6 Expenses and doctor payouts
- Record expenses by category with date and note. The list shows one day at a time. Decided 6 Nov 2026: a manual expense may be edited and soft deleted with a reason; an expense created by a purchase or a payout may only be soft deleted (the bill or payout stays the record).
- Doctor payout for any date range Admin picks: salary amount (prefilled, editable) plus percentage of that doctor's fees in the range, on gross or net basis as configured. Mark as paid. Paid payouts become expenses automatically.
- Built 6 Nov 2026 (Phase 8B): the Payouts tab lists every payout (latest period first, Paid / Unpaid / Deleted chips); New payout picks the doctor and period (default: last month), shows gross, discounts, net, share and total from the day summaries, warns when the doctor already has a payout touching the period; the payout page has Mark paid, Mark unpaid (reason) and Delete (reason, unpaid only) and opens the linked expense.

### 7.7 Analytics and reports
- Revenue by day, week, month, doctor, department, payment method.
- Patient counts: new vs returning, per doctor, per department.
- Discounts: by receptionist, by doctor, by reason.
- Expenses by category. Net profit over time.
- Inventory sales and margins.
- Export any report to Excel (CSV) and PDF.
- Built 6 Nov 2026 (Phase 8B): the Reports page uses the dashboard's ranges and shows nine tables from the day summaries: revenue by day, by doctor, by department, fees by payment method, patients (new vs returning), discounts by user and by reason, expenses by category, sales by category; each has its own Export CSV button. PDF export and inventory margins are deferred (decided 6 Nov 2026).

### 7.8 Settings
- Clinic name, logo (PNG or JPG up to 2 MB), address, phone, receipt footer, default receipt copy count (1 to 5).
- Follow-up reminder days (0 to 30): how many days before a follow-up date it appears on the reminders list.
- WhatsApp reminders: on or off per reminder type (appointment, follow-up, post-op), and the message template for each, plus an ad-hoc template for the Send WhatsApp button on a patient. Templates may use the placeholders `{patient}`, `{doctor}`, `{date}`, `{time}` and `{clinic}`, replaced when the message is opened (Phase 6).
- First run: an Initial setup page (reached from a banner shown on Admin pages while settings are missing) asks for the clinic name, address and phone and creates the settings with default templates, the branch, the Eye and Homeopathy departments, and visit types Checkup and Follow-up for each plus Eye Test.

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

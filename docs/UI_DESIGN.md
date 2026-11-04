# UI Design

**Status:** Draft v2 — 3 Nov 2026 (Phase 2 screens: catalog tabs, forms, settings, first-run setup). Companion to [FEATURES.md](FEATURES.md) (what each screen does) and [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) (theme, packages, phases). This document fixes how screens are laid out and how users move between them. Screens are still reviewed one by one by the owner as they are built; this document is the starting point, not a pixel spec.

---

## 1. Decisions

| Topic | Decision |
|---|---|
| Web shell (Reception, Admin, Doctor on desktop) | Fixed left sidebar with section links. Top bar with clinic name and logo, screen title, role switcher, online/offline badge, user menu. |
| Mobile shell (Doctor, Admin on phones) | Bottom navigation bar, 4 to 5 tabs per role. Overflow goes into a "More" tab. |
| Breakpoints | Width < 600: mobile shell. 600–1023: sidebar collapsed to icons (navigation rail). ≥ 1024: full sidebar with labels. One codebase, one widget tree, layout switches on width. |
| Theme | Material 3, teal seed (`AppColors.seed`). Eye accent blue, Homeo accent green, other departments purple. Light and dark follow the system. Roboto. |
| Density | `VisualDensity.adaptivePlatformDensity`: compact on desktop and desktop browsers, standard on phones. |
| Eye prescription form | Table: rows OD (right) and OS (left), columns SPH, CYL, AXIS, ADD, VA. Diagnosis and advice below. Typed only, no photo mode. |
| Homeo prescription form | Repeating rows: medicine, potency, dosage, duration, with add and remove row. Diagnosis and advice below. |
| Lists | `DataTable`-style tables on desktop, `ListTile` cards on phones. Same data, same view model. |
| Forms | One column on phones, two columns on desktop where fields are short. Save button fixed at the bottom. Validation on submit, inline errors. |
| Money | Always `Rs 1,500` via `MoneyText`. Never decimals. Discounts shown in red-tinted text, net in bold. |
| Token | Chip with the department colour, e.g. `E-12` on blue, `H-5` on green. |
| Status | Visit: waiting (grey), in progress (amber), completed (green). Appointment: booked, arrived, cancelled, no-show. Operation: scheduled, done, cancelled. Always a coloured chip plus text, never colour alone. |
| Offline | Badge in the top bar: green "Online", grey "Offline", amber "Syncing 3" when writes are pending. Receipts print offline. |
| Destructive actions | Always a confirm dialog. Delete and edit of saved visits require a reason field before the button enables. |
| Printing | A4 PDF generated in-app, opened with the `printing` print dialog on web, share sheet on mobile. Copy count stepper on the receipt preview. |
| Icons | Material Symbols. No custom icon set. |
| Empty states | `EmptyState` widget: icon, one-line title, one-line hint, optional primary action. |

---

## 2. Shells

### 2.1 Web shell (width ≥ 1024)

```
+------------+-------------------------------------------------------+
| [logo]     |  Screen title                 [Reception ▾] [● Online] [AH ▾] |
| Clinic     |                                                       |
|------------|                                                       |
| ● Patients |                                                       |
|   Visits   |                                                       |
|   Queue    |                 Screen content                        |
|   Appts    |                                                       |
|   Reminders|                                                       |
|   Sales    |                                                       |
|   Summary  |                                                       |
|            |                                                       |
|------------|                                                       |
| v1.0.0     |                                                       |
+------------+-------------------------------------------------------+
```

- Sidebar width 240 px, section links with icon and label, selected item filled with primary container colour.
- Top bar: clinic name and logo come from Settings (`SettingsController`; "Clinic" and a hospital icon until setup runs). Role switcher appears only for users with more than one role. User menu: change password, sign out.
- Widths 600–1023 show the same sidebar as a 72 px rail with icons only; labels on hover tooltip.

### 2.2 Mobile shell (width < 600)

```
+----------------------------------+
| Queue              [● Online] ⋮  |
|----------------------------------|
|                                  |
|          Screen content          |
|                                  |
|----------------------------------|
| Queue | Patients | Ops |  Me     |
+----------------------------------+
```

- App bar title is the current tab. Overflow menu: switch role, change password, sign out.
- Bottom bar tabs are per role (see §3). Detail screens push on top of the tab with a back button; the bottom bar stays visible.

### 2.3 Role switcher

Users with several roles land on the role they used last on this device (`shared_preferences`). Switching role replaces the whole shell and navigates to that role's home. The URL prefix changes (`/reception`, `/doctor`, `/admin`).

---

## 3. Navigation Map

Route paths live in `lib/core/routing/app_routes.dart`. Only `login`, `changePassword` and the three role roots exist today; the rest are added per phase.

### 3.1 Public

| Path | Screen | Phase |
|---|---|---|
| `/login` | Login | 1 |
| `/change-password` | Change password. First login is forced here as `/change-password?forced=1`; once `mustChangePassword` clears the router moves on to the role home. Without the marker (opened from the user menu) the screen stays until the user leaves. | 1 |

After login: redirect to the last used role's home, or the single role's home. Signed-out users hitting any other path go to `/login` and return after login.

Return-after-login mechanics (decided 2 Nov 2026): the wanted page travels as a `from` query parameter while the session is unknown or signed out, e.g. `/?from=%2Fadmin%2Fusers` then `/login?from=%2Fadmin%2Fusers`. Only paths under a role root are remembered, never `/`, `/login` or `/change-password`, and never absolute URLs. After sign-in the user lands on `from` if they hold that role, otherwise on the active role's home. A forced password change still comes first and drops `from`.

### 3.2 Reception (`/reception`)

Sidebar order: Patients, Visits, Queue, Appointments, Reminders, Sales, Summary.

| Path | Screen | Phase |
|---|---|---|
| `/reception` | redirects to `/reception/visits` | 4 |
| `/reception/patients` | Patient search (phone, patient ID, name) | 3 |
| `/reception/patients/new` | New family + patient | 3 |
| `/reception/patients/:id` | Patient detail: family members, visits, reports, appointments, WhatsApp button | 3 |
| `/reception/visits` | Today's visits list, New visit button | 4 |
| `/reception/visits/new?patientId=` | New visit wizard (patient → doctor → type → fee → discount → payment → token) | 4 |
| `/reception/visits/:id` | Visit detail, receipt preview, reprint | 4 |
| `/reception/queue` | Queue board: one column per doctor on duty | 4 |
| `/reception/appointments` | Today's appointments, calendar per doctor, Arrived / Reschedule / Cancel / No-show | 6 |
| `/reception/appointments/new?patientId=` | Book appointment | 6 |
| `/reception/reminders` | Reminders due today with Send buttons | 6 |
| `/reception/sales` | Today's sales, New sale | 7 |
| `/reception/sales/new?patientId=&visitId=` | New sale with lens power picker | 7 |
| `/reception/summary` | Shift summary | 4 |

### 3.3 Doctor (`/doctor`)

Bottom tabs: Queue, Patients, Operations, Me. Sidebar on desktop uses the same four plus Appointments.

| Path | Screen | Phase |
|---|---|---|
| `/doctor` | redirects to `/doctor/queue` | 5 |
| `/doctor/queue` | My queue today, in token order | 5 |
| `/doctor/visits/:id` | Consultation: patient header, history tab, prescription tab, reports tab, operation tab. Complete button | 5 |
| `/doctor/patients` | Patient search (read-only) | 5 |
| `/doctor/patients/:id` | Patient history across departments | 5 |
| `/doctor/operations` | My operations: scheduled, done | 5 |
| `/doctor/operations/:id` | Operation detail: checklist, post-op days, follow-up appointments | 5 |
| `/doctor/appointments` | My upcoming appointments (desktop sidebar, inside Me on phones) | 6 |
| `/doctor/me` | Personal summary: today, week, month; defaults for my operation types | 5 |

### 3.4 Admin (`/admin`)

Bottom tabs: Dashboard, Visits, Inventory, Finance, More. Sidebar on desktop: Dashboard, Visits, Patients, Appointments, Inventory, Finance, Reports, Users, Catalog, Settings, Audit log.

| Path | Screen | Phase |
|---|---|---|
| `/admin` | redirects to `/admin/dashboard` | 8 |
| `/admin/dashboard` | KPI tiles, range picker, breakdown cards, low-stock alerts | 8 |
| `/admin/visits` | Search any visit; edit or soft delete with reason | 8 |
| `/admin/patients` and `/admin/patients/:id` | Same screens as Reception, re-used | 3 |
| `/admin/appointments` | Same as Reception | 6 |
| `/admin/inventory` | Items by category tabs; lens grid tab | 7 |
| `/admin/inventory/items/:id` | Item detail, stock movements, adjust stock | 7 |
| `/admin/inventory/suppliers` | Suppliers | 7 |
| `/admin/inventory/purchases` and `/new` | Purchase bills | 7 |
| `/admin/finance/expenses` | Expenses | 8 |
| `/admin/finance/payouts` and `/new` | Doctor payouts by date range | 8 |
| `/admin/reports` | Date-range reports with CSV and PDF export | 8 |
| `/admin/users` | Users, create, roles, deactivate, reset password | 1 |
| `/admin/catalog` | redirects to `/admin/catalog/departments` | 2 |
| `/admin/catalog/departments` | Departments tab: table (name, code chip, status), New department dialog, edit dialog with code-change warning | 2 |
| `/admin/catalog/doctors`, `/new`, `/:id` | Doctors tab: table (name, department, specialisation, salary, share, login link, status), search, department filter; full-page form (doctor, pay, fees cards) with `PageHeader` back | 2 |
| `/admin/catalog/fees` | Fee grid: doctors × visit types, department segments, Save row | 2 |
| `/admin/catalog/visit-types`, `/new?departmentId=`, `/:id` | Visit types tab: table (kind, operation defaults); full-page form with follow-up / operation switches, checklist list and post-op day chips | 2 |
| `/admin/settings` | Clinic settings: Clinic, Receipts and WhatsApp reminders cards, logo upload, Save FAB | 2 |
| `/admin/setup` | Initial setup card (clinic name, address, phone, what will be created). Reachable only while `settings/general` is missing; otherwise redirects to the dashboard. Admin pages show a `MaterialBanner` with a "Run setup" button while settings are missing (decided 3 Nov 2026: banner, no forced redirect) | 2 |
| `/admin/audit` | Audit log with filters | 9 |

---

## 4. Key Screens

### 4.1 Login
Centered card, clinic logo if cached, email, password, Sign in. Error text under the form. No self sign-up link. Debug builds only: a small **Create test admin** text button under Sign in (DEVELOPMENT_PLAN §1, Test admin) that creates or restores the fixed test admin and signs in with it.

### 4.2 Patient search (Reception)
Single search field at the top that accepts a phone number, a patient ID (`26-00341`) or a name. Results grouped by family: family phone and head name as a header, patients as rows (name, age, gender, patient ID, last visit). Row actions: New visit, Book appointment, Open. Button "New patient" top right, which first asks for the phone and shows the family if it exists.

### 4.3 New visit wizard (Reception)
One screen, vertical sections that enable in order. Desktop shows it as a two-column form with a live receipt summary on the right.

```
Patient      [Ahmed Khan  26-00341  0300-1234567]        (change)
Department   (Eye) (Homeopathy)
Doctor       [Dr. Sara ▾]                      Waiting now: 4
Visit type   (Checkup) (Follow-up) (Eye Test)
Fee          Rs 1,500
Discount     [ 200 ] Rs  or [ 10 ] %     Reason [Old patient      ▾]
Net          Rs 1,300
Payment      (Cash) (Bank) (JazzCash) (Easypaisa)   Ref [        ]
                                       [ Save and print ]  [ Save ]
```

After save: dialog with the token in large type (`E-12`), receipt preview, copy stepper, Print and Done.

### 4.4 Queue board (Reception)
One column per doctor on duty today. Column header: doctor name, department chip, counts waiting / in progress / done. Rows: token chip, patient name, time since created. Updates live.

### 4.5 Doctor queue (Doctor)
List of waiting visits in token order with a large token chip, patient name, age and gender, visit type. Tapping opens the consultation and moves the visit to in progress. Completed visits of today collapse under a "Done today" section.

### 4.6 Consultation (Doctor)
Patient header: name, age, gender, patient ID, phone, token, visit type, fee / discount / net. Tabs: Prescription, History, Reports, Operation. Bottom bar: Follow-up date, Print Rx, Complete.

**Eye prescription:**

```
            SPH       CYL       AXIS      ADD       VA
OD (R)   [ -1.25 ]  [ -0.50 ]  [  90  ]  [ +1.00 ]  [ 6/6 ]
OS (L)   [ -1.00 ]  [ -0.75 ]  [  85  ]  [ +1.00 ]  [ 6/9 ]

Diagnosis  [                                              ]
Advice     [                                              ]
```

Field rules: SPH and CYL in 0.25 steps with sign, AXIS 0–180 integer, ADD positive in 0.25 steps, VA free text (e.g. `6/6`, `6/9`, `CF`). On phones the table scrolls horizontally; the row labels stay fixed.

**Homeo prescription:**

```
Medicine            Potency   Dosage          Duration
[ Arnica        ▾]  [ 30C  ]  [ 3 drops TDS ] [ 7 days ]   (×)
[ Belladonna    ▾]  [ 200C ]  [ 2 pills BD  ] [ 5 days ]   (×)
[ + Add medicine ]

Diagnosis  [                                              ]
Advice     [                                              ]
```

Medicine field suggests from inventory items of category medicine, free text allowed.

### 4.7 Operation detail (Doctor)
Header: patient, operation type, surgeon, scheduled date picker, status chip. Checklist as checkboxes with who and when on tick; "Add item" at the bottom. Post-op days as chips (`Day 1`, `Day 7`, `Day 30`) with add and remove; changing them regenerates appointments after a confirm. "Mark done" disabled until all items are ticked, with an "Override with reason" link.

### 4.8 Admin dashboard
Range picker (Today, This week, This month, Custom). Row of KPI tiles: Revenue, Visits, New patients, Discounts, Expenses, Net profit. Below: revenue by department and by doctor (bar), by payment method (stacked bar), visits per day (line). Low-stock list card. Everything reads `dailySummaries`.

### 4.9 Fee grid (Admin)
Table with doctors as rows and the department's active visit types as columns (follow-up column labelled "(reduced)"), amount cells editable inline, Save row button enabled only when the row changed, undo icon discards. Department segments at the top since visit types are per department; switching discards unsaved edits.

### 4.9a Catalog (Admin)
`/admin/catalog/*` share a `TabBar` (Departments, Doctors, Visit types, Fees) whose tabs are routes. Lists follow the Users screen pattern: `DataTable` on desktop, `ListTile` on phones, a row menu with Edit and Deactivate / Reactivate (confirm dialog on deactivate), "Show inactive" filter chip. Departments edit in a dialog; doctors and visit types open a full page inside the shell with a `PageHeader` (back arrow, title) and a Save FAB.

### 4.9b Settings and first run (Admin)
Settings is one scrolling form in three cards (Clinic with logo row, Receipts, WhatsApp reminders with a switch above each template; a switched-off template is disabled). Save FAB bottom right; snackbar "Settings saved". Initial setup is a centered card listing what will be created, with a single "Run setup" button; on success it goes to the dashboard and the banner disappears.

### 4.10 Lens grid (Admin, Reception sale picker)
Tabs per lens type. Grid with SPH down the side and CYL across the top; each cell shows stock on hand, red tint at or below the low-stock threshold, grey when the item does not exist. Tapping a cell opens the item or, in the sale picker, adds that lens to the sale. The sale picker pre-highlights the cell matching the patient's latest eye prescription.

### 4.11 Reminders due today (Reception)
Three sections: Appointments tomorrow, Follow-ups due, Post-op follow-ups due. Each row: patient, phone, doctor, date, Send button. Send opens `wa.me/<phone>?text=<template>` in a new tab and marks the row sent with time and user. Sections for reminder types Admin has turned off are hidden.

---

## 5. Shared Components (`lib/core/widgets/`)

| Widget | Use |
|---|---|
| `MoneyText` | Formats int PKR as `Rs 1,500`. Variants for discount (red) and total (bold). |
| `TokenChip` | Token label with department colour. |
| `StatusChip` | Visit, appointment, operation statuses. |
| `EmptyState` | Icon, title, hint, optional action. |
| `ConfirmDialog` | Title, message, optional required reason field, destructive style. |
| `SyncBadge` | Online / Offline / Syncing N. |
| `KarachiDatePicker` | Date picker that returns `YYYY-MM-DD`. |
| `PatientHeader` | Name, age, gender, patient ID, phone. Used by visit, consultation, sale. |
| `DepartmentChip` | Department name in its colour. |
| `AdaptiveList` | Table on desktop, cards on phones, from one row model. |
| `AppShell` | Sidebar / rail / bottom bar by width, takes the role's destination list. Shows the first-run banner on Admin pages. |
| `PageHeader` | Back arrow, title and actions for detail / form pages inside the shell. |
| `ActiveChip` | "Active" / "Inactive" for master-data rows. |

---

## 6. Print Layouts (summary)

Both are A4 portrait PDFs generated with `pdf` and shown with `printing`.

**Receipt:** clinic header (logo, name, address, phone), receipt number (visit ID short), date and time, patient block (name, patient ID, phone), visit block (doctor, department, visit type, token in large type), amounts table (fee, discount with reason, net, payment method and reference), items sold table if any, footer text. Copies printed as repeated pages.

**Prescription:** same clinic header plus doctor name and specialisation, patient block, Eye table or Homeo rows, diagnosis, advice, follow-up date, doctor signature line.

---

## 7. Accessibility and Input

- Minimum touch target 48 px on phones; compact density only changes padding on desktop.
- Every colour-coded chip also carries text.
- Keyboard: on web, Enter submits the current form, Tab order follows the visual order, the search field is focused on open.
- Barcode or scanner input for patient ID is not in v1; the patient ID field accepts paste.
- Text scales with system font size; tables scroll rather than clip.

---

## 8. Open Points

1. Logo size and placement on receipt will be tuned once the owner supplies the real logo.
2. Whether the reception queue board should show all doctors or only doctors with visits today. Default: doctors with at least one visit today, plus a toggle to show all active doctors.

# UI Design

**Status:** Draft v12 — 6 Nov 2026 (Phase 10 screens: version footer in the sidebar, theme colour swatches on Settings, Export PDF on every report card, Sales margins report card; v11: Phase 9 screen: audit log by day with filters; the login screen loses the dev test-admin button; v10: Phase 8B screens: admin visits by day, visit correction form and delete dialog, payouts list, new payout, payout detail, reports with CSV export; v9: Phase 8A screens: admin dashboard, expenses by day, expense form; v8: Phase 6B screens: reminders due today, doctor upcoming appointments, post-op days sheet; v7: Phase 6A screens: appointments day view, book appointment, patient Appointments tab; v6: Phase 5B screens: report upload dialog and Reports tab, schedule-operation sheet, operations list and detail, Me-tab defaults editor, operation link on the new-visit form). v5 — 5 Nov 2026 (Phase 5A screens: doctor queue, consultation with prescription forms and follow-up, prescription PDF, doctor patient history, personal summary). v4 — 4 Nov 2026 (Phase 4 screens: new visit form, token dialog, visits list, queue board, shift summary, visit detail, sync badge). v3 — 4 Nov 2026 (Phase 3 screens: patient search, registration form, patient page, family dialogs). v2 — 3 Nov 2026 (Phase 2 screens: catalog tabs, forms, settings, first-run setup). Companion to [FEATURES.md](FEATURES.md) (what each screen does) and [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) (theme, packages, phases). This document fixes how screens are laid out and how users move between them. Screens are still reviewed one by one by the owner as they are built; this document is the starting point, not a pixel spec.

---

## 1. Decisions

| Topic | Decision |
|---|---|
| Web shell (Reception, Admin, Doctor on desktop) | Fixed left sidebar with section links. Top bar with clinic name and logo, screen title, role switcher, online/offline badge, user menu. |
| Mobile shell (Doctor, Admin on phones) | Bottom navigation bar, 4 to 5 tabs per role. Overflow goes into a "More" tab. |
| Breakpoints | Width < 600: mobile shell. 600–1023: sidebar collapsed to icons (navigation rail). ≥ 1024: full sidebar with labels. One codebase, one widget tree, layout switches on width. |
| Theme | Material 3, seed colour chosen by Admin in Settings from a fixed palette (`ThemeColor`, default teal `AppColors.seed`; Phase 10, decided 6 Nov 2026). Eye accent blue, Homeo accent green, other departments purple. Light and dark follow the system. Roboto. |
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

- Sidebar width 240 px, section links with icon and label, selected item filled with primary container colour. Footer `v1.0.0` (`app-version`, from `AppVersion.current`; Phase 10): small muted text at the bottom of the extended sidebar, a tooltip on the rail's info icon, and a disabled "Version 1.0.0" row in the phone user menu.
- Top bar: clinic name and logo come from Settings (`SettingsController`; "Clinic" and a hospital icon until setup runs). Role switcher appears only for users with more than one role. User menu: change password, sign out.
- Widths 600–1023 show the same sidebar as a 72 px rail with icons only; labels on hover tooltip. The rail scrolls when a role's destinations exceed the window height (Admin on a short tablet; fixed in Phase 10).

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
| `/reception/patients/new?phone=` or `?familyId=` | New family + patient, or new patient under a family | 3 |
| `/reception/patients/:id` | Patient detail: family members, visits, reports, appointments, WhatsApp button | 3 |
| `/reception/patients/:id/edit` | Edit patient | 3 |
| `/reception/visits` | Today's visits list, New visit button | 4 |
| `/reception/visits/new?patientId=` | New visit wizard (patient → doctor → type → fee → discount → payment → token) | 4 |
| `/reception/visits/:id` | Visit detail, receipt preview, reprint | 4 |
| `/reception/queue` | Queue board: one column per doctor on duty | 4 |
| `/reception/appointments` | Appointments day view: date picker, one column per doctor, Arrived / Reschedule / Cancel / No-show | 6A |
| `/reception/appointments/new?patientId=` | Book appointment | 6A |
| `/reception/reminders` | Reminders due today with Send buttons | 6B |
| `/reception/sales` | Today's sales, New sale | 7B |
| `/reception/sales/new?patientId=&visitId=` | New sale with lens power picker (walk-in when no patient) | 7B |
| `/reception/sales/:id` | Sale detail, receipt print | 7B |
| `/reception/summary` | Shift summary | 4 |

### 3.3 Doctor (`/doctor`)

Bottom tabs: Queue, Patients, Operations, Me, plus More holding Appointments (decided 6 Nov 2026). Sidebar on desktop shows all five.

| Path | Screen | Phase |
|---|---|---|
| `/doctor` | redirects to `/doctor/queue` | 5 |
| `/doctor/queue` | My queue today, in token order | 5A |
| `/doctor/visits/:id` | Consultation: patient header, prescription tab, history tab, reports tab (5B), operation tab (5B). Save, Print Rx, Complete | 5A |
| `/doctor/patients` | Patient search (read-only) | 5A |
| `/doctor/patients/:id` | Patient history across departments | 5A |
| `/doctor/operations` | My operations: scheduled, done | 5B |
| `/doctor/operations/:id` | Operation detail: checklist, post-op days, follow-up appointments | 5B |
| `/doctor/appointments` | My upcoming appointments, next 30 days (desktop sidebar, under More on phones) | 6B |
| `/doctor/me` | Personal summary: today, week, month (5A); defaults for my operation types (5B) | 5A / 5B |

### 3.4 Admin (`/admin`)

Bottom tabs: Dashboard, Visits, Inventory, Finance, More. Sidebar on desktop: Dashboard, Visits, Patients, Appointments, Sales, Inventory, Finance, Reports, Users, Catalog, Settings, Audit log.

| Path | Screen | Phase |
|---|---|---|
| `/admin` | redirects to `/admin/dashboard` | 8 |
| `/admin/dashboard` | KPI tiles, range picker, breakdown cards, low-stock alerts, Recompute day | 8A |
| `/admin/visits`, `/admin/visits/:id`, `/admin/visits/:id/edit` | Pick a day, filter the list; the visit page with Edit and Delete (reason); the correction form | 8B |
| `/admin/patients`, `/admin/patients/new`, `/admin/patients/:id`, `/admin/patients/:id/edit` | Same screens as Reception, re-used (Patients sits under More on phones) | 3 |
| `/admin/appointments`, `/admin/appointments/new?patientId=` | Same screens as Reception (Appointments sits under More on phones) | 6A |
| `/admin/sales`, `/admin/sales/new?patientId=&visitId=`, `/admin/sales/:id` | Same screens as Reception plus Void on the sale detail (Sales sits under More on phones; decided 6 Nov 2026) | 7B |
| `/admin/inventory` | redirects to `/admin/inventory/medicine` | 7A |
| `/admin/inventory/medicine`, `/frame`, `/consumable` | Items of one category: search, low-stock and show-inactive filters, New item | 7A |
| `/admin/inventory/lens` | Lens grid per lens type | 7A |
| `/admin/inventory/items/new?category=&lensType=&sph=&cyl=` | New item (lens power prefilled from the grid) | 7A |
| `/admin/inventory/items/:id` | Item detail, stock movements, adjust stock | 7A |
| `/admin/inventory/items/:id/edit` | Edit item | 7A |
| `/admin/inventory/suppliers` | Suppliers (dialog add and edit) | 7A |
| `/admin/inventory/purchases`, `/new`, `/:id` | Purchase bills list, new bill, read-only bill | 7A |
| `/admin/finance` | redirects to `/admin/finance/expenses` | 8A |
| `/admin/finance/expenses`, `/new`, `/:id/edit` | Expenses of one day; expense form with delete | 8A |
| `/admin/finance/payouts`, `/new`, `/:id` | Doctor payouts by date range: list, new payout, payout page with Mark paid / Mark unpaid / Delete | 8B |
| `/admin/reports` | Date-range reports, one CSV export per section (PDF deferred; decided 6 Nov 2026) | 8B |
| `/admin/users` | Users, create, roles, deactivate, reset password | 1 |
| `/admin/catalog` | redirects to `/admin/catalog/departments` | 2 |
| `/admin/catalog/departments` | Departments tab: table (name, code chip, status), New department dialog, edit dialog with code-change warning | 2 |
| `/admin/catalog/doctors`, `/new`, `/:id` | Doctors tab: table (name, department, specialisation, salary, share, login link, status), search, department filter; full-page form (doctor, pay, fees cards) with `PageHeader` back | 2 |
| `/admin/catalog/fees` | Fee grid: doctors × visit types, department segments, Save row | 2 |
| `/admin/catalog/visit-types`, `/new?departmentId=`, `/:id` | Visit types tab: table (kind, operation defaults); full-page form with follow-up / operation switches, checklist list and post-op day chips | 2 |
| `/admin/settings` | Clinic settings: Clinic, Receipts and WhatsApp reminders cards, logo upload, Save FAB | 2 |
| `/admin/setup` | Initial setup card (clinic name, address, phone, what will be created). Reachable only while `settings/general` is missing; otherwise redirects to the dashboard. Admin pages show a `MaterialBanner` with a "Run setup" button while settings are missing (decided 3 Nov 2026: banner, no forced redirect) | 2 |
| `/admin/audit` | Audit log of one day with user, record and action filters; rows expand to the changed fields | 9 |

---

## 4. Key Screens

### 4.1 Login
Centered card, clinic logo if cached, email, password, Sign in. Error text under the form. No self sign-up link. Debug builds only: a small **Create test admin** text button under Sign in (DEVELOPMENT_PLAN §1, Test admin) that creates or restores the fixed test admin and signs in with it.

### 4.2 Patient search (Reception)
Single search field at the top (autofocus, searches 300 ms after typing stops or on Enter) that accepts a phone number, a patient ID (`26-00341`), a temporary ID (`T-7K3M9`) or a name. Results grouped by family: a header card with head name, phone, address, a "Duplicate phone" chip when flagged, and an Add patient button; patients as rows (name, age, gender, number chip with a pending look for temp numbers, last visit). Row actions: New visit and Book appointment (disabled until Phases 4 and 6), Open. Button "New patient" top right, which first asks for the phone and shows the family if it exists ("Add to this family"), otherwise opens the new-family form with the phone filled in. A phone search with no result offers "Register new family". Results come from this device's cache first; under cached matches a footer "Matches saved on this device. Not here? Search online" (`search-online`) repeats the search on the server (decided 5 Nov 2026, FIREBASE_ARCHITECTURE §9).

**Registration form** (`/reception/patients/new`): Family card (phone, head of family, address) when the family is new, otherwise a one-line family summary; Patient card (name, gender segmented button, "Age is known as" segmented button switching between an age field and a date-of-birth field with a picker, personal phone, address, notes). Register goes to the patient page.

**Patient page** (`/reception/patients/:id`): header card (`PatientHeader`: name, age, gender, phones, number chip) with address and notes; on wide screens a family card on the left (head, phone, Add member, Change phone, Move to another family, Edit family, list of other members that open their pages) and a tabbed card on the right (Visits, Reports, Appointments; placeholders until Phases 4–6). Decided 5 Nov 2026: the Visits tab reads 3 visits when it is shown and offers "Load more" (`visits-load-more`) for the next 3; its label shows the patient's `visitCount`. Page actions: Send WhatsApp (opens `wa.me` with the ad-hoc template) and Edit. Move asks for the target family's phone, shows the family found, then confirms.

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

The fee is read-only; when the doctor has no fee for the chosen type the row says "No fee set — ask Admin" and Save stays disabled. Phase 5B: choosing an operation visit type for a patient with a scheduled operation of that type shows `visit-operation-link` ("Operation scheduled for 12 Nov 2026") and the saved visit carries `operationId`. Discount reason is a dropdown of presets plus Other, which reveals a text field. Payment reference appears for bank, JazzCash and Easypaisa. The doctor row shows "Waiting now: N" from today's visits.

After save: dialog with the token in large type (`E-12`), patient and doctor line, amounts, copy stepper (defaults to Settings), Print and Done. Done goes to the visit detail page; the dialog also has "New visit for another patient" back to search.

**Visits list** (`/reception/visits`): today's visits newest first as a table (token chip, time, patient, doctor, type, net, payment, status chip) or cards on phones; filter field for patient name or token; New visit button opens patient search. Row opens the visit detail.

**Visit detail** (`/reception/visits/:id`): `PageHeader` with the token, patient header, visit card (doctor, department, type, amounts, payment, status chip, created by and time) and a receipt card with a copy stepper and Print (decided 4 Nov 2026: this is where reprints happen).

**Shift summary** (`/reception/summary`): tiles for Visits, Collected (net), Cash, Bank, JazzCash, Easypaisa and Discounts for today, plus a table of visits per doctor. Switch "My visits only" at the top (decided 4 Nov 2026).

### 4.4 Queue board (Reception)
One column per doctor with a visit today (toggle "Show all doctors" adds active doctors without visits; resolves §8 open point 2). Column header: doctor name, department chip, counts waiting / in progress / done. Rows: token chip, patient name, visit type, time since created, status chip, and a Start (waiting → in progress) or Complete (in progress → completed) button; completed rows collapse under "Done" at the bottom of the column. Updates live from the today's-visits listener. Decided 4 Nov 2026: reception may change status here.

### 4.5 Doctor queue (Doctor)
List of waiting visits in token order with a large token chip, patient name, age and gender, visit type. Tapping opens the consultation and moves the visit to in progress. Completed visits of today collapse under a "Done today" section.

Built 5 Nov 2026 (Phase 5A): header line "N waiting · M done"; in-progress rows first with a Complete button, waiting rows with Start, both keyed `doctor-start-<id>` / `doctor-complete-<id>`; rows keyed `doctor-row-<id>` open `/doctor/visits/:id`. Empty state "No patients yet today". A multi-role user sees only the visits of their own doctor record.

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

Medicine field suggests from inventory items of category medicine, free text allowed (suggestions arrive with inventory in Phase 7; 5A is free text).

Built 5 Nov 2026 (Phase 5A): the header card shows `PatientHeader`, token chip, visit type and `Fee / Discount (reason) / Net`. Departments other than Eye and Homeopathy show only Diagnosis and Advice. Eye cells are keyed `rx-od-sph` … `rx-os-va`; Homeo rows `rx-homeo-<i>-medicine|potency|dosage|duration` with `rx-homeo-add` and `rx-homeo-remove-<i>`; `rx-diagnosis`, `rx-advice`. Follow-up row: chips `rx-follow-3d`, `rx-follow-1w`, `rx-follow-2w`, `rx-follow-1m`, a date button `rx-follow-pick` and a clear button `rx-follow-clear`, showing the resulting date. Bottom bar: `rx-save` (Save), `rx-print` (Print Rx, enabled once saved), `rx-complete` (Complete; confirm dialog `rx-complete-confirm` when nothing is saved). After the Karachi day of the prescription the form is read-only with a "Locked" chip and only Print stays. Validation messages appear under the field; Save stays enabled and shows the first problem in a snackbar. The History tab lists the patient's other visits with their prescriptions (same rows as §4.6a), 3 per page with "Load more" (`history-load-more`); nothing is read until the tab is opened.

### 4.6a Patient history (Doctor)
`/doctor/patients/:id`: `PageHeader` with the patient name, `PatientHeader` card, then the visits newest first as `ExpansionTile`s keyed `history-visit-<id>`: date, token chip, doctor, type, status chip; expanded shows the prescription (Eye table or Homeo rows, diagnosis, advice, follow-up) or "No prescription". Decided 5 Nov 2026: the list is paged, 3 visits per page. The first page is read when the Visits tab is shown (nothing before), and a "Load more" footer (`history-load-more`) reads the next 3; the tab label shows the patient's total `visitCount`. The same rows and footer serve the consultation History tab (§4.6), which leaves out the visit being consulted. Reports and Operations tabs arrive in 5B. The doctor's patient search (`/doctor/patients`) is the reception search without New patient, Add patient, New visit or Book.

### 4.6b Personal summary (Doctor)
`/doctor/me`: three cards Today, This week, This month keyed `me-today`, `me-week`, `me-month`, each with Patients seen, Fees, Discounts, Net (`Rs`). A Refresh button `me-refresh`; an offline or failed load shows the error under the cards. Operation-type defaults are added here in 5B.

### 4.7 Operation detail (Doctor)
Header: patient, operation type, surgeon, scheduled date picker, status chip. Checklist as checkboxes with who and when on tick; "Add item" at the bottom. Post-op days as chips (`Day 1`, `Day 7`, `Day 30`) with add and remove; changing them regenerates appointments after a confirm. "Mark done" disabled until all items are ticked, with an "Override with reason" link.

Built 5 Nov 2026 (Phase 5B). `/doctor/operations`: two tabs Scheduled and Done (cancelled under Done), rows `op-row-<id>` with date, patient, type, surgeon and an operation status chip. Detail keys: `op-date-pick` (date change confirms "Move the follow-ups too?"), `op-check-<itemId>` checkboxes showing "by <name>, <time>" when ticked, `op-add-item-input` + `op-add-item`, `op-day-<n>` chips, `op-day-input` + `op-day-add` (confirm dialog `op-day-confirm` before appointments are regenerated), and a fixed bottom bar (so it stays reachable on long pages) with `op-cancel` → `op-cancel-reason` + `op-cancel-confirm`, `op-override` → dialog `op-override-reason` + `op-override-confirm`, and `op-done` (disabled until every item is ticked). Done and cancelled operations are read-only and have no bar.

### 4.7a Schedule operation (Doctor, consultation Operation tab)
When the visit has no operation: button `op-schedule` opens a sheet with `op-type` (operation types of the department), `op-surgeon` (active doctors of the department, self preselected), `op-date` (picker, defaults to tomorrow), `op-notes`, `op-save`. Saving shows the operation summary on the tab with `op-open` to the detail page. When the visit is linked (`operationId`) or the patient has a scheduled operation, the tab shows that record instead.

### 4.7b Reports (Reception upload, Doctor view)
Patient page Reports tab: list rows `report-row-<id>` (title, date, uploader, size, visit token when linked) with `report-open-<id>` (new tab) and, for reception and Admin, `report-delete-<id>` → dialog `report-delete-reason` + `report-delete-confirm`. Button `reports-upload` opens the dialog: `report-title`, `report-pick-file`, `report-pick-camera` (devices with a camera), `report-visit` dropdown of the patient's visits, `report-save`; a progress bar while uploading; errors inline. The same list (without upload and delete) sits on the doctor's consultation Reports tab and history page.

### 4.6c Me tab defaults (Doctor)
Below the period cards, a card per operation type of the doctor's department (`defaults-type-<id>` expansion): checklist items with `defaults-check-remove-<typeId>-<itemId>`, `defaults-check-input-<typeId>` + `defaults-check-add-<typeId>`, post-op day chips `defaults-day-<typeId>-<n>`, `defaults-day-input-<typeId>` + `defaults-day-add-<typeId>`, and `defaults-save-<typeId>`. Changes affect future operations only.

### 4.8 Admin dashboard
Range picker (Today, This week, This month, Custom). Row of KPI tiles: Revenue, Visits, New patients, Discounts, Expenses, Net profit. Below: revenue by department and by doctor (bar), by payment method (stacked bar), visits per day (line). Low-stock list card. Everything reads `dailySummaries`. Keys (decided 6 Nov 2026, Phase 8A): segments `dash-range-<today|week|month|custom>`, `dash-custom-from` / `dash-custom-to` (date pickers shown for Custom), `dash-refresh`; tiles `dash-kpi-<revenue|visits|new-patients|discounts|expenses|profit>` (the tile's value text carries the key); cards `dash-by-department`, `dash-by-doctor`, `dash-by-payment` (`fl_chart` bars with the amounts listed under the chart), `dash-visits-per-day` (line); `dash-low-stock` card with rows `dash-low-<itemId>` opening the item (reads `InventoryController`, "All stocked" when none); `dash-recompute` opens a dialog (`recompute-date` picker, `recompute-confirm`) that calls `recomputeDay` and shows "Day recomputed". New and returning counts sit under the Visits tile; loading and error states follow the other pages.

### 4.9 Fee grid (Admin)
Table with doctors as rows and the department's active visit types as columns (follow-up column labelled "(reduced)"), amount cells editable inline, Save row button enabled only when the row changed, undo icon discards. Department segments at the top since visit types are per department; switching discards unsaved edits.

### 4.9a Catalog (Admin)
`/admin/catalog/*` share a `TabBar` (Departments, Doctors, Visit types, Fees) whose tabs are routes. Lists follow the Users screen pattern: `DataTable` on desktop, `ListTile` on phones, a row menu with Edit and Deactivate / Reactivate (confirm dialog on deactivate), "Show inactive" filter chip. Departments edit in a dialog; doctors and visit types open a full page inside the shell with a `PageHeader` (back arrow, title) and a Save FAB.

### 4.9b Settings and first run (Admin)
Settings is one scrolling form in three cards (Clinic with logo row and, from Phase 10, a Theme colour row of eight swatches `settings-colour-<key>` with the chosen one ringed and checked; Receipts; WhatsApp reminders with a switch above each template; a switched-off template is disabled). Save FAB bottom right; snackbar "Settings saved". Initial setup is a centered card listing what will be created, with a single "Run setup" button; on success it goes to the dashboard and the banner disappears.

### 4.10 Lens grid (Admin, Reception sale picker)
Segmented buttons per lens type (`lens-type-<singleVision|bifocal|progressive>`). Grid with SPH −20.00 to +20.00 down the side and CYL 0.00 to −8.00 across the top in 0.25 steps (decided 6 Nov 2026); the sheet scrolls both ways, rows are built lazily and the view opens with SPH 0.00 ten rows below the top (−2.50 to about +3.00 visible on a desktop). Each cell (`lens-cell-<lensKey>`) shows stock on hand, red tint at or below the low-stock threshold, grey when the item does not exist. Tapping a cell opens the item; tapping a grey cell opens the new-item form with the type and power filled in. In the sale picker (7B) a tap adds that lens to the sale and the cell matching the patient's latest eye prescription is pre-highlighted.

### 4.15 Inventory (Admin)
`/admin/inventory/*` share a `TabBar` whose tabs are routes (`inv-tab-<medicine|frame|lens|consumable|suppliers|purchases>`), like Catalog. Category lists follow the Users pattern (`DataTable` on desktop, `ListTile` on phones): search field `inv-search` (name or brand), filter chips `inv-low-stock` and `inv-show-inactive`, rows `inv-row-<id>` (name, brand, unit, sale price, stock with a red "Low" chip at or below the threshold) that open the detail, a row menu `inv-menu-<id>` with Edit and Deactivate / Reactivate (confirm on deactivate), FAB `inv-new-item`. Item form (`PageHeader`, Save FAB `item-save`): `item-name`, `item-brand`, `item-unit`, `item-purchase-price`, `item-sale-price`, `item-low-stock`, `item-active`; on create `item-opening-stock`; for lenses the name is generated and the form shows `item-lens-type`, `item-lens-sph`, `item-lens-cyl` instead of the name. Item detail: header card (name, category, brand, unit, prices, stock, threshold), `inv-edit`, `inv-adjust` opening the adjust dialog (`inv-adjust-qty` signed, `inv-adjust-reason`, `inv-adjust-save`), then the last 50 movements (`inv-mov-<id>`: date, type chip, quantity, reason or bill, by whom). Suppliers: rows `supplier-row-<id>`, menu `supplier-menu-<id>`, FAB `new-supplier`, dialog `supplier-name`, `supplier-phone`, `supplier-address`, `supplier-notes`, `supplier-save`. Purchases: rows `purchase-row-<id>` (date, supplier, bill no, lines, total), `purchase-refresh` (read once), FAB `new-purchase`; the form has `purchase-supplier` (dropdown of active suppliers), `purchase-bill-no`, `purchase-date` (date picker, default today), `purchase-note`, an item picker `purchase-item-search` (autocomplete over the active items, lens items by generated name) that appends a line, lines with `purchase-qty-<n>`, `purchase-cost-<n>` (prefilled with the item's purchase price), `purchase-remove-<n>`, a running total, and Save `purchase-save` which confirms (`purchase-confirm`, "Stock will increase and an expense of Rs X will be recorded") because the bill cannot be edited afterwards. The bill page (`/admin/inventory/purchases/:id`) is read-only.

### 4.11 Reminders due today (Reception)
Four sections (decided 6 Nov 2026): Appointments tomorrow (manual and surgery-day), Follow-ups due and Post-op follow-ups due (today to today + follow-up reminder days), Overdue (booked follow-ups and post-ops from the last 7 days). Each row (`rem-row-<id>`): patient and number, phone, doctor, date and time, source chip, Send (`rem-send-<id>`, opens `wa.me/<phone>?text=<template>` in a new tab and marks the row sent). A sent row shows "Sent 06 Nov, 10:32" ("by you" when the signed-in user sent it) and a Send again link with the same key. Rows without a phone show "No phone" and no Send. Header: count and Refresh (`rem-refresh`); the list is read once when opened. Sections for reminder types Admin has turned off are hidden; section headers carry keys `rem-section-tomorrow`, `rem-section-followUp`, `rem-section-postOp`, `rem-section-overdue`. Empty state "Nothing due today".

### 4.11a Post-op days sheet (Reception, Admin)
Opened from a booked post-op row (`appt-postop-<id>` on the day view, `patient-appt-postop-<id>` on the patient tab). Bottom sheet (Close `postop-close`) with the operation type and surgery date, the day chips (`postop-day-<n>`, deletable), an add row (`postop-day-input`, `postop-day-add`), and Save (`postop-save`) which confirms (`postop-confirm`) before re-booking the post-op appointments. The surgery-day appointment is not touched. A done operation's days stay editable (follow-ups continue after surgery); a cancelled operation's sheet is read-only.

### 4.11b My upcoming appointments (Doctor)
`/doctor/appointments`: the doctor's booked appointments for the next 30 days, grouped under day headers (`doc-appt-day-<date>`), rows `doc-appt-row-<id>` with time, patient, number and source chip; read-only. Header count and Refresh (`doc-appt-refresh`). Empty state "No upcoming appointments". Sidebar entry on desktop; under More in the phone bottom bar.

### 4.12 Appointments day view (Reception, Admin)
Decided 5 Nov 2026. Header row: previous day (`appt-date-prev`), the date (`appt-date-pick`, opens a calendar; a "Today" chip (`appt-date-today`) when another day is shown), next day (`appt-date-next`) and Book (`appt-book`, goes to patient search). Below, the queue-board layout: one card per doctor with appointments that day (`appt-column-<doctorId>`, catalog name order), rows `appt-row-<id>` with the time (or "No time"), patient name and number, a source chip (Manual, Follow-up, Post-op, Operation) and the appointment status chip; booked rows first (by time, then name), then arrived, then cancelled and no-show. Row actions by status and source: booked → Arrived (`appt-arrived-<id>`, opens the new-visit form with the doctor preselected), Reschedule (`appt-reschedule-<id>`, dialog with date `appt-reschedule-date`, time `appt-reschedule-time`, Save `appt-reschedule-save`), Cancel (`appt-cancel-<id>`, confirm `appt-cancel-confirm`), No-show (`appt-noshow-<id>`, only on or after the day, confirm `appt-noshow-confirm`); surgery-day rows get Arrived and No-show only; arrived, cancelled and no-show rows are read-only. Empty state "No appointments on this day".

### 4.13 Book appointment (Reception, Admin)
`/<role>/appointments/new?patientId=`: patient header card, then Department (segmented, `book-dept-<id>`), Doctor (`book-doctor`, auto-picked when the department has one active doctor; the patient's last doctor preselected), Date (`book-date`, calendar from today, defaults to tomorrow), Time (`book-time`, free text such as "10:30", optional), Notes (`book-notes`, optional), Book (`book-save`). On success a snackbar "Appointment booked" and the patient page opens. Entry points: `patient-book-<id>` on search rows (Phase 3's disabled Book), `patient-book-appointment` on the patient page Appointments tab.

### 4.16 Sales (Reception, Admin)
Decided 6 Nov 2026 (Phase 7B). **Sales list** (`/<role>/sales`): today's sales from one listener while the page is open, a header line with the count and the day's total (`sales-total`), rows `sale-row-<id>` (time, customer name, line count, total, payment chip, a "Voided" chip when deleted) that open the detail, FAB `new-sale` (walk-in sale). Entry points with a patient: `patient-sell-<id>` on the patient search row, `patient-sell` on the patient page, `visit-sell` on the visit detail (links the sale to the visit).

**New sale** (`/<role>/sales/new?patientId=&visitId=`): patient header card when a patient is given, otherwise a customer name field `sale-customer`; a visit chip when linked. Item picker `sale-item-search` (autocomplete over active non-lens items by name or brand) appends a line; `sale-add-lens` opens the lens picker sheet: lens type segmented buttons (`lens-type-<key>`), the Add right (`sale-lens-right`) and Add left (`sale-lens-left`) buttons showing the power suggested from the patient's latest eye prescription (hidden when none), and the lens grid (`lens-cell-<lensKey>`, suggested cells highlighted, grey cells disabled). Lines: name with power, `sale-qty-<n>`, `sale-price-<n>` (prefilled with the sale price, editable), `sale-remove-<n>`, and a short-stock warning `sale-short-<n>` ("Only 2 in stock" or "Out of stock") that does not block. Below: subtotal, `sale-discount`, `sale-discount-reason` (required when the discount is above 0), `sale-payment` (segmented), `sale-payment-ref` for non-cash, `sale-total`, Save FAB `sale-save`. On success a snackbar "Sale saved" and the sale detail opens.

**Sale detail** (`/<role>/sales/:id`): `PageHeader`, customer block (name, patient number and phone when known, visit token when linked), items table, amounts (subtotal, discount with reason, total, payment), a receipt card with the copies stepper and Print (`sale-print`), and for Admin a Void button (`sale-void`) opening a dialog with `sale-void-reason` and `sale-void-confirm`; a voided sale shows a red banner with the reason and no actions. The sale receipt (A4, `SaleReceiptPdf`) reuses the visit receipt layout without the token box; the visit receipt adds an "Items sold" table and a grand total line when the visit has a sale (visit detail shows the same card with `visit-sale-<saleId>` opening the sale).

### 4.17 Expenses (Admin)
Decided 6 Nov 2026 (Phase 8A). `/admin/finance` redirects to `/admin/finance/expenses`; a `TabBar` whose tabs are routes (`fin-tab-expenses`, `fin-tab-payouts`; Payouts built in 8B, below). **Expenses list**: a day strip `exp-prev-day`, `exp-date` (date picker, default today), `exp-next-day`, `exp-refresh` (read once; the list reloads after your own saves), header total `exp-total` (non-deleted), rows `exp-row-<id>` (category chip, note, amount, a source chip for purchase and payout expenses, struck through with "Deleted" when deleted) that open the form, FAB `new-expense`, empty state "No expenses on this day". **Expense form** (`/admin/finance/expenses/new`, `/admin/finance/expenses/:id/edit`): `PageHeader`, `expense-category` dropdown, `expense-amount`, `expense-date` (date picker), `expense-note`, Save FAB `expense-save` → snackbar "Expense saved" and back to the day; errors inline in `expense-error`. On an existing expense the header has `expense-delete` → dialog `expense-delete-reason` + `expense-delete-confirm` → "Expense deleted". A purchase or payout expense opens read-only (fields disabled, no Save) with Delete only and a note naming the bill or payout.

**Payouts** (Phase 8B, decided 6 Nov 2026). The Payouts tab lists every payout latest period first: rows `payout-row-<id>` (doctor, period, total, a Paid / Unpaid / Deleted chip, struck through when deleted) open the payout page; `payouts-refresh`; FAB `new-payout`; empty state "No payouts yet". **New payout** (`/admin/finance/payouts/new`): `payout-doctor` dropdown (active doctors), period buttons `payout-from` / `payout-to` (default: last calendar month), `payout-salary` (prefilled with the doctor's monthly salary, editable), a warning card `payout-overlap` when the doctor already has a live payout touching the period, a figures card (`payout-gross`, `payout-net`, `payout-share`, `payout-total`) read once from the day summaries, `payout-note`, Save FAB `payout-save` → "Payout saved" and the payout page; errors inline in `payout-error`. **Payout page** (`/admin/finance/payouts/:id`): `PageHeader` "Payout: Dr X" with `payout-mark-paid` (confirm dialog `payout-paid-confirm` → "Payout marked paid"), `payout-unmark-paid` (dialog `payout-unpaid-reason` + `payout-unpaid-confirm` → "Payout marked unpaid") and `payout-delete` (unpaid only; dialog `payout-delete-reason` + `payout-delete-confirm` → "Payout deleted"); the card shows the period, chip, gross, discounts, net, share basis and share, salary, total, note, paid date and `payout-expense` ("Open the expense"), the last unpaid reason, and a red "Deleted: reason" banner.

### 4.18 Admin visits and corrections
Decided 6 Nov 2026 (Phase 8B). **Day list** (`/admin/visits`): a strip with `visits-prev-day`, `visits-date` (date picker, default today), `visits-next-day`, `visits-refresh` (one read per day shown, deleted visits included), a text filter `visits-filter` (name, patient number, phone or exact token, on the client) and `visits-new` (opens Admin's patient search); rows reuse `VisitRow` (`visit-row-<id>`), deleted ones struck through with a "Deleted" chip in place of the status; empty states "No visits on this day" / "No visit matches the filter". **Visit page** (`/admin/visits/:id`): for Admin the header gains `visit-edit` and `visit-delete`; Delete opens `visit-delete-reason` + `visit-delete-confirm` → "Visit deleted"; a deleted visit shows a red "Deleted: reason" banner and loses the receipt, Sell and Edit actions; the card shows "Last correction" with the latest `editReason`. **Correction form** (`/admin/visits/:id/edit`): `PageHeader` "Edit visit E-12", patient line, `correct-doctor` (only doctors of the visit's department; the current one even if inactive), `correct-fee`, `correct-discount`, `correct-reason` (presets + Other → `correct-other-reason`), `correct-payment` (+ `correct-payment-ref` for non-cash), `correct-edit-reason` (required), Save FAB `correct-save` → "Visit updated" and back to the visit page; errors inline in `correct-error` ("Nothing changed" when nothing differs). A deleted visit opens read-only.

### 4.19 Reports (Admin)
Decided 6 Nov 2026 (Phase 8B). `/admin/reports` (sidebar; under More on phones): the dashboard's range control (`rep-range-<today|week|month|custom>`, `rep-custom-from`, `rep-custom-to`, `rep-refresh`; one `dailySummaries` range read), then one card per section (`report-<key>`) with a `DataTable` and an "Export CSV" button (`report-export-<key>`): `daily` (full width: date, visits, new, returning, gross, discounts, net, sales, sale discounts, expenses, net profit, one row per day plus Total), `by-doctor`, `by-department`, `by-payment`, `patients`, `discounts-by-user` (display names from `users`), `discounts-by-reason`, `expenses-by-category`, `sales-by-category`. Export writes `<section>_<start>_<end>.csv` (one date for a single day) through `FileSaver` and shows "Saved <file>". Phase 10 (decided 6 Nov 2026): a second button "Export PDF" (`report-export-pdf-<key>`) builds an A4 PDF of the section (§6) and opens the print dialog through `ReceiptPrinter`; a tenth card `sales-margins` (category, sold, cost, margin, margin %) follows `sales-by-category`.

### 4.20 Audit log (Admin)
Decided 6 Nov 2026 (Phase 9). `/admin/audit` (sidebar; under More on phones): a day strip `audit-prev-day`, `audit-date` (date picker, default today), `audit-next-day`, `audit-refresh` (one read per day shown), then dropdowns `audit-filter-user` (users seen that day), `audit-filter-collection` (record type) and `audit-filter-action` (Edit / Delete) with `audit-clear-filters` once any is set. Rows `audit-row-<eventId>` are `ExpansionTile`s: an action chip (Delete in the error colour), "Visits · Ali Khan", then time, user and the reason in italics; expanded, a Field / Before / After table of the changed fields and the record ID. Empty states "No changes on this day" / "No change matches the filters".

### 4.14 Patient page Appointments tab (Reception, Admin)
Rows `patient-appt-row-<id>`: date, time, doctor, source chip, status chip; booked ones soonest first, then the rest newest first. Book button at the top (`patient-book-appointment`). Row actions live on the day view (6A); "Change post-op days" on post-op rows arrives in 6B.

Built 5 Nov 2026 (Phase 6A): §4.12–4.14 as described; chips in `core/widgets/appointment_chips.dart`; the reschedule and confirm dialogs in `features/appointments/presentation/widgets/appointment_dialogs.dart`. The Admin sidebar gains Appointments (under More on phones).

---

## 5. Shared Components (`lib/core/widgets/`)

| Widget | Use |
|---|---|
| `MoneyText` | Formats int PKR as `Rs 1,500`. Variants for discount (red) and total (bold). |
| `TokenChip` | Token label with department colour. |
| `StatusChip` | Visit, appointment, operation statuses. |
| `EmptyState` | Icon, title, hint, optional action. |
| `ConfirmDialog` | Title, message, optional required reason field, destructive style. |
| `SyncBadge` | Online / Offline / Syncing N in the top bar, from `TodayVisitsController` (Phase 4). |
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

**Report (Phase 10):** clinic name, section title and the date range in the header, then the section's table with the Total row in bold, numbers right-aligned, repeated header on every page, page numbers in the footer. Landscape when the table has more than six columns (the daily table).

---

## 7. Accessibility and Input

- Minimum touch target 48 px on phones; compact density only changes padding on desktop.
- Every colour-coded chip also carries text.
- Keyboard: on web, Enter submits the current form, Tab order follows the visual order, the search field is focused on open.
- Barcode or scanner input for patient ID is not in v1; the patient ID field accepts paste.
- Text scales with system font size; tables scroll rather than clip.

---

## 8. Open Points

1. Logo size and placement on receipt will be tuned once the owner supplies the real logo. Phase 4 prints the receipt without the logo (fetching the uploaded image for the PDF needs an offline-safe cache; the clinic name, address and phone print).
2. Resolved 4 Nov 2026: the queue board shows doctors with at least one visit today, plus a "Show all doctors" toggle (§4.4).

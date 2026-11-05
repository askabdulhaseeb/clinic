// Firestore rules allow/deny matrix for Phases 1 to 5B (FIREBASE_ARCHITECTURE.md §6).
// Runs against the Firestore emulator on 127.0.0.1:8080.
import * as fs from "node:fs";
import * as path from "node:path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "ramzan-clinic-web";
const ADMIN = "admin-uid";
const ALICE = "alice-uid";
const BOB = "bob-uid";

const adminToken = { roles: ["admin"], doctorId: null, branchIds: ["main"] };
const receptionToken = { roles: ["reception"], doctorId: null, branchIds: ["main"] };
const doctorToken = { roles: ["doctor"], doctorId: "d1", branchIds: ["main"] };

let env: RulesTestEnvironment;

function userDoc(uid: string, roles: string[]) {
  return {
    email: `${uid}@clinic.pk`,
    displayName: uid,
    roles,
    doctorId: null,
    active: true,
    branchIds: ["main"],
    mustChangePassword: true,
    createdAt: new Date(),
    createdBy: ADMIN,
    updatedAt: new Date(),
    updatedBy: ADMIN,
  };
}

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

afterAll(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`users/${ADMIN}`).set(userDoc(ADMIN, ["admin"]));
    await db.doc(`users/${ALICE}`).set(userDoc(ALICE, ["reception"]));
    await db.doc(`users/${BOB}`).set(userDoc(BOB, ["reception"]));
  });
});

const asAdmin = () => env.authenticatedContext(ADMIN, adminToken).firestore();
const asAlice = () => env.authenticatedContext(ALICE, receptionToken).firestore();
// Signed in but with no roles claim at all.
const asNoClaims = () => env.authenticatedContext("noclaims-uid").firestore();
const asAnon = () => env.unauthenticatedContext().firestore();
const asDoctor = () => env.authenticatedContext("doctor-uid", doctorToken).firestore();

describe("users read", () => {
  it("own doc allowed", async () => {
    await assertSucceeds(asAlice().doc(`users/${ALICE}`).get());
  });
  it("other user's doc denied", async () => {
    await assertFails(asAlice().doc(`users/${BOB}`).get());
  });
  it("admin may read any", async () => {
    await assertSucceeds(asAdmin().doc(`users/${ALICE}`).get());
    await assertSucceeds(asAdmin().collection("users").get());
  });
  it("non-admin list denied", async () => {
    await assertFails(asAlice().collection("users").get());
  });
  it("unauthenticated denied", async () => {
    await assertFails(asAnon().doc(`users/${ALICE}`).get());
  });
  it("signed in without a roles claim can still read own doc only", async () => {
    await assertFails(asNoClaims().doc(`users/${ALICE}`).get());
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("users/noclaims-uid").set(userDoc("noclaims-uid", []));
    });
    await assertSucceeds(asNoClaims().doc("users/noclaims-uid").get());
  });
});

describe("users create", () => {
  it("denied for admin, self and anonymous", async () => {
    await assertFails(asAdmin().doc("users/new-uid").set(userDoc("new-uid", ["reception"])));
    await assertFails(asAlice().doc("users/new-uid").set(userDoc("new-uid", ["reception"])));
    await assertFails(asAnon().doc("users/new-uid").set(userDoc("new-uid", ["reception"])));
  });
});

describe("users update by owner", () => {
  it("mustChangePassword -> false with updatedBy = self allowed", async () => {
    await assertSucceeds(
      asAlice().doc(`users/${ALICE}`).update({
        mustChangePassword: false,
        updatedAt: new Date(),
        updatedBy: ALICE,
      })
    );
  });
  it("mustChangePassword -> true denied", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`users/${ALICE}`).update({ mustChangePassword: false });
    });
    await assertFails(
      asAlice().doc(`users/${ALICE}`).update({ mustChangePassword: true, updatedBy: ALICE })
    );
  });
  it("updatedBy must be self", async () => {
    await assertFails(
      asAlice().doc(`users/${ALICE}`).update({ mustChangePassword: false, updatedBy: BOB })
    );
  });
  it("own roles change denied", async () => {
    await assertFails(
      asAlice().doc(`users/${ALICE}`).update({ roles: ["admin"], updatedBy: ALICE })
    );
    await assertFails(
      asAlice()
        .doc(`users/${ALICE}`)
        .update({ mustChangePassword: false, roles: ["admin"], updatedBy: ALICE })
    );
  });
  it("own displayName / active change denied", async () => {
    await assertFails(
      asAlice().doc(`users/${ALICE}`).update({ displayName: "Hacker", updatedBy: ALICE })
    );
    await assertFails(asAlice().doc(`users/${ALICE}`).update({ active: false, updatedBy: ALICE }));
  });
  it("other user's mustChangePassword denied", async () => {
    await assertFails(
      asAlice().doc(`users/${BOB}`).update({ mustChangePassword: false, updatedBy: ALICE })
    );
  });
});

describe("users update by admin", () => {
  it("displayName change allowed", async () => {
    await assertSucceeds(
      asAdmin().doc(`users/${ALICE}`).update({
        displayName: "Alice Renamed",
        updatedAt: new Date(),
        updatedBy: ADMIN,
      })
    );
  });
  it("displayName change with wrong updatedBy denied", async () => {
    await assertFails(
      asAdmin().doc(`users/${ALICE}`).update({ displayName: "Alice Renamed", updatedBy: ALICE })
    );
  });
  it("roles change denied (functions only)", async () => {
    await assertFails(asAdmin().doc(`users/${ALICE}`).update({ roles: ["admin"], updatedBy: ADMIN }));
  });
  it("active / doctorId / mustChangePassword change denied", async () => {
    await assertFails(asAdmin().doc(`users/${ALICE}`).update({ active: false, updatedBy: ADMIN }));
    await assertFails(asAdmin().doc(`users/${ALICE}`).update({ doctorId: "d1", updatedBy: ADMIN }));
    await assertFails(
      asAdmin().doc(`users/${ALICE}`).update({ mustChangePassword: false, updatedBy: ADMIN })
    );
  });
});

describe("users delete", () => {
  it("denied for everyone", async () => {
    await assertFails(asAdmin().doc(`users/${ALICE}`).delete());
    await assertFails(asAlice().doc(`users/${ALICE}`).delete());
    await assertFails(asAnon().doc(`users/${ALICE}`).delete());
  });
});

// ---------------------------------------------------------------------------
// Phase 2: master data
// ---------------------------------------------------------------------------

const department = (by: string) => ({
  name: "Eye",
  code: "E",
  sortOrder: 1,
  active: true,
  createdAt: new Date(),
  createdBy: by,
  updatedAt: new Date(),
  updatedBy: by,
});

const visitType = (by: string) => ({
  departmentId: "eye",
  name: "Checkup",
  isOperation: false,
  isFollowUp: false,
  sortOrder: 1,
  active: true,
  defaultPreOpChecklist: [],
  defaultPostOpDays: [],
  createdAt: new Date(),
  createdBy: by,
  updatedAt: new Date(),
  updatedBy: by,
});

const doctor = (by: string) => ({
  userId: null,
  name: "Dr Sara",
  departmentId: "eye",
  departmentCode: "E",
  specialisation: "Cataract",
  salary: 50000,
  sharePercent: 10,
  shareBasis: "gross",
  fees: { "eye-checkup": 1500 },
  active: true,
  branchId: "main",
  createdAt: new Date(),
  createdBy: by,
  updatedAt: new Date(),
  updatedBy: by,
});

const settings = (by: string) => ({
  clinicName: "Ramzan Clinic",
  logoUrl: null,
  address: "",
  phone: "",
  receiptFooter: "",
  defaultReceiptCopies: 1,
  followUpReminderDays: 0,
  reminders: { appointment: true, followUp: true, postOp: true },
  whatsappTemplates: { appointment: "", followUp: "", postOp: "", adhoc: "" },
  timezone: "Asia/Karachi",
  updatedAt: new Date(),
  updatedBy: by,
});

describe("master data read", () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.doc("settings/general").set(settings(ADMIN));
      await db.doc("departments/eye").set(department(ADMIN));
      await db.doc("visitTypes/eye-checkup").set(visitType(ADMIN));
      await db.doc("doctors/d1").set(doctor(ADMIN));
      await db.doc("branches/main").set({ name: "Main", active: true, createdBy: ADMIN });
    });
  });
  it("any signed-in user reads all of it", async () => {
    await assertSucceeds(asAlice().doc("settings/general").get());
    await assertSucceeds(asAlice().collection("departments").get());
    await assertSucceeds(asAlice().collection("visitTypes").get());
    await assertSucceeds(asAlice().collection("doctors").get());
    await assertSucceeds(asAlice().doc("branches/main").get());
    await assertSucceeds(asNoClaims().collection("doctors").get());
  });
  it("anonymous denied", async () => {
    await assertFails(asAnon().doc("settings/general").get());
    await assertFails(asAnon().collection("departments").get());
    await assertFails(asAnon().collection("doctors").get());
  });
});

describe("master data write", () => {
  it("admin creates and updates with createdBy/updatedBy = self", async () => {
    await assertSucceeds(asAdmin().doc("branches/main").set({ name: "Main", active: true, createdBy: ADMIN }));
    await assertSucceeds(asAdmin().doc("settings/general").set(settings(ADMIN)));
    await assertSucceeds(asAdmin().doc("departments/eye").set(department(ADMIN)));
    await assertSucceeds(asAdmin().doc("visitTypes/eye-checkup").set(visitType(ADMIN)));
    await assertSucceeds(asAdmin().doc("doctors/d1").set(doctor(ADMIN)));

    await assertSucceeds(
      asAdmin().doc("settings/general").update({ clinicName: "Renamed", updatedBy: ADMIN })
    );
    await assertSucceeds(
      asAdmin().doc("departments/eye").update({ name: "Eye Care", code: "EY", updatedBy: ADMIN })
    );
    await assertSucceeds(
      asAdmin().doc("doctors/d1").update({ fees: { "eye-checkup": 2000 }, updatedBy: ADMIN })
    );
    await assertSucceeds(
      asAdmin().doc("visitTypes/eye-checkup").update({ active: false, updatedBy: ADMIN })
    );
  });
  it("reception and anonymous cannot write", async () => {
    await assertFails(asAlice().doc("departments/eye").set(department(ALICE)));
    await assertFails(asAlice().doc("settings/general").set(settings(ALICE)));
    await assertFails(asAlice().doc("doctors/d1").set(doctor(ALICE)));
    await assertFails(asAlice().doc("visitTypes/v1").set(visitType(ALICE)));
    await assertFails(asAnon().doc("departments/eye").set(department("anon")));
  });
  it("wrong createdBy / updatedBy denied", async () => {
    await assertFails(asAdmin().doc("departments/eye").set(department(ALICE)));
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("departments/eye").set(department(ADMIN));
    });
    await assertFails(asAdmin().doc("departments/eye").update({ name: "X", updatedBy: ALICE }));
  });
  it("shape checks: empty names, bad share, bad basis", async () => {
    await assertFails(asAdmin().doc("departments/x").set({ ...department(ADMIN), name: "" }));
    await assertFails(asAdmin().doc("departments/x").set({ ...department(ADMIN), code: "" }));
    await assertFails(asAdmin().doc("settings/general").set({ ...settings(ADMIN), clinicName: "" }));
    await assertFails(asAdmin().doc("doctors/d2").set({ ...doctor(ADMIN), sharePercent: 150 }));
    await assertFails(asAdmin().doc("doctors/d2").set({ ...doctor(ADMIN), shareBasis: "half" }));
    await assertFails(asAdmin().doc("doctors/d2").set({ ...doctor(ADMIN), salary: -1 }));
    await assertFails(asAdmin().doc("doctors/d2").set({ ...doctor(ADMIN), branchId: "other" }));
    await assertFails(asAdmin().doc("visitTypes/v2").set({ ...visitType(ADMIN), isOperation: "yes" }));
  });
  it("doctor userId is functions-only on update", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("doctors/d1").set(doctor(ADMIN));
    });
    await assertFails(asAdmin().doc("doctors/d1").update({ userId: ALICE, updatedBy: ADMIN }));
    await assertFails(asAdmin().doc("doctors/d1").update({ branchId: "b2", updatedBy: ADMIN }));
  });
  it("nobody deletes", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("departments/eye").set(department(ADMIN));
    });
    await assertFails(asAdmin().doc("departments/eye").delete());
    await assertFails(asAdmin().doc("settings/general").delete());
  });
});

describe("other collections", () => {
  it("denied even for admin", async () => {
    await assertFails(asAdmin().doc("inventoryItems/i1").get());
    await assertFails(asAdmin().doc("inventoryItems/i1").set({ name: "x" }));
    await assertFails(asAlice().collection("inventoryItems").get());
    await assertFails(asAnon().doc("settings/general").get());
  });
});

// ----- Phase 3: families, patients, counters (§4.7–§4.9) -------------------

const family = (by: string) => ({
  phone: "03001234567",
  headName: "Khan",
  address: "",
  patientCount: 0,
  duplicatePhone: false,
  branchId: "main",
  createdAt: new Date(),
  createdAtLocal: new Date(),
  createdBy: by,
  updatedAt: new Date(),
  updatedBy: by,
});

const patient = (by: string) => ({
  patientNo: null,
  tempNo: "T-AAAAA",
  familyId: "f1",
  name: "Ali Khan",
  gender: "male",
  dateOfBirth: "1986-01-01",
  dobApproximate: true,
  personalPhone: null,
  phones: ["03001234567"],
  address: "",
  notes: "",
  searchKeys: ["a", "al", "ali"],
  visitCount: 0,
  lastVisitAt: null,
  lastDoctorId: null,
  deleted: false,
  branchId: "main",
  createdAt: new Date(),
  createdAtLocal: new Date(),
  createdBy: by,
  updatedAt: new Date(),
  updatedBy: by,
});

describe("families and patients read", () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("families/f1").set(family(ADMIN));
      await ctx.firestore().doc("patients/p1").set(patient(ADMIN));
    });
  });
  it("any signed-in role reads and lists", async () => {
    await assertSucceeds(asAlice().doc("families/f1").get());
    await assertSucceeds(asDoctor().doc("patients/p1").get());
    await assertSucceeds(asAdmin().collection("patients").get());
    await assertSucceeds(
      asAlice().collection("patients").where("phones", "array-contains", "03001234567").get()
    );
  });
  it("anonymous denied", async () => {
    await assertFails(asAnon().doc("families/f1").get());
    await assertFails(asAnon().collection("patients").get());
  });
});

describe("families and patients write", () => {
  it("reception and admin create with createdBy = self", async () => {
    await assertSucceeds(asAlice().doc("families/f1").set(family(ALICE)));
    await assertSucceeds(asAlice().doc("patients/p1").set(patient(ALICE)));
    await assertSucceeds(asAdmin().doc("families/f2").set(family(ADMIN)));
    await assertSucceeds(asAdmin().doc("patients/p2").set(patient(ADMIN)));
  });
  it("doctor, anonymous and wrong createdBy denied", async () => {
    await assertFails(asDoctor().doc("families/f1").set(family("doctor-uid")));
    await assertFails(asDoctor().doc("patients/p1").set(patient("doctor-uid")));
    await assertFails(asAnon().doc("patients/p1").set(patient("anon")));
    await assertFails(asAlice().doc("families/f1").set(family(BOB)));
    await assertFails(asAlice().doc("patients/p1").set(patient(BOB)));
  });
  it("shape checks on create", async () => {
    await assertFails(asAlice().doc("families/f1").set({ ...family(ALICE), phone: "" }));
    await assertFails(asAlice().doc("families/f1").set({ ...family(ALICE), headName: "" }));
    await assertFails(asAlice().doc("families/f1").set({ ...family(ALICE), duplicatePhone: true }));
    await assertFails(asAlice().doc("families/f1").set({ ...family(ALICE), branchId: "other" }));
    await assertFails(asAlice().doc("patients/p1").set({ ...patient(ALICE), name: "" }));
    await assertFails(asAlice().doc("patients/p1").set({ ...patient(ALICE), familyId: "" }));
    await assertFails(asAlice().doc("patients/p1").set({ ...patient(ALICE), tempNo: "" }));
    await assertFails(asAlice().doc("patients/p1").set({ ...patient(ALICE), gender: "x" }));
    await assertFails(asAlice().doc("patients/p1").set({ ...patient(ALICE), phones: "0300" }));
    await assertFails(asAlice().doc("patients/p1").set({ ...patient(ALICE), deleted: "no" }));
    await assertFails(asAlice().doc("patients/p1").set({ ...patient(ALICE), branchId: "other" }));
    // The number is assigned by the function, never by the client.
    await assertFails(asAlice().doc("patients/p1").set({ ...patient(ALICE), patientNo: "26-00001" }));
  });
  it("reception updates with updatedBy = self; functions-only fields locked", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("families/f1").set(family(ADMIN));
      await ctx.firestore().doc("patients/p1").set({ ...patient(ADMIN), patientNo: "26-00001" });
    });
    await assertSucceeds(
      asAlice().doc("patients/p1").update({ name: "Ali Raza", searchKeys: ["ali"], updatedBy: ALICE })
    );
    await assertSucceeds(
      asAlice().doc("patients/p1").update({ familyId: "f2", phones: ["03009999999"], updatedBy: ALICE })
    );
    await assertSucceeds(
      asAlice().doc("patients/p1").update({ deleted: true, deleteReason: "Duplicate", updatedBy: ALICE })
    );
    await assertSucceeds(
      asAlice().doc("families/f1").update({ phone: "03009999999", patientCount: 3, updatedBy: ALICE })
    );
    await assertFails(asAlice().doc("patients/p1").update({ name: "X", updatedBy: BOB }));
    await assertFails(asAlice().doc("patients/p1").update({ patientNo: "26-00009", updatedBy: ALICE }));
    await assertFails(asAlice().doc("patients/p1").update({ tempNo: "T-ZZZZZ", updatedBy: ALICE }));
    await assertFails(asAlice().doc("patients/p1").update({ createdBy: ALICE, updatedBy: ALICE }));
    await assertFails(asAlice().doc("patients/p1").update({ branchId: "b2", updatedBy: ALICE }));
    await assertFails(asAlice().doc("patients/p1").update({ name: "", updatedBy: ALICE }));
    await assertFails(asAlice().doc("families/f1").update({ duplicatePhone: true, updatedBy: ALICE }));
    await assertFails(asAlice().doc("families/f1").update({ phone: "", updatedBy: ALICE }));
    await assertFails(asDoctor().doc("patients/p1").update({ name: "X", updatedBy: "doctor-uid" }));
  });
  it("nobody deletes", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("families/f1").set(family(ADMIN));
      await ctx.firestore().doc("patients/p1").set(patient(ADMIN));
    });
    await assertFails(asAdmin().doc("families/f1").delete());
    await assertFails(asAdmin().doc("patients/p1").delete());
  });
});

describe("counters", () => {
  it("nobody reads or writes, not even admin", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("counters/patients_26").set({ value: 3 });
    });
    await assertFails(asAdmin().doc("counters/patients_26").get());
    await assertFails(asAdmin().doc("counters/patients_26").set({ value: 4 }));
    await assertFails(asAlice().doc("counters/patients_26").update({ value: 4 }));
  });
});

// ----- Phase 4: visits (§4.11) ---------------------------------------------

const visit = (by: string) => ({
  patientId: "p1",
  patientName: "Ali Khan",
  patientNo: "26-00001",
  phone: "03001234567",
  familyId: "f1",
  doctorId: "d1",
  doctorName: "Dr Sara",
  departmentId: "eye",
  departmentCode: "E",
  visitTypeId: "eye-checkup",
  visitTypeName: "Checkup",
  isOperation: false,
  isFollowUp: false,
  token: 1,
  tokenLabel: "E-1",
  date: "2026-11-04",
  isFirstVisit: true,
  fee: 1500,
  discountAmount: 0,
  discountReason: "",
  netAmount: 1500,
  paymentMethod: "cash",
  paymentRef: "",
  status: "waiting",
  startedAt: null,
  completedAt: null,
  appointmentId: null,
  operationId: null,
  saleId: null,
  hasPrescription: false,
  receiptCopies: 1,
  deleted: false,
  deletedAt: null,
  deletedBy: null,
  deleteReason: null,
  editReason: null,
  branchId: "main",
  createdAt: new Date(),
  createdAtLocal: new Date(),
  createdBy: by,
  updatedAt: new Date(),
  updatedBy: by,
});

describe("visits read", () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("visits/v1").set(visit(ADMIN));
    });
  });
  it("any signed-in role reads and queries by day, patient and doctor", async () => {
    await assertSucceeds(asAlice().doc("visits/v1").get());
    await assertSucceeds(asDoctor().doc("visits/v1").get());
    await assertSucceeds(asAlice().collection("visits").where("date", "==", "2026-11-04").get());
    await assertSucceeds(asAdmin().collection("visits").where("patientId", "==", "p1").get());
    await assertSucceeds(
      asDoctor().collection("visits").where("doctorId", "==", "d1").where("date", "==", "2026-11-04").get()
    );
  });
  it("anonymous denied", async () => {
    await assertFails(asAnon().doc("visits/v1").get());
    await assertFails(asAnon().collection("visits").get());
  });
});

describe("visits create", () => {
  it("reception and admin create with createdBy = self", async () => {
    await assertSucceeds(asAlice().doc("visits/v1").set(visit(ALICE)));
    await assertSucceeds(asAdmin().doc("visits/v2").set(visit(ADMIN)));
  });
  it("a discount needs a reason and a consistent net", async () => {
    await assertSucceeds(
      asAlice().doc("visits/v1").set({
        ...visit(ALICE),
        discountAmount: 200,
        discountReason: "Old patient",
        netAmount: 1300,
      })
    );
    await assertFails(
      asAlice().doc("visits/v2").set({ ...visit(ALICE), discountAmount: 200, netAmount: 1300 })
    );
    await assertFails(
      asAlice().doc("visits/v3").set({
        ...visit(ALICE),
        discountAmount: 200,
        discountReason: "Old patient",
        netAmount: 1500,
      })
    );
    await assertFails(
      asAlice().doc("visits/v4").set({
        ...visit(ALICE),
        discountAmount: 1600,
        discountReason: "x",
        netAmount: 0,
      })
    );
    await assertFails(asAlice().doc("visits/v5").set({ ...visit(ALICE), netAmount: 1400 }));
  });
  it("shape checks on create", async () => {
    await assertFails(asAlice().doc("visits/v1").set({ ...visit(ALICE), patientId: "" }));
    await assertFails(asAlice().doc("visits/v1").set({ ...visit(ALICE), patientName: "" }));
    await assertFails(asAlice().doc("visits/v1").set({ ...visit(ALICE), doctorId: "" }));
    await assertFails(asAlice().doc("visits/v1").set({ ...visit(ALICE), visitTypeId: "" }));
    await assertFails(asAlice().doc("visits/v1").set({ ...visit(ALICE), tokenLabel: "" }));
    await assertFails(asAlice().doc("visits/v1").set({ ...visit(ALICE), token: 0 }));
    await assertFails(asAlice().doc("visits/v1").set({ ...visit(ALICE), date: "" }));
    await assertFails(asAlice().doc("visits/v1").set({ ...visit(ALICE), fee: -1, netAmount: -1 }));
    await assertFails(asAlice().doc("visits/v1").set({ ...visit(ALICE), paymentMethod: "cheque" }));
    await assertFails(asAlice().doc("visits/v1").set({ ...visit(ALICE), status: "completed" }));
    await assertFails(asAlice().doc("visits/v1").set({ ...visit(ALICE), deleted: true }));
    await assertFails(asAlice().doc("visits/v1").set({ ...visit(ALICE), receiptCopies: 9 }));
    await assertFails(asAlice().doc("visits/v1").set({ ...visit(ALICE), branchId: "other" }));
  });
  it("doctor, anonymous and wrong createdBy denied", async () => {
    await assertFails(asDoctor().doc("visits/v1").set(visit("doctor-uid")));
    await assertFails(asAnon().doc("visits/v1").set(visit("anon")));
    await assertFails(asAlice().doc("visits/v1").set(visit(BOB)));
  });
});

describe("visits update", () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("visits/v1").set(visit(ALICE));
      await ctx.firestore().doc("visits/other").set({ ...visit(ALICE), doctorId: "d2" });
    });
  });
  it("reception moves the status and nothing else", async () => {
    await assertSucceeds(
      asAlice().doc("visits/v1").update({ status: "inProgress", startedAt: new Date(), updatedBy: ALICE })
    );
    await assertSucceeds(
      asAlice().doc("visits/v1").update({ status: "completed", completedAt: new Date(), updatedBy: ALICE })
    );
    await assertFails(asAlice().doc("visits/v1").update({ status: "bogus", updatedBy: ALICE }));
    await assertFails(asAlice().doc("visits/v1").update({ fee: 100, netAmount: 100, updatedBy: ALICE }));
    await assertFails(asAlice().doc("visits/v1").update({ discountAmount: 100, updatedBy: ALICE }));
    await assertFails(asAlice().doc("visits/v1").update({ hasPrescription: true, updatedBy: ALICE }));
    await assertFails(asAlice().doc("visits/v1").update({ deleted: true, updatedBy: ALICE }));
    await assertFails(asAlice().doc("visits/v1").update({ status: "completed", updatedBy: BOB }));
  });
  it("the assigned doctor moves status and hasPrescription on own visits only", async () => {
    await assertSucceeds(
      asDoctor().doc("visits/v1").update({ status: "inProgress", startedAt: new Date(), updatedBy: "doctor-uid" })
    );
    await assertSucceeds(asDoctor().doc("visits/v1").update({ hasPrescription: true, updatedBy: "doctor-uid" }));
    await assertFails(asDoctor().doc("visits/v1").update({ fee: 100, netAmount: 100, updatedBy: "doctor-uid" }));
    await assertFails(
      asDoctor().doc("visits/other").update({ status: "inProgress", updatedBy: "doctor-uid" })
    );
  });
  it("admin edits any business field with updatedBy = self; stamps locked", async () => {
    await assertSucceeds(
      asAdmin().doc("visits/v1").update({
        fee: 1000,
        discountAmount: 100,
        discountReason: "Correction",
        netAmount: 900,
        editReason: "Wrong fee typed",
        updatedBy: ADMIN,
      })
    );
    // Soft delete needs a reason; checked before the valid delete below
    // because the merged document would otherwise already carry one.
    await assertFails(asAdmin().doc("visits/v1").update({ deleted: true, updatedBy: ADMIN }));
    await assertSucceeds(
      asAdmin().doc("visits/v1").update({ deleted: true, deleteReason: "Duplicate", deletedBy: ADMIN, updatedBy: ADMIN })
    );
    await assertFails(asAdmin().doc("visits/v1").update({ fee: 1000, netAmount: 1000, updatedBy: ALICE }));
    await assertFails(asAdmin().doc("visits/v1").update({ createdBy: ADMIN, updatedBy: ADMIN }));
    await assertFails(asAdmin().doc("visits/v1").update({ branchId: "b2", updatedBy: ADMIN }));
    await assertFails(
      asAdmin().doc("visits/v1").update({ discountAmount: 100, netAmount: 1400, updatedBy: ADMIN })
    );
  });
  it("nobody deletes", async () => {
    await assertFails(asAdmin().doc("visits/v1").delete());
    await assertFails(asAlice().doc("visits/v1").delete());
  });
});

// ----- Phase 5A: prescriptions (§4.12), appointments (§4.10) ---------------

const DOCTOR = "doctor-uid";
const doctor2Token = { roles: ["doctor"], doctorId: "d2", branchIds: ["main"] };
const asDoctor2 = () => env.authenticatedContext("doctor2-uid", doctor2Token).firestore();

/** Today's clinic day in Karachi (UTC+5), the only day a prescription may be edited. */
function karachiToday(offsetDays = 0): string {
  const d = new Date(Date.now() + 5 * 3600_000 + offsetDays * 86_400_000);
  return d.toISOString().slice(0, 10);
}

const prescription = (by: string, date: string, extra: Record<string, unknown> = {}) => ({
  visitId: "v1",
  patientId: "p1",
  patientName: "Ali Khan",
  patientNo: "26-00001",
  doctorId: "d1",
  doctorName: "Dr Sara",
  departmentId: "eye",
  date,
  eye: {
    od: { sph: "-1.25", cyl: "", axis: "", add: "", va: "6/6" },
    os: { sph: "", cyl: "", axis: "", add: "", va: "" },
  },
  homeo: [],
  diagnosis: "Myopia",
  advice: "",
  followUpDate: null,
  followUpAppointmentId: null,
  branchId: "main",
  createdAt: new Date(),
  createdAtLocal: new Date(),
  createdBy: by,
  updatedAt: new Date(),
  updatedBy: by,
  ...extra,
});

describe("prescriptions", () => {
  const today = karachiToday();
  const yesterday = karachiToday(-1);
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.doc("visits/v1").set({ ...visit(ALICE), date: today, status: "inProgress" });
      await db.doc("visits/v2").set({ ...visit(ALICE), doctorId: "d2", date: today });
      await db.doc("visits/old").set({ ...visit(ALICE), date: yesterday, status: "completed" });
      await db.doc("prescriptions/old").set(prescription(DOCTOR, yesterday, { visitId: "old" }));
    });
  });
  it("any signed-in role reads; anonymous denied", async () => {
    await assertSucceeds(asAlice().doc("prescriptions/old").get());
    await assertSucceeds(asDoctor2().collection("prescriptions").where("patientId", "==", "p1").get());
    await assertFails(asAnon().doc("prescriptions/old").get());
  });
  it("the visit's doctor creates under the visit id with the visit's date", async () => {
    await assertSucceeds(asDoctor().doc("prescriptions/v1").set(prescription(DOCTOR, today)));
  });
  it("another doctor, reception, admin and anonymous cannot create", async () => {
    await assertFails(asDoctor2().doc("prescriptions/v1").set({ ...prescription("doctor2-uid", today), doctorId: "d2" }));
    await assertFails(asDoctor2().doc("prescriptions/v1").set(prescription("doctor2-uid", today)));
    await assertFails(asAlice().doc("prescriptions/v1").set(prescription(ALICE, today)));
    await assertFails(asAdmin().doc("prescriptions/v1").set(prescription(ADMIN, today)));
    await assertFails(asAnon().doc("prescriptions/v1").set(prescription("anon", today)));
  });
  it("shape: id must match visitId, date the visit, doctorId the claim, createdBy the caller", async () => {
    await assertFails(asDoctor().doc("prescriptions/v1").set(prescription(DOCTOR, today, { visitId: "v2" })));
    await assertFails(asDoctor().doc("prescriptions/v1").set(prescription(DOCTOR, yesterday)));
    await assertFails(asDoctor().doc("prescriptions/v1").set(prescription(DOCTOR, today, { doctorId: "d2" })));
    await assertFails(asDoctor().doc("prescriptions/v1").set(prescription(ALICE, today)));
    await assertFails(asDoctor().doc("prescriptions/v1").set(prescription(DOCTOR, today, { branchId: "other" })));
    await assertFails(asDoctor().doc("prescriptions/missing").set(prescription(DOCTOR, today, { visitId: "missing" })));
  });
  it("own doctor edits today's prescription; identity fields locked", async () => {
    await assertSucceeds(asDoctor().doc("prescriptions/v1").set(prescription(DOCTOR, today)));
    await assertSucceeds(
      asDoctor().doc("prescriptions/v1").update({ diagnosis: "Astigmatism", followUpDate: karachiToday(7), updatedBy: DOCTOR })
    );
    await assertFails(asDoctor().doc("prescriptions/v1").update({ doctorId: "d2", updatedBy: DOCTOR }));
    await assertFails(asDoctor().doc("prescriptions/v1").update({ date: yesterday, updatedBy: DOCTOR }));
    await assertFails(asDoctor().doc("prescriptions/v1").update({ visitId: "v2", updatedBy: DOCTOR }));
    await assertFails(asDoctor().doc("prescriptions/v1").update({ createdBy: ALICE, updatedBy: DOCTOR }));
    await assertFails(asDoctor().doc("prescriptions/v1").update({ diagnosis: "x", updatedBy: ALICE }));
    await assertFails(asDoctor2().doc("prescriptions/v1").update({ diagnosis: "x", updatedBy: "doctor2-uid" }));
    await assertFails(asAdmin().doc("prescriptions/v1").update({ diagnosis: "x", updatedBy: ADMIN }));
  });
  it("yesterday's prescription is read-only even for its doctor", async () => {
    await assertFails(asDoctor().doc("prescriptions/old").update({ diagnosis: "x", updatedBy: DOCTOR }));
  });
  it("nobody deletes", async () => {
    await assertFails(asDoctor().doc("prescriptions/old").delete());
    await assertFails(asAdmin().doc("prescriptions/old").delete());
  });
});

const appointment = (by: string, extra: Record<string, unknown> = {}) => ({
  patientId: "p1",
  patientName: "Ali Khan",
  patientNo: "26-00001",
  phone: "03001234567",
  doctorId: "d1",
  doctorName: "Dr Sara",
  departmentId: "eye",
  date: "2026-11-12",
  time: "",
  source: "followUp",
  status: "booked",
  operationId: null,
  prescriptionId: "v1",
  visitId: null,
  notes: "",
  reminderSentAt: null,
  reminderSentBy: null,
  branchId: "main",
  createdAt: new Date(),
  createdAtLocal: new Date(),
  createdBy: by,
  updatedAt: new Date(),
  updatedBy: by,
  ...extra,
});

describe("appointments", () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("appointments/a1").set(appointment(DOCTOR));
    });
  });
  it("any signed-in role reads and queries; anonymous denied", async () => {
    await assertSucceeds(asAlice().doc("appointments/a1").get());
    await assertSucceeds(asDoctor2().collection("appointments").where("date", "==", "2026-11-12").get());
    await assertFails(asAnon().doc("appointments/a1").get());
  });
  it("reception, doctor and admin create with createdBy = self", async () => {
    await assertSucceeds(asAlice().doc("appointments/a2").set(appointment(ALICE, { source: "manual", time: "10:30" })));
    await assertSucceeds(asDoctor().doc("appointments/a3").set(appointment(DOCTOR)));
    await assertSucceeds(asAdmin().doc("appointments/a4").set(appointment(ADMIN)));
    await assertFails(asAlice().doc("appointments/a5").set(appointment(BOB)));
    await assertFails(asAnon().doc("appointments/a6").set(appointment("anon")));
    await assertFails(asNoClaims().doc("appointments/a7").set(appointment("noclaims-uid")));
  });
  it("shape checks on create", async () => {
    await assertFails(asDoctor().doc("appointments/x").set(appointment(DOCTOR, { patientId: "" })));
    await assertFails(asDoctor().doc("appointments/x").set(appointment(DOCTOR, { patientName: "" })));
    await assertFails(asDoctor().doc("appointments/x").set(appointment(DOCTOR, { doctorId: "" })));
    await assertFails(asDoctor().doc("appointments/x").set(appointment(DOCTOR, { date: "" })));
    await assertFails(asDoctor().doc("appointments/x").set(appointment(DOCTOR, { status: "done" })));
    await assertFails(asDoctor().doc("appointments/x").set(appointment(DOCTOR, { source: "phone" })));
    await assertFails(asDoctor().doc("appointments/x").set(appointment(DOCTOR, { branchId: "other" })));
  });
  it("updates by the three roles with updatedBy = self; stamps locked", async () => {
    await assertSucceeds(asDoctor().doc("appointments/a1").update({ date: "2026-11-19", updatedBy: DOCTOR }));
    await assertSucceeds(asAlice().doc("appointments/a1").update({ status: "cancelled", updatedBy: ALICE }));
    await assertSucceeds(asAdmin().doc("appointments/a1").update({ notes: "Call first", updatedBy: ADMIN }));
    await assertFails(asDoctor().doc("appointments/a1").update({ status: "bogus", updatedBy: DOCTOR }));
    await assertFails(asDoctor().doc("appointments/a1").update({ date: "2026-11-19", updatedBy: ALICE }));
    await assertFails(asDoctor().doc("appointments/a1").update({ createdBy: ALICE, updatedBy: DOCTOR }));
    await assertFails(asDoctor().doc("appointments/a1").update({ branchId: "b2", updatedBy: DOCTOR }));
    await assertFails(asNoClaims().doc("appointments/a1").update({ notes: "x", updatedBy: "noclaims-uid" }));
  });
  it("nobody deletes", async () => {
    await assertFails(asAdmin().doc("appointments/a1").delete());
    await assertFails(asDoctor().doc("appointments/a1").delete());
  });
});

// ----- Phase 5B: reports (§4.13), operations (§4.14), visit-type defaults -----

const report = (by: string, extra: Record<string, unknown> = {}) => ({
  patientId: "p1",
  patientName: "Ali Khan",
  visitId: null,
  title: "Blood test",
  fileName: "scan.pdf",
  storagePath: "patients/p1/reports/r1.pdf",
  downloadUrl: "https://example.test/r1.pdf",
  mimeType: "application/pdf",
  sizeBytes: 2048,
  uploadedBy: by,
  uploadedAt: new Date(),
  deleted: false,
  deletedAt: null,
  deletedBy: null,
  deleteReason: null,
  branchId: "main",
  createdAt: new Date(),
  createdAtLocal: new Date(),
  createdBy: by,
  updatedAt: new Date(),
  updatedBy: by,
  ...extra,
});

describe("reports", () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("reports/r1").set(report(ALICE));
    });
  });
  it("any signed-in role reads and queries by patient; anonymous denied", async () => {
    await assertSucceeds(asDoctor().doc("reports/r1").get());
    await assertSucceeds(asDoctor().collection("reports").where("patientId", "==", "p1").get());
    await assertFails(asAnon().doc("reports/r1").get());
  });
  it("reception and admin create with createdBy = self and a valid file shape", async () => {
    await assertSucceeds(asAlice().doc("reports/r2").set(report(ALICE)));
    await assertSucceeds(asAdmin().doc("reports/r3").set(report(ADMIN, { mimeType: "image/jpeg", visitId: "v1" })));
    await assertFails(asDoctor().doc("reports/r4").set(report(DOCTOR)));
    await assertFails(asAnon().doc("reports/r4").set(report("anon")));
    await assertFails(asAlice().doc("reports/r4").set(report(BOB)));
    await assertFails(asAlice().doc("reports/r4").set(report(ALICE, { title: "" })));
    await assertFails(asAlice().doc("reports/r4").set(report(ALICE, { patientId: "" })));
    await assertFails(asAlice().doc("reports/r4").set(report(ALICE, { storagePath: "" })));
    await assertFails(asAlice().doc("reports/r4").set(report(ALICE, { mimeType: "image/gif" })));
    await assertFails(asAlice().doc("reports/r4").set(report(ALICE, { sizeBytes: 10 * 1024 * 1024 + 1 })));
    await assertFails(asAlice().doc("reports/r4").set(report(ALICE, { deleted: true })));
    await assertFails(asAlice().doc("reports/r4").set(report(ALICE, { branchId: "other" })));
  });
  it("reception renames or soft-deletes with a reason; file fields locked; doctor denied", async () => {
    await assertSucceeds(asAlice().doc("reports/r1").update({ title: "CBC", updatedBy: ALICE }));
    await assertFails(asAlice().doc("reports/r1").update({ deleted: true, updatedBy: ALICE }));
    await assertSucceeds(
      asAdmin().doc("reports/r1").update({ deleted: true, deleteReason: "Wrong patient", deletedBy: ADMIN, deletedAt: new Date(), updatedBy: ADMIN })
    );
    await assertFails(asAlice().doc("reports/r1").update({ storagePath: "x", updatedBy: ALICE }));
    await assertFails(asAlice().doc("reports/r1").update({ downloadUrl: "x", updatedBy: ALICE }));
    await assertFails(asAlice().doc("reports/r1").update({ patientId: "p2", updatedBy: ALICE }));
    await assertFails(asAlice().doc("reports/r1").update({ title: "x", updatedBy: BOB }));
    await assertFails(asDoctor().doc("reports/r1").update({ title: "x", updatedBy: DOCTOR }));
  });
  it("nobody deletes", async () => {
    await assertFails(asAdmin().doc("reports/r1").delete());
    await assertFails(asAlice().doc("reports/r1").delete());
  });
});

const operation = (by: string, extra: Record<string, unknown> = {}) => ({
  patientId: "p1",
  patientName: "Ali Khan",
  patientNo: "26-00001",
  phone: "03001234567",
  visitId: "v1",
  visitTypeId: "cataract",
  visitTypeName: "Cataract Surgery",
  surgeonDoctorId: "d1",
  surgeonName: "Dr Sara",
  departmentId: "eye",
  scheduledById: "d1",
  scheduledDate: "2026-11-10",
  status: "scheduled",
  checklist: [{ id: "c1", label: "Blood sugar", done: false, doneBy: null, doneAt: null }],
  checklistComplete: false,
  checklistOverrideReason: null,
  postOpDays: [1, 7, 30],
  surgeryAppointmentId: "a0",
  followUpAppointmentIds: ["a1", "a2", "a3"],
  notes: "",
  doneAt: null,
  doneBy: null,
  cancelReason: null,
  branchId: "main",
  createdAt: new Date(),
  createdAtLocal: new Date(),
  createdBy: by,
  updatedAt: new Date(),
  updatedBy: by,
  ...extra,
});

describe("operations", () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("operations/o1").set(operation(DOCTOR));
    });
  });
  it("any signed-in role reads and queries by surgeon and patient; anonymous denied", async () => {
    await assertSucceeds(asAlice().doc("operations/o1").get());
    await assertSucceeds(asDoctor().collection("operations").where("surgeonDoctorId", "==", "d1").get());
    await assertSucceeds(asAdmin().collection("operations").where("patientId", "==", "p1").get());
    await assertFails(asAnon().doc("operations/o1").get());
  });
  it("doctor and admin create a scheduled operation with createdBy = self", async () => {
    await assertSucceeds(asDoctor().doc("operations/o2").set(operation(DOCTOR)));
    await assertSucceeds(asAdmin().doc("operations/o3").set(operation(ADMIN)));
    await assertFails(asAlice().doc("operations/o4").set(operation(ALICE)));
    await assertFails(asAnon().doc("operations/o4").set(operation("anon")));
    await assertFails(asDoctor().doc("operations/o4").set(operation(ALICE)));
    await assertFails(asDoctor().doc("operations/o4").set(operation(DOCTOR, { status: "done" })));
    await assertFails(asDoctor().doc("operations/o4").set(operation(DOCTOR, { patientId: "" })));
    await assertFails(asDoctor().doc("operations/o4").set(operation(DOCTOR, { surgeonDoctorId: "" })));
    await assertFails(asDoctor().doc("operations/o4").set(operation(DOCTOR, { scheduledDate: "" })));
    await assertFails(asDoctor().doc("operations/o4").set(operation(DOCTOR, { checklist: "none" })));
    await assertFails(asDoctor().doc("operations/o4").set(operation(DOCTOR, { branchId: "other" })));
  });
  it("doctor and admin update; done needs the flag or an override; cancel needs a reason", async () => {
    await assertSucceeds(
      asDoctor().doc("operations/o1").update({
        checklist: [{ id: "c1", label: "Blood sugar", done: true, doneBy: "Dr Sara", doneAt: new Date() }],
        checklistComplete: true,
        updatedBy: DOCTOR,
      })
    );
    await assertSucceeds(asDoctor().doc("operations/o1").update({ scheduledDate: "2026-11-12", postOpDays: [1, 7], updatedBy: DOCTOR }));
    await assertSucceeds(asDoctor().doc("operations/o1").update({ status: "done", doneBy: "Dr Sara", doneAt: new Date(), updatedBy: DOCTOR }));
    await assertFails(asDoctor().doc("operations/o1").update({ status: "bogus", updatedBy: DOCTOR }));
    await assertFails(asDoctor().doc("operations/o1").update({ createdBy: ADMIN, updatedBy: DOCTOR }));
    await assertFails(asDoctor().doc("operations/o1").update({ branchId: "b2", updatedBy: DOCTOR }));
    await assertFails(asDoctor().doc("operations/o1").update({ notes: "x", updatedBy: ALICE }));
    await assertSucceeds(asAdmin().doc("operations/o1").update({ notes: "Admin note", updatedBy: ADMIN }));
  });
  it("done without a complete checklist needs an override reason", async () => {
    await assertFails(asDoctor().doc("operations/o1").update({ status: "done", doneBy: "Dr Sara", doneAt: new Date(), updatedBy: DOCTOR }));
    await assertFails(asDoctor().doc("operations/o1").update({ status: "done", checklistOverrideReason: "Seen on paper", updatedBy: DOCTOR }));
    await assertSucceeds(
      asDoctor().doc("operations/o1").update({ status: "done", doneBy: "Dr Sara", doneAt: new Date(), checklistOverrideReason: "Seen on paper", updatedBy: DOCTOR })
    );
  });
  it("cancel needs a reason", async () => {
    await assertFails(asDoctor().doc("operations/o1").update({ status: "cancelled", updatedBy: DOCTOR }));
    await assertSucceeds(asDoctor().doc("operations/o1").update({ status: "cancelled", cancelReason: "Unfit", updatedBy: DOCTOR }));
  });
  it("reception may change only the post-op days and their appointment ids", async () => {
    await assertSucceeds(asAlice().doc("operations/o1").update({ postOpDays: [1, 14], followUpAppointmentIds: ["x", "y"], updatedBy: ALICE }));
    await assertFails(asAlice().doc("operations/o1").update({ scheduledDate: "2026-12-01", updatedBy: ALICE }));
    await assertFails(asAlice().doc("operations/o1").update({ status: "done", updatedBy: ALICE }));
    await assertFails(asAlice().doc("operations/o1").update({ notes: "x", updatedBy: ALICE }));
    await assertFails(asAlice().doc("operations/o1").update({ postOpDays: [1], updatedBy: BOB }));
  });
  it("nobody deletes", async () => {
    await assertFails(asAdmin().doc("operations/o1").delete());
    await assertFails(asDoctor().doc("operations/o1").delete());
  });
});

describe("visit type defaults by doctors", () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.doc("visitTypes/cataract").set({ ...visitType(ADMIN), name: "Cataract Surgery", isOperation: true });
      await db.doc("visitTypes/checkup").set(visitType(ADMIN));
    });
  });
  it("a doctor changes the checklist and post-op days of an operation type", async () => {
    await assertSucceeds(
      asDoctor().doc("visitTypes/cataract").update({
        defaultPreOpChecklist: [{ id: "c9", label: "Fasting" }],
        defaultPostOpDays: [1, 14],
        updatedBy: DOCTOR,
      })
    );
  });
  it("a doctor cannot touch other fields, a non-operation type, or write with the wrong updatedBy", async () => {
    await assertFails(asDoctor().doc("visitTypes/cataract").update({ name: "x", updatedBy: DOCTOR }));
    await assertFails(asDoctor().doc("visitTypes/cataract").update({ active: false, updatedBy: DOCTOR }));
    await assertFails(asDoctor().doc("visitTypes/checkup").update({ defaultPostOpDays: [1], updatedBy: DOCTOR }));
    await assertFails(asDoctor().doc("visitTypes/cataract").update({ defaultPostOpDays: [1], updatedBy: ALICE }));
    await assertFails(asAlice().doc("visitTypes/cataract").update({ defaultPostOpDays: [1], updatedBy: ALICE }));
    await assertFails(asDoctor().doc("visitTypes/new").set({ ...visitType(DOCTOR), isOperation: true }));
  });
});

describe("appointments from operations", () => {
  it("source operation is accepted", async () => {
    await assertSucceeds(
      asDoctor().doc("appointments/op-day").set(appointment(DOCTOR, { source: "operation", operationId: "o1", prescriptionId: null }))
    );
  });
});

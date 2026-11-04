// Firestore rules allow/deny matrix for Phases 1 and 2 (FIREBASE_ARCHITECTURE.md §6).
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
    await assertFails(asAdmin().doc("visits/v1").get());
    await assertFails(asAdmin().doc("visits/v1").set({ name: "x" }));
    await assertFails(asAlice().collection("visits").get());
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

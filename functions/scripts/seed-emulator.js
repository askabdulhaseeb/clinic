#!/usr/bin/env node
// Seeds the local Auth + Firestore emulators with the accounts and master
// data the Flutter integration tests expect. Run while the emulators are up:
//   node scripts/seed-emulator.js
// Never points at production: it refuses to run without the emulator hosts.
//
// Seeded: four accounts (admin, first-login reception, plain reception,
// multi-role), the Eye and Homeopathy departments with their visit types,
// one doctor record linked to the multi-role account, and one family with
// two patients (Phase 3). `settings/general` is deliberately NOT seeded so
// the integration test can exercise the first-run setup screen; the admin
// setup flow creates it.
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= "127.0.0.1:9099";
process.env.FIRESTORE_EMULATOR_HOST ??= "127.0.0.1:8080";
process.env.GCLOUD_PROJECT ??= "ramzan-clinic-web";

const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp({ projectId: process.env.GCLOUD_PROJECT });
const auth = getAuth();
const db = getFirestore();

const SEED = [
  {
    uid: "seed-admin",
    email: "admin@clinic.test",
    password: "Admin12345",
    displayName: "Seed Admin",
    roles: ["admin"],
    doctorId: null,
    mustChangePassword: false,
  },
  {
    uid: "seed-fresh",
    email: "fresh@clinic.test",
    password: "Temp12345",
    displayName: "Fresh Reception",
    roles: ["reception"],
    doctorId: null,
    mustChangePassword: true,
  },
  {
    uid: "seed-reception",
    email: "reception@clinic.test",
    password: "Reception12345",
    displayName: "Seed Reception",
    roles: ["reception"],
    doctorId: null,
    mustChangePassword: false,
  },
  {
    uid: "seed-multi",
    email: "multi@clinic.test",
    password: "Multi12345",
    displayName: "Multi Role",
    roles: ["reception", "doctor", "admin"],
    doctorId: "seed-doctor",
    mustChangePassword: false,
  },
];

async function upsert(u) {
  try {
    await auth.getUser(u.uid);
    await auth.updateUser(u.uid, {
      email: u.email,
      password: u.password,
      displayName: u.displayName,
      disabled: false,
    });
  } catch {
    await auth.createUser({
      uid: u.uid,
      email: u.email,
      password: u.password,
      displayName: u.displayName,
    });
  }
  await auth.setCustomUserClaims(u.uid, {
    roles: u.roles,
    doctorId: u.doctorId,
    branchIds: ["main"],
  });
  await db.collection("users").doc(u.uid).set({
    email: u.email,
    displayName: u.displayName,
    roles: u.roles,
    doctorId: u.doctorId,
    active: true,
    branchIds: ["main"],
    mustChangePassword: u.mustChangePassword,
    createdAt: FieldValue.serverTimestamp(),
    createdBy: "seed",
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: "seed",
  });
  console.log(`seeded ${u.email} (${u.roles.join(",")})`);
}

const STAMP = (by) => ({
  createdAt: FieldValue.serverTimestamp(),
  createdBy: by,
  updatedAt: FieldValue.serverTimestamp(),
  updatedBy: by,
});

// Fixed IDs shared with the app's initial setup (lib/features/settings).
const DEPARTMENTS = [
  { id: "eye", name: "Eye", code: "E", sortOrder: 1 },
  { id: "homeo", name: "Homeopathy", code: "H", sortOrder: 2 },
];
const VISIT_TYPES = [
  { id: "eye-checkup", departmentId: "eye", name: "Checkup", isFollowUp: false, sortOrder: 1 },
  { id: "eye-follow-up", departmentId: "eye", name: "Follow-up", isFollowUp: true, sortOrder: 2 },
  { id: "eye-eye-test", departmentId: "eye", name: "Eye Test", isFollowUp: false, sortOrder: 3 },
  { id: "homeo-checkup", departmentId: "homeo", name: "Checkup", isFollowUp: false, sortOrder: 1 },
  { id: "homeo-follow-up", departmentId: "homeo", name: "Follow-up", isFollowUp: true, sortOrder: 2 },
];

async function seedCatalog() {
  const batch = db.batch();
  for (const d of DEPARTMENTS) {
    batch.set(
      db.collection("departments").doc(d.id),
      { name: d.name, code: d.code, sortOrder: d.sortOrder, active: true, ...STAMP("seed") },
      { merge: true }
    );
  }
  for (const v of VISIT_TYPES) {
    batch.set(
      db.collection("visitTypes").doc(v.id),
      {
        departmentId: v.departmentId,
        name: v.name,
        isOperation: false,
        isFollowUp: v.isFollowUp,
        sortOrder: v.sortOrder,
        active: true,
        defaultPreOpChecklist: [],
        defaultPostOpDays: [],
        ...STAMP("seed"),
      },
      { merge: true }
    );
  }
  batch.set(
    db.collection("doctors").doc("seed-doctor"),
    {
      userId: "seed-multi",
      name: "Dr Multi",
      departmentId: "eye",
      departmentCode: "E",
      specialisation: "General",
      salary: 50000,
      sharePercent: 10,
      shareBasis: "gross",
      fees: { "eye-checkup": 1500, "eye-follow-up": 500, "eye-eye-test": 800 },
      active: true,
      branchId: "main",
      ...STAMP("seed"),
    },
    { merge: true }
  );
  await batch.commit();
  console.log("seeded departments, visit types, doctor seed-doctor");
}

// Phase 3: one family with two patients so search has something to find.
// `patientNo` stays null; when the Functions emulator is running the
// assignPatientNo trigger numbers them like the real project would.
const FAMILY = {
  id: "seed-family-khan",
  phone: "03001234567",
  headName: "Khan",
  address: "Lyari, Karachi",
};
const PATIENTS = [
  {
    id: "seed-patient-ali",
    tempNo: "T-SEED1",
    name: "Ali Khan",
    gender: "male",
    dateOfBirth: "1986-01-01",
    dobApproximate: true,
    personalPhone: null,
    searchKeys: ["a", "al", "ali", "ali ", "ali k", "ali kh", "ali kha", "ali khan", "k", "kh", "kha", "khan"],
  },
  {
    id: "seed-patient-sara",
    tempNo: "T-SEED2",
    name: "Sara Khan",
    gender: "female",
    dateOfBirth: "2010-04-02",
    dobApproximate: false,
    personalPhone: "03119876543",
    searchKeys: ["s", "sa", "sar", "sara", "sara ", "sara k", "sara kh", "sara kha", "sara khan", "k", "kh", "kha", "khan"],
  },
];

async function seedPatients() {
  const batch = db.batch();
  batch.set(
    db.collection("families").doc(FAMILY.id),
    {
      phone: FAMILY.phone,
      headName: FAMILY.headName,
      address: FAMILY.address,
      patientCount: PATIENTS.length,
      duplicatePhone: false,
      branchId: "main",
      ...STAMP("seed"),
    },
    { merge: true }
  );
  for (const p of PATIENTS) {
    batch.set(
      db.collection("patients").doc(p.id),
      {
        patientNo: null,
        tempNo: p.tempNo,
        familyId: FAMILY.id,
        name: p.name,
        gender: p.gender,
        dateOfBirth: p.dateOfBirth,
        dobApproximate: p.dobApproximate,
        personalPhone: p.personalPhone,
        phones: [FAMILY.phone, ...(p.personalPhone ? [p.personalPhone] : [])],
        address: "",
        notes: "",
        searchKeys: p.searchKeys,
        visitCount: 0,
        lastVisitAt: null,
        lastDoctorId: null,
        deleted: false,
        branchId: "main",
        createdAtLocal: FieldValue.serverTimestamp(),
        ...STAMP("seed"),
      },
      { merge: true }
    );
  }
  await batch.commit();
  console.log("seeded family Khan with Ali Khan and Sara Khan");
}

(async () => {
  for (const u of SEED) await upsert(u);
  await seedCatalog();
  await seedPatients();
  console.log("done");
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});

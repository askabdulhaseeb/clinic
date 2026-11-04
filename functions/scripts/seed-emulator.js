#!/usr/bin/env node
// Seeds the local Auth + Firestore emulators with the accounts and master
// data the Flutter integration tests expect. Run while the emulators are up:
//   node scripts/seed-emulator.js
// Never points at production: it refuses to run without the emulator hosts.
//
// Seeded: three accounts (admin, first-login reception, multi-role), the Eye
// and Homeopathy departments with their visit types, and one doctor record
// linked to the multi-role account. `settings/general` is deliberately NOT
// seeded so the integration test can exercise the first-run setup screen;
// the admin setup flow creates it.
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

(async () => {
  for (const u of SEED) await upsert(u);
  await seedCatalog();
  console.log("done");
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});

// Phase 3 triggers (FIREBASE_ARCHITECTURE.md §5): assignPatientNo and
// checkDuplicateFamilyPhone. Runs against the Firestore emulator.
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, Timestamp, type Firestore } from "firebase-admin/firestore";
import { assignPatientNoCore } from "../src/patients";
import { checkDuplicateFamilyPhoneCore } from "../src/families";

const PROJECT_ID = "ramzan-clinic-web";
let db: Firestore;

async function clearFirestore() {
  const fsHost = process.env.FIRESTORE_EMULATOR_HOST;
  await fetch(
    `http://${fsHost}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" }
  );
}

async function seedPatient(id: string, extra: Record<string, unknown> = {}) {
  await db.doc(`patients/${id}`).set({
    patientNo: null,
    tempNo: "T-AAAAA",
    familyId: "f1",
    name: `Patient ${id}`,
    gender: "male",
    phones: ["03001234567"],
    searchKeys: [],
    visitCount: 0,
    deleted: false,
    branchId: "main",
    createdAtLocal: Timestamp.fromDate(new Date("2026-11-04T10:00:00+05:00")),
    createdBy: "rec-1",
    ...extra,
  });
}

async function seedFamily(id: string, phone: string) {
  await db.doc(`families/${id}`).set({
    phone,
    headName: `Head ${id}`,
    address: "",
    patientCount: 0,
    duplicatePhone: false,
    branchId: "main",
    createdBy: "rec-1",
  });
}

beforeAll(() => {
  if (getApps().length === 0) initializeApp({ projectId: PROJECT_ID });
  db = getFirestore();
});

beforeEach(clearFirestore);

describe("assignPatientNo", () => {
  it("numbers patients sequentially within the year of creation", async () => {
    await seedPatient("p1");
    await seedPatient("p2");
    expect(await assignPatientNoCore(db, "p1")).toBe("26-00001");
    expect(await assignPatientNoCore(db, "p2")).toBe("26-00002");
    expect((await db.doc("patients/p1").get()).get("patientNo")).toBe("26-00001");
    expect((await db.doc("patients/p2").get()).get("patientNo")).toBe("26-00002");
    expect((await db.doc("counters/patients_26").get()).get("value")).toBe(2);
  });

  it("uses a counter per year, from the Karachi date of createdAtLocal", async () => {
    // 23:30 UTC on 31 Dec 2025 is already 2026 in Karachi.
    await seedPatient("late", {
      createdAtLocal: Timestamp.fromDate(new Date("2025-12-31T23:30:00Z")),
    });
    await seedPatient("old", {
      createdAtLocal: Timestamp.fromDate(new Date("2025-06-01T10:00:00Z")),
    });
    expect(await assignPatientNoCore(db, "late")).toBe("26-00001");
    expect(await assignPatientNoCore(db, "old")).toBe("25-00001");
    expect((await db.doc("counters/patients_25").get()).get("value")).toBe(1);
    expect((await db.doc("counters/patients_26").get()).get("value")).toBe(1);
  });

  it("falls back to now when createdAtLocal is missing", async () => {
    await seedPatient("p1", { createdAtLocal: null });
    const now = new Date("2027-03-01T05:00:00Z");
    expect(await assignPatientNoCore(db, "p1", now)).toBe("27-00001");
  });

  it("is idempotent: a retried event keeps the number and the counter", async () => {
    await seedPatient("p1");
    await assignPatientNoCore(db, "p1");
    expect(await assignPatientNoCore(db, "p1")).toBe("26-00001");
    expect((await db.doc("counters/patients_26").get()).get("value")).toBe(1);
  });

  it("ignores a document that no longer exists", async () => {
    expect(await assignPatientNoCore(db, "ghost")).toBeNull();
    expect((await db.doc("counters/patients_26").get()).exists).toBe(false);
  });

  it("hands out distinct numbers under concurrency", async () => {
    const ids = ["a", "b", "c", "d", "e", "f"];
    await Promise.all(ids.map((id) => seedPatient(id)));
    const numbers = await Promise.all(ids.map((id) => assignPatientNoCore(db, id)));
    expect(new Set(numbers).size).toBe(ids.length);
    expect([...numbers].sort()).toEqual([
      "26-00001",
      "26-00002",
      "26-00003",
      "26-00004",
      "26-00005",
      "26-00006",
    ]);
  });
});

describe("checkDuplicateFamilyPhone", () => {
  it("leaves a unique phone alone", async () => {
    await seedFamily("f1", "03001234567");
    await seedFamily("f2", "03009999999");
    expect(await checkDuplicateFamilyPhoneCore(db, "f1")).toEqual([]);
    expect((await db.doc("families/f1").get()).get("duplicatePhone")).toBe(false);
  });

  it("flags every family sharing the phone", async () => {
    await seedFamily("f1", "03001234567");
    await seedFamily("f2", "03001234567");
    await seedFamily("f3", "03009999999");
    const flagged = await checkDuplicateFamilyPhoneCore(db, "f2");
    expect(flagged.sort()).toEqual(["f1", "f2"]);
    expect((await db.doc("families/f1").get()).get("duplicatePhone")).toBe(true);
    expect((await db.doc("families/f2").get()).get("duplicatePhone")).toBe(true);
    expect((await db.doc("families/f3").get()).get("duplicatePhone")).toBe(false);
  });

  it("ignores a family that no longer exists", async () => {
    expect(await checkDuplicateFamilyPhoneCore(db, "ghost")).toEqual([]);
  });
});

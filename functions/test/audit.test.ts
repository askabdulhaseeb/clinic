// Phase 9: auditWriteCore (FIREBASE_ARCHITECTURE.md §4.24, §5). Runs
// against the Firestore emulator; the trigger wrappers are exercised by the
// Chrome flow through the Functions emulator.
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import { auditWriteCore, changedFields } from "../src/audit";

const PROJECT_ID = "ramzan-clinic-web";
let db: Firestore;
const NOW = new Date("2026-11-06T06:30:00Z"); // 11:30 Karachi

async function clearFirestore() {
  const fsHost = process.env.FIRESTORE_EMULATOR_HOST;
  await fetch(
    `http://${fsHost}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" }
  );
}

function visit(extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    patientName: "Ali Khan",
    doctorId: "doc-1",
    date: "2026-11-06",
    fee: 1500,
    discountAmount: 0,
    discountReason: "",
    netAmount: 1500,
    paymentMethod: "cash",
    status: "waiting",
    deleted: false,
    editReason: null,
    createdBy: "rec-1",
    updatedBy: "rec-1",
    updatedAt: "t0",
    ...extra,
  };
}

async function logs() {
  const snap = await db.collection("auditLogs").get();
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }) as Record<string, unknown>);
}

beforeAll(() => {
  if (getApps().length === 0) initializeApp({ projectId: PROJECT_ID });
  db = getFirestore();
});

beforeEach(async () => {
  await clearFirestore();
  await db.doc("users/admin-1").set({ displayName: "Dr Admin" });
});

describe("changedFields", () => {
  it("lists keys whose value differs, ignoring the audit stamps", () => {
    expect(
      changedFields(visit(), visit({ fee: 1000, netAmount: 1000, updatedAt: "t1", updatedBy: "admin-1" }))
    ).toEqual(["fee", "netAmount"]);
    expect(changedFields(visit(), visit({ updatedAt: "t1" }))).toEqual([]);
    expect(changedFields(visit(), visit({ extra: 1 }))).toEqual(["extra"]);
  });
});

describe("auditWriteCore", () => {
  it("skips creates and deletes of the raw document", async () => {
    expect(
      await auditWriteCore(db, { collection: "visits", docId: "v1", eventId: "e1", before: undefined, after: visit(), now: NOW })
    ).toBe("skipped-create");
    expect(
      await auditWriteCore(db, { collection: "visits", docId: "v1", eventId: "e2", before: visit(), after: undefined, now: NOW })
    ).toBe("skipped-create");
    expect(await logs()).toEqual([]);
  });

  it("skips queue-only visit changes and stock-only item changes", async () => {
    expect(
      await auditWriteCore(db, {
        collection: "visits",
        docId: "v1",
        eventId: "e1",
        before: visit(),
        after: visit({ status: "inProgress", startedAt: "t1", updatedAt: "t1", updatedBy: "rec-1" }),
        now: NOW,
      })
    ).toBe("skipped-ignored");
    expect(
      await auditWriteCore(db, {
        collection: "inventoryItems",
        docId: "i1",
        eventId: "e2",
        before: { name: "Drops", stock: 10, updatedBy: "rec-1" },
        after: { name: "Drops", stock: 9, updatedBy: "rec-1", updatedAt: "t1" },
        now: NOW,
      })
    ).toBe("skipped-ignored");
    expect(await logs()).toEqual([]);
  });

  it("logs an edit with the actor's name, the reason and the changed values only", async () => {
    const before = visit();
    const after = visit({
      fee: 1000,
      netAmount: 1000,
      doctorId: "doc-2",
      editReason: "Wrong fee typed",
      updatedAt: "t1",
      updatedBy: "admin-1",
    });
    expect(
      await auditWriteCore(db, { collection: "visits", docId: "v1", eventId: "ev-1", before, after, now: NOW })
    ).toBe("logged");
    const [log] = await logs();
    expect(log.id).toBe("ev-1");
    expect(log).toMatchObject({
      collection: "visits",
      docId: "v1",
      action: "update",
      userId: "admin-1",
      userName: "Dr Admin",
      reason: "Wrong fee typed",
      changedFields: ["doctorId", "editReason", "fee", "netAmount"],
      before: { fee: 1500, netAmount: 1500, doctorId: "doc-1", editReason: null },
      after: { fee: 1000, netAmount: 1000, doctorId: "doc-2", editReason: "Wrong fee typed" },
      date: "2026-11-06",
      label: "Ali Khan",
    });
    expect(log.createdAt).toBeDefined();
  });

  it("logs a soft delete as delete with its reason; unknown users keep the uid", async () => {
    await auditWriteCore(db, {
      collection: "sales",
      docId: "s1",
      eventId: "ev-2",
      before: { customerName: "Walk-in", total: 500, deleted: false, updatedBy: "rec-1" },
      after: { customerName: "Walk-in", total: 500, deleted: true, deleteReason: "Wrong item", deletedBy: "ghost", updatedBy: "ghost" },
      now: NOW,
    });
    const [log] = await logs();
    expect(log).toMatchObject({
      collection: "sales",
      action: "delete",
      userId: "ghost",
      userName: "ghost",
      reason: "Wrong item",
      label: "Walk-in",
    });
    expect(log.changedFields).toEqual(["deleteReason", "deleted", "deletedBy"]);
  });

  it("picks the reason from unpaidReason and cancelReason too; a redelivery overwrites", async () => {
    const before = { doctorName: "Dr Sara", paid: true, expenseId: "e1", unpaidReason: "", updatedBy: "admin-1" };
    const after = { doctorName: "Dr Sara", paid: false, expenseId: null, unpaidReason: "Cheque bounced", updatedBy: "admin-1" };
    await auditWriteCore(db, { collection: "payouts", docId: "p1", eventId: "ev-3", before, after, now: NOW });
    await auditWriteCore(db, { collection: "payouts", docId: "p1", eventId: "ev-3", before, after, now: NOW });
    const all = await logs();
    expect(all).toHaveLength(1);
    expect(all[0]).toMatchObject({ action: "update", reason: "Cheque bounced", label: "Dr Sara" });
    expect(
      await auditWriteCore(db, {
        collection: "settings",
        docId: "general",
        eventId: "ev-4",
        before: { clinicName: "Old", updatedBy: "admin-1" },
        after: { clinicName: "New", updatedBy: "admin-1" },
        now: NOW,
      })
    ).toBe("logged");
    expect((await logs()).find((l) => l.id === "ev-4")).toMatchObject({ reason: "", label: "New" });
  });
});

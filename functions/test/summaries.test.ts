// Phase 8A: applyDailySummaryDelta core and recomputeDay
// (FIREBASE_ARCHITECTURE.md §4.22, §4.23, §5). Runs against the Firestore
// emulator; the trigger wrappers are not exercised here (the Chrome flow
// does that through the Functions emulator).
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { applyDailySummaryDeltaCore, dayDeltas, recomputeDayCore } from "../src/summaries";

const ADMIN_CLAIMS = { roles: ["admin"], doctorId: null, branchIds: ["main"] };
const RECEPTION_CLAIMS = { roles: ["reception"], doctorId: null, branchIds: ["main"] };

const PROJECT_ID = "ramzan-clinic-web";
const DAY = "2026-11-06";
let db: Firestore;

async function clearFirestore() {
  const fsHost = process.env.FIRESTORE_EMULATOR_HOST;
  await fetch(
    `http://${fsHost}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" }
  );
}

function visit(extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    patientId: "pat-1",
    doctorId: "doc-1",
    departmentId: "dep-eye",
    date: DAY,
    isFirstVisit: true,
    fee: 1000,
    discountAmount: 100,
    discountReason: "Staff",
    netAmount: 900,
    paymentMethod: "cash",
    status: "waiting",
    deleted: false,
    createdBy: "rec-1",
    branchId: "main",
    ...extra,
  };
}

async function summary(date = DAY) {
  return (await db.doc(`dailySummaries/${date}`).get()).data();
}

beforeAll(() => {
  if (getApps().length === 0) initializeApp({ projectId: PROJECT_ID });
  db = getFirestore();
});

beforeEach(clearFirestore);

describe("applyDailySummaryDeltaCore", () => {
  it("a new visit increments the day's totals and buckets", async () => {
    const result = await applyDailySummaryDeltaCore(db, {
      collection: "visits",
      eventId: "ev-1",
      before: undefined,
      after: visit(),
    });
    expect(result).toBe("applied");
    const s = await summary();
    expect(s).toMatchObject({
      date: DAY,
      branchId: "main",
      visits: 1,
      newPatients: 1,
      grossFees: 1000,
      discounts: 100,
      netFees: 900,
      byPayment: { cash: 900 },
      byDepartment: { "dep-eye": { visits: 1, gross: 1000, discounts: 100, net: 900 } },
      byDoctor: { "doc-1": { visits: 1, gross: 1000, discounts: 100, net: 900 } },
      discountsByUser: { "rec-1": { count: 1, amount: 100 } },
      discountsByReason: { Staff: { count: 1, amount: 100 } },
      netProfit: 900,
    });
    const ev = (await db.doc("summaryEvents/ev-1").get()).data();
    expect(ev?.date).toBe(DAY);
    expect(ev?.expiresAt).toBeDefined();
  });

  it("an edit applies only the difference", async () => {
    const before = visit();
    await applyDailySummaryDeltaCore(db, { collection: "visits", eventId: "ev-1", before: undefined, after: before });
    const after = visit({ fee: 1500, discountAmount: 0, discountReason: "", netAmount: 1500, paymentMethod: "bank" });
    const result = await applyDailySummaryDeltaCore(db, { collection: "visits", eventId: "ev-2", before, after });
    expect(result).toBe("applied");
    const s = await summary();
    expect(s).toMatchObject({
      visits: 1,
      grossFees: 1500,
      discounts: 0,
      netFees: 1500,
      byPayment: { cash: 0, bank: 1500 },
      byDoctor: { "doc-1": { visits: 1, gross: 1500, discounts: 0, net: 1500 } },
      discountsByUser: { "rec-1": { count: 0, amount: 0 } },
      netProfit: 1500,
    });
  });

  it("a status-only change is a zero delta and writes nothing", async () => {
    const before = visit();
    const after = visit({ status: "completed", completedAt: "x" });
    expect(dayDeltas("visits", before, after).size).toBe(0);
    const result = await applyDailySummaryDeltaCore(db, { collection: "visits", eventId: "ev-9", before, after });
    expect(result).toBe("skipped-zero");
    expect(await summary()).toBeUndefined();
    expect((await db.doc("summaryEvents/ev-9").get()).exists).toBe(false);
  });

  it("a doctor change moves the doctor bucket (Phase 8B correction)", async () => {
    const before = visit();
    await applyDailySummaryDeltaCore(db, { collection: "visits", eventId: "ev-1", before: undefined, after: before });
    const after = visit({ doctorId: "doc-2", fee: 1200, discountAmount: 0, discountReason: "", netAmount: 1200 });
    await applyDailySummaryDeltaCore(db, { collection: "visits", eventId: "ev-2", before, after });
    const s = await summary();
    expect(s).toMatchObject({
      visits: 1,
      grossFees: 1200,
      netFees: 1200,
      byDoctor: {
        "doc-1": { visits: 0, gross: 0, discounts: 0, net: 0 },
        // `discounts` stays absent: it was never incremented for doc-2.
        "doc-2": { visits: 1, gross: 1200, net: 1200 },
      },
      byDepartment: { "dep-eye": { visits: 1, gross: 1200, discounts: 0, net: 1200 } },
      discountsByReason: { Staff: { count: 0, amount: 0 } },
    });
  });

  it("a soft delete removes the visit's contribution", async () => {
    const before = visit();
    await applyDailySummaryDeltaCore(db, { collection: "visits", eventId: "ev-1", before: undefined, after: before });
    await applyDailySummaryDeltaCore(db, {
      collection: "visits",
      eventId: "ev-2",
      before,
      after: visit({ deleted: true, deleteReason: "Test" }),
    });
    const s = await summary();
    expect(s).toMatchObject({ visits: 0, newPatients: 0, grossFees: 0, netFees: 0, netProfit: 0 });
    expect(s?.byDepartment["dep-eye"]).toEqual({ visits: 0, gross: 0, discounts: 0, net: 0 });
  });

  it("a redelivered event is skipped", async () => {
    const after = visit();
    await applyDailySummaryDeltaCore(db, { collection: "visits", eventId: "ev-1", before: undefined, after });
    const result = await applyDailySummaryDeltaCore(db, { collection: "visits", eventId: "ev-1", before: undefined, after });
    expect(result).toBe("skipped-duplicate");
    expect((await summary())?.visits).toBe(1);
  });

  it("a date change moves the contribution to the new day", async () => {
    const before = visit();
    await applyDailySummaryDeltaCore(db, { collection: "visits", eventId: "ev-1", before: undefined, after: before });
    await applyDailySummaryDeltaCore(db, {
      collection: "visits",
      eventId: "ev-2",
      before,
      after: visit({ date: "2026-11-07" }),
    });
    expect((await summary(DAY))?.netFees).toBe(0);
    expect((await summary("2026-11-07"))).toMatchObject({ date: "2026-11-07", visits: 1, netFees: 900 });
  });

  it("a sale adds to the sales fields and profit", async () => {
    const sale = {
      patientName: "Walk-in",
      date: DAY,
      items: [
        { itemId: "i1", name: "Eye Drops", category: "consumable", qty: 2, unitPrice: 150 },
        { itemId: "l1", name: "Lens", category: "lens", qty: 1, unitPrice: 900 },
      ],
      subtotal: 1200,
      discountAmount: 100,
      discountReason: "Staff",
      total: 1100,
      paymentMethod: "cash",
      deleted: false,
      createdBy: "rec-1",
      branchId: "main",
    };
    await applyDailySummaryDeltaCore(db, { collection: "sales", eventId: "s-1", before: undefined, after: sale });
    expect(await summary()).toMatchObject({
      salesTotal: 1100,
      salesDiscounts: 100,
      salesByCategory: { consumable: 300, lens: 900 },
      netProfit: 1100,
    });
    expect((await summary())?.visits).toBeUndefined();
    // Void takes it back out.
    await applyDailySummaryDeltaCore(db, { collection: "sales", eventId: "s-2", before: sale, after: { ...sale, deleted: true } });
    expect(await summary()).toMatchObject({ salesTotal: 0, salesByCategory: { consumable: 0, lens: 0 }, netProfit: 0 });
  });

  it("a sale's line costs feed salesCost and salesCostByCategory (Phase 10)", async () => {
    const sale = {
      patientName: "Walk-in",
      date: DAY,
      items: [
        { itemId: "i1", name: "Eye Drops", category: "consumable", qty: 2, unitPrice: 150, unitCost: 60 },
        { itemId: "l1", name: "Lens", category: "lens", qty: 1, unitPrice: 900, unitCost: 400 },
        // Written before Phase 10: no unitCost, counts as 0.
        { itemId: "f1", name: "Frame", category: "frame", qty: 1, unitPrice: 1200 },
      ],
      subtotal: 2400,
      discountAmount: 0,
      discountReason: "",
      total: 2400,
      paymentMethod: "cash",
      deleted: false,
      createdBy: "rec-1",
      branchId: "main",
    };
    await applyDailySummaryDeltaCore(db, { collection: "sales", eventId: "sc-1", before: undefined, after: sale });
    expect(await summary()).toMatchObject({
      salesTotal: 2400,
      salesByCategory: { consumable: 300, lens: 900, frame: 1200 },
      salesCost: 520,
      salesCostByCategory: { consumable: 120, lens: 400 },
      netProfit: 2400,
    });
    expect((await summary())?.salesCostByCategory?.frame).toBeUndefined();
  });

  it("an expense reduces profit and buckets by category", async () => {
    const expense = { category: "rent", amount: 5000, date: DAY, note: "", source: "manual", deleted: false, createdBy: "adm-1", branchId: "main" };
    await applyDailySummaryDeltaCore(db, { collection: "expenses", eventId: "e-1", before: undefined, after: expense });
    expect(await summary()).toMatchObject({ expensesTotal: 5000, expensesByCategory: { rent: 5000 }, netProfit: -5000 });
    await applyDailySummaryDeltaCore(db, {
      collection: "expenses",
      eventId: "e-2",
      before: expense,
      after: { ...expense, category: "utilities", amount: 700 },
    });
    expect(await summary()).toMatchObject({ expensesTotal: 700, expensesByCategory: { rent: 0, utilities: 700 }, netProfit: -700 });
  });
});

describe("recomputeDayCore", () => {
  it("rewrites the day from its visits, sales and expenses and drops stale buckets", async () => {
    await db.doc("visits/v1").set(visit());
    await db.doc("visits/v2").set(visit({ isFirstVisit: false, fee: 500, discountAmount: 0, discountReason: "", netAmount: 500, paymentMethod: "bank", doctorId: "doc-2" }));
    await db.doc("visits/v3").set(visit({ deleted: true, deleteReason: "x" }));
    await db.doc("visits/v4").set(visit({ date: "2026-11-05" }));
    await db.doc("sales/s1").set({ date: DAY, items: [{ category: "frame", qty: 1, unitPrice: 2000 }], subtotal: 2000, discountAmount: 0, total: 2000, deleted: false, branchId: "main" });
    await db.doc("expenses/e1").set({ date: DAY, category: "rent", amount: 300, source: "manual", deleted: false, branchId: "main" });
    // A drifted summary with a bucket that no longer exists.
    await db.doc(`dailySummaries/${DAY}`).set({ date: DAY, visits: 9, byDoctor: { ghost: { visits: 4 } } });

    const result = await recomputeDayCore(db, "adm-1", ADMIN_CLAIMS, { date: DAY });
    expect(result).toMatchObject({ date: DAY, visits: 2, newPatients: 1, returningPatients: 1, grossFees: 1500, netFees: 1400, salesTotal: 2000, expensesTotal: 300, netProfit: 3100 });
    const s = await summary();
    expect(s).toMatchObject({
      visits: 2,
      byPayment: { cash: 900, bank: 500 },
      byDoctor: { "doc-1": { visits: 1, gross: 1000, discounts: 100, net: 900 }, "doc-2": { visits: 1, gross: 500, discounts: 0, net: 500 } },
      salesByCategory: { frame: 2000 },
      expensesByCategory: { rent: 300 },
      netProfit: 3100,
    });
    expect(s?.byDoctor.ghost).toBeUndefined();
    expect(s?.updatedAt).toBeDefined();
  });

  it("recompute carries the sales cost fields", async () => {
    await db.collection("sales").add({
      patientName: "Walk-in",
      date: DAY,
      items: [{ itemId: "i1", name: "Eye Drops", category: "consumable", qty: 3, unitPrice: 150, unitCost: 60 }],
      subtotal: 450,
      discountAmount: 0,
      total: 450,
      paymentMethod: "cash",
      deleted: false,
      createdBy: "rec-1",
      branchId: "main",
    });
    const out = await recomputeDayCore(db, "admin-1", ADMIN_CLAIMS, { date: DAY });
    expect(out).toMatchObject({ salesTotal: 450, salesCost: 180, salesCostByCategory: { consumable: 180 } });
    expect(await summary()).toMatchObject({ salesCost: 180, salesCostByCategory: { consumable: 180 } });
  });

  it("an empty day becomes an all-zero summary", async () => {
    const result = await recomputeDayCore(db, "adm-1", ADMIN_CLAIMS, { date: "2026-01-01" });
    expect(result).toMatchObject({ visits: 0, netFees: 0, netProfit: 0 });
    expect((await summary("2026-01-01"))?.visits).toBe(0);
  });

  it("rejects non-admins and bad dates", async () => {
    await expect(recomputeDayCore(db, "rec-1", RECEPTION_CLAIMS, { date: DAY })).rejects.toMatchObject({ code: "permission-denied" });
    await expect(recomputeDayCore(db, "adm-1", ADMIN_CLAIMS, { date: "6/11/2026" })).rejects.toBeInstanceOf(HttpsError);
    await expect(recomputeDayCore(db, "adm-1", ADMIN_CLAIMS, {})).rejects.toMatchObject({ code: "invalid-argument" });
  });
});

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue, getFirestore, Timestamp, type Firestore } from "firebase-admin/firestore";

// Phase 8A: dailySummaries kept by increments (FIREBASE_ARCHITECTURE.md
// §4.22, §4.23, §5). One trigger per collection shares
// applyDailySummaryDeltaCore: the contribution of the document before and
// after the write is computed from the data alone, the difference is applied
// with FieldValue.increment, and the event ID is recorded in summaryEvents
// so a redelivered event never counts twice.

export type SummaryCollection = "visits" | "sales" | "expenses";

/** Nested numeric increments, mirroring the summary document's shape. */
export interface Delta {
  [key: string]: number | Delta;
}

export interface Contribution {
  date: string;
  branchId: string;
  delta: Delta;
}

const EVENT_TTL_MS = 2 * 24 * 60 * 60 * 1000;

function num(v: unknown): number {
  return typeof v === "number" && Number.isFinite(v) ? v : 0;
}

function str(v: unknown, fallback = ""): string {
  return typeof v === "string" && v.length > 0 ? v : fallback;
}

function visitContribution(d: Record<string, unknown>): Delta {
  const fee = num(d.fee);
  const discount = num(d.discountAmount);
  const net = num(d.netAmount);
  const bucket = { visits: 1, gross: fee, discounts: discount, net };
  const delta: Delta = {
    visits: 1,
    newPatients: d.isFirstVisit === true ? 1 : 0,
    returningPatients: d.isFirstVisit === true ? 0 : 1,
    grossFees: fee,
    discounts: discount,
    netFees: net,
    byPayment: { [str(d.paymentMethod, "cash")]: net },
    byDepartment: { [str(d.departmentId, "unknown")]: bucket },
    byDoctor: { [str(d.doctorId, "unknown")]: bucket },
    netProfit: net,
  };
  if (discount > 0) {
    delta.discountsByUser = { [str(d.createdBy, "unknown")]: { count: 1, amount: discount } };
    delta.discountsByReason = { [str(d.discountReason, "Other")]: { count: 1, amount: discount } };
  }
  return delta;
}

function saleContribution(d: Record<string, unknown>): Delta {
  const byCategory: Delta = {};
  const costByCategory: Delta = {};
  let cost = 0;
  const items = Array.isArray(d.items) ? d.items : [];
  for (const raw of items) {
    if (typeof raw !== "object" || raw === null) continue;
    const line = raw as Record<string, unknown>;
    const key = str(line.category, "other");
    const qty = num(line.qty);
    byCategory[key] = num(byCategory[key]) + qty * num(line.unitPrice);
    // Phase 10: unitCost is the purchase price snapshot; lines written
    // before it have none and count as 0 cost.
    const lineCost = qty * num(line.unitCost);
    if (lineCost !== 0) {
      costByCategory[key] = num(costByCategory[key]) + lineCost;
      cost += lineCost;
    }
  }
  const total = num(d.total);
  return {
    salesTotal: total,
    salesDiscounts: num(d.discountAmount),
    salesByCategory: byCategory,
    salesCost: cost,
    salesCostByCategory: costByCategory,
    netProfit: total,
  };
}

function expenseContribution(d: Record<string, unknown>): Delta {
  const amount = num(d.amount);
  return {
    expensesTotal: amount,
    expensesByCategory: { [str(d.category, "other")]: amount },
    netProfit: -amount,
  };
}

/**
 * What one document adds to its day's summary; null when it adds nothing
 * (missing, soft-deleted or without a date).
 */
export function contribution(
  collection: SummaryCollection,
  data: Record<string, unknown> | undefined
): Contribution | null {
  if (!data || data.deleted === true) return null;
  const date = str(data.date);
  if (!date) return null;
  const branchId = str(data.branchId, "main");
  switch (collection) {
    case "visits":
      return { date, branchId, delta: visitContribution(data) };
    case "sales":
      return { date, branchId, delta: saleContribution(data) };
    case "expenses":
      return { date, branchId, delta: expenseContribution(data) };
  }
}

function negate(delta: Delta): Delta {
  const out: Delta = {};
  for (const [k, v] of Object.entries(delta)) {
    out[k] = typeof v === "number" ? -v : negate(v);
  }
  return out;
}

/** Merges two deltas, adding numbers at the same path. */
export function addDeltas(a: Delta, b: Delta): Delta {
  const out: Delta = { ...a };
  for (const [k, v] of Object.entries(b)) {
    const cur = out[k];
    if (typeof v === "number") {
      out[k] = num(cur) + v;
    } else {
      out[k] = addDeltas(typeof cur === "object" ? cur : {}, v);
    }
  }
  return out;
}

/** Drops zero leaves and empty maps. */
export function pruneDelta(delta: Delta): Delta {
  const out: Delta = {};
  for (const [k, v] of Object.entries(delta)) {
    if (typeof v === "number") {
      if (v !== 0) out[k] = v;
    } else {
      const inner = pruneDelta(v);
      if (Object.keys(inner).length > 0) out[k] = inner;
    }
  }
  return out;
}

function toIncrements(delta: Delta): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(delta)) {
    out[k] = typeof v === "number" ? FieldValue.increment(v) : toIncrements(v);
  }
  return out;
}

export interface DeltaEvent {
  collection: SummaryCollection;
  eventId: string;
  before: Record<string, unknown> | undefined;
  after: Record<string, unknown> | undefined;
  now?: Date;
}

export type DeltaResult = "applied" | "skipped-zero" | "skipped-duplicate";

/** Per-day deltas for one write: the old day loses, the new day gains. */
export function dayDeltas(
  collection: SummaryCollection,
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined
): Map<string, Contribution> {
  const days = new Map<string, Contribution>();
  const add = (c: Contribution | null, sign: 1 | -1) => {
    if (!c) return;
    const delta = sign === 1 ? c.delta : negate(c.delta);
    const cur = days.get(c.date);
    days.set(c.date, {
      date: c.date,
      branchId: c.branchId,
      delta: cur ? addDeltas(cur.delta, delta) : delta,
    });
  };
  add(contribution(collection, before), -1);
  add(contribution(collection, after), 1);
  for (const [date, c] of days) {
    const pruned = pruneDelta(c.delta);
    if (Object.keys(pruned).length === 0) days.delete(date);
    else days.set(date, { ...c, delta: pruned });
  }
  return days;
}

export async function applyDailySummaryDeltaCore(
  db: Firestore,
  event: DeltaEvent
): Promise<DeltaResult> {
  const days = dayDeltas(event.collection, event.before, event.after);
  if (days.size === 0) return "skipped-zero";
  const now = event.now ?? new Date();
  const eventRef = db.doc(`summaryEvents/${event.eventId}`);
  return db.runTransaction(async (tx) => {
    const seen = await tx.get(eventRef);
    if (seen.exists) return "skipped-duplicate";
    for (const c of days.values()) {
      tx.set(
        db.doc(`dailySummaries/${c.date}`),
        {
          date: c.date,
          branchId: c.branchId,
          ...toIncrements(c.delta),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
    tx.set(eventRef, {
      date: [...days.keys()].join(","),
      appliedAt: Timestamp.fromDate(now),
      expiresAt: Timestamp.fromDate(new Date(now.getTime() + EVENT_TTL_MS)),
    });
    return "applied";
  });
}

const EMPTY_SUMMARY: Delta = {
  visits: 0,
  newPatients: 0,
  returningPatients: 0,
  grossFees: 0,
  discounts: 0,
  netFees: 0,
  byPayment: {},
  byDepartment: {},
  byDoctor: {},
  discountsByUser: {},
  discountsByReason: {},
  salesTotal: 0,
  salesDiscounts: 0,
  salesByCategory: {},
  salesCost: 0,
  salesCostByCategory: {},
  expensesTotal: 0,
  expensesByCategory: {},
  netProfit: 0,
};

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

/**
 * `recomputeDay` (Admin): reads every visit, sale and expense of one day and
 * rewrites its summary from scratch (plain values, no merge, so stale
 * buckets disappear). Returns the summary written.
 */
export async function recomputeDayCore(
  db: Firestore,
  callerUid: string,
  callerClaims: Record<string, unknown> | undefined,
  data: unknown
): Promise<Record<string, unknown>> {
  const roles = Array.isArray(callerClaims?.roles) ? callerClaims.roles : [];
  if (!roles.includes("admin")) {
    throw new HttpsError("permission-denied", "Only admins may recompute a day.");
  }
  const date = typeof data === "object" && data !== null ? (data as { date?: unknown }).date : undefined;
  if (typeof date !== "string" || !DATE_RE.test(date)) {
    throw new HttpsError("invalid-argument", "date must be YYYY-MM-DD.");
  }
  let total: Delta = { ...EMPTY_SUMMARY };
  let branchId = "main";
  for (const collection of ["visits", "sales", "expenses"] as SummaryCollection[]) {
    const snap = await db.collection(collection).where("date", "==", date).get();
    for (const doc of snap.docs) {
      const c = contribution(collection, doc.data());
      if (!c) continue;
      total = addDeltas(total, c.delta);
      branchId = c.branchId;
    }
  }
  const summary = { date, branchId, ...total };
  await db.doc(`dailySummaries/${date}`).set({
    ...summary,
    updatedAt: FieldValue.serverTimestamp(),
    recomputedBy: callerUid,
  });
  return summary;
}

export const recomputeDay = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required.");
  return recomputeDayCore(getFirestore(), request.auth.uid, request.auth.token, request.data);
});

function trigger(collection: SummaryCollection) {
  return onDocumentWritten(`${collection}/{docId}`, async (event) => {
    await applyDailySummaryDeltaCore(getFirestore(), {
      collection,
      eventId: event.id,
      before: event.data?.before.data(),
      after: event.data?.after.data(),
    });
  });
}

export const applyVisitSummaryDelta = trigger("visits");
export const applySaleSummaryDelta = trigger("sales");
export const applyExpenseSummaryDelta = trigger("expenses");

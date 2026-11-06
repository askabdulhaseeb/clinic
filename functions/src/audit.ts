import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { FieldValue, getFirestore, type Firestore } from "firebase-admin/firestore";

// Phase 9: audit log (FIREBASE_ARCHITECTURE.md §4.24, §5). One trigger per
// audited collection shares auditWriteCore: creates and deletes of the raw
// document are skipped (nothing was corrected), queue-only visit moves and
// stock-only item changes are skipped (the queue and stockMovements already
// record them), everything else writes one auditLogs entry keyed by the
// event ID (a redelivery overwrites instead of duplicating) with the actor
// from `updatedBy`, the reason the client stored and the changed values.

export type AuditCollection =
  | "visits"
  | "sales"
  | "expenses"
  | "payouts"
  | "doctors"
  | "visitTypes"
  | "inventoryItems"
  | "users"
  | "settings";

export const AUDITED: AuditCollection[] = [
  "visits",
  "sales",
  "expenses",
  "payouts",
  "doctors",
  "visitTypes",
  "inventoryItems",
  "users",
  "settings",
];

/** Keys that never count as a change. */
const STAMPS = new Set(["updatedAt", "updatedBy"]);

/** Per collection: changes made only of these keys are not audited. */
const IGNORED: Partial<Record<AuditCollection, string[]>> = {
  visits: ["status", "startedAt", "completedAt", "hasPrescription", "saleId"],
  inventoryItems: ["stock"],
  users: ["mustChangePassword"],
};

const REASON_KEYS = ["editReason", "deleteReason", "unpaidReason", "cancelReason", "checklistOverrideReason"];
const LABEL_KEYS = ["patientName", "customerName", "doctorName", "name", "displayName", "clinicName", "note"];

const KARACHI_OFFSET_MS = 5 * 60 * 60 * 1000;

function karachiDate(d: Date): string {
  return new Date(d.getTime() + KARACHI_OFFSET_MS).toISOString().slice(0, 10);
}

function same(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (a === null || b === null || a === undefined || b === undefined) return false;
  if (typeof a === "object" && typeof b === "object") {
    if (typeof (a as { toMillis?: unknown }).toMillis === "function" && typeof (b as { toMillis?: unknown }).toMillis === "function") {
      return (a as { toMillis: () => number }).toMillis() === (b as { toMillis: () => number }).toMillis();
    }
    return JSON.stringify(a) === JSON.stringify(b);
  }
  return false;
}

/** Keys whose value differs between the two documents, sorted; stamps ignored. */
export function changedFields(
  before: Record<string, unknown>,
  after: Record<string, unknown>
): string[] {
  const keys = new Set([...Object.keys(before), ...Object.keys(after)]);
  const out: string[] = [];
  for (const k of keys) {
    if (STAMPS.has(k)) continue;
    if (!same(before[k], after[k])) out.push(k);
  }
  return out.sort();
}

export interface AuditEvent {
  collection: AuditCollection;
  docId: string;
  eventId: string;
  before: Record<string, unknown> | undefined;
  after: Record<string, unknown> | undefined;
  now?: Date;
}

export type AuditResult = "logged" | "skipped-create" | "skipped-ignored";

function str(v: unknown): string {
  return typeof v === "string" ? v : "";
}

function pick(doc: Record<string, unknown>, keys: string[]): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const k of keys) out[k] = doc[k] === undefined ? null : doc[k];
  return out;
}

export async function auditWriteCore(db: Firestore, event: AuditEvent): Promise<AuditResult> {
  const { before, after } = event;
  if (!before || !after) return "skipped-create";
  const changed = changedFields(before, after);
  const ignored = new Set(IGNORED[event.collection] ?? []);
  if (changed.length === 0 || changed.every((k) => ignored.has(k))) return "skipped-ignored";

  const userId = str(after.updatedBy) || str(before.updatedBy) || "unknown";
  let userName = userId;
  try {
    const user = await db.doc(`users/${userId}`).get();
    const name = str(user.data()?.displayName);
    if (name) userName = name;
  } catch {
    // Name lookup is best effort; the uid is kept.
  }
  const becameDeleted = before.deleted !== true && after.deleted === true;
  let reason = "";
  for (const k of REASON_KEYS) {
    if (changed.includes(k) && str(after[k])) {
      reason = str(after[k]);
      break;
    }
  }
  if (!reason && becameDeleted) reason = str(after.deleteReason);
  let label = "";
  for (const k of LABEL_KEYS) {
    if (str(after[k])) {
      label = str(after[k]);
      break;
    }
  }
  const now = event.now ?? new Date();
  await db.doc(`auditLogs/${event.eventId}`).set({
    collection: event.collection,
    docId: event.docId,
    action: becameDeleted ? "delete" : "update",
    userId,
    userName,
    reason,
    label,
    changedFields: changed,
    before: pick(before, changed),
    after: pick(after, changed),
    date: karachiDate(now),
    createdAt: FieldValue.serverTimestamp(),
  });
  return "logged";
}

function trigger(collection: AuditCollection) {
  return onDocumentWritten(`${collection}/{docId}`, async (event) => {
    await auditWriteCore(getFirestore(), {
      collection,
      docId: event.params.docId,
      eventId: event.id,
      before: event.data?.before.data(),
      after: event.data?.after.data(),
    });
  });
}

export const auditVisits = trigger("visits");
export const auditSales = trigger("sales");
export const auditExpenses = trigger("expenses");
export const auditPayouts = trigger("payouts");
export const auditDoctors = trigger("doctors");
export const auditVisitTypes = trigger("visitTypes");
export const auditInventoryItems = trigger("inventoryItems");
export const auditUsers = trigger("users");
export const auditSettings = trigger("settings");

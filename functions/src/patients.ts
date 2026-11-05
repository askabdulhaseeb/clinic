import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { FieldValue, getFirestore, Timestamp, type Firestore } from "firebase-admin/firestore";

// Phase 3: assignPatientNo (FIREBASE_ARCHITECTURE.md §5, §4.9).
// The client writes `patientNo: null` plus a `tempNo`; this trigger hands
// out `YY-NNNNN` from `counters/patients_{YY}` in a transaction so numbers
// never collide or repeat. YY comes from the Karachi date of creation.

const KARACHI_OFFSET_MS = 5 * 60 * 60 * 1000;

/** Two-digit Karachi year of a moment, e.g. "26". */
export function karachiYear(at: Date): string {
  const shifted = new Date(at.getTime() + KARACHI_OFFSET_MS);
  return String(shifted.getUTCFullYear() % 100).padStart(2, "0");
}

export function formatPatientNo(yy: string, value: number): string {
  return `${yy}-${String(value).padStart(5, "0")}`;
}

/**
 * Assigns the next number to `patients/{patientId}` unless it already has
 * one. Returns the number, or null when the document is gone.
 */
export async function assignPatientNoCore(
  db: Firestore,
  patientId: string,
  now: Date = new Date()
): Promise<string | null> {
  const patientRef = db.doc(`patients/${patientId}`);
  return db.runTransaction(async (tx) => {
    const patient = await tx.get(patientRef);
    if (!patient.exists) return null;
    const existing = patient.get("patientNo");
    if (typeof existing === "string" && existing.length > 0) return existing;

    const createdAtLocal = patient.get("createdAtLocal");
    const createdAt = createdAtLocal instanceof Timestamp ? createdAtLocal.toDate() : now;
    const yy = karachiYear(createdAt);
    const counterRef = db.doc(`counters/patients_${yy}`);
    const counter = await tx.get(counterRef);
    const current = counter.exists ? Number(counter.get("value") ?? 0) : 0;
    const next = current + 1;
    const patientNo = formatPatientNo(yy, next);

    tx.set(counterRef, { value: next }, { merge: true });
    // updatedAt moves so the reception delta sync (§9) pulls the number.
    tx.update(patientRef, { patientNo, updatedAt: FieldValue.serverTimestamp() });
    return patientNo;
  });
}

export const assignPatientNo = onDocumentCreated("patients/{patientId}", async (event) => {
  await assignPatientNoCore(getFirestore(), event.params.patientId);
});

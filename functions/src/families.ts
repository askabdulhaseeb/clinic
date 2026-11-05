import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { FieldValue, getFirestore, type Firestore } from "firebase-admin/firestore";

// Phase 3: checkDuplicateFamilyPhone (FIREBASE_ARCHITECTURE.md §5, §4.7).
// The client refuses a used phone when online; two families created
// offline with the same number both get `duplicatePhone: true` here so
// Admin can merge them later.

/** Flags every family sharing the new family's phone. Returns their ids. */
export async function checkDuplicateFamilyPhoneCore(
  db: Firestore,
  familyId: string
): Promise<string[]> {
  const created = await db.doc(`families/${familyId}`).get();
  if (!created.exists) return [];
  const phone = created.get("phone");
  if (typeof phone !== "string" || phone.length === 0) return [];

  const same = await db.collection("families").where("phone", "==", phone).get();
  if (same.size < 2) return [];

  const batch = db.batch();
  for (const doc of same.docs) {
    // updatedAt moves so the reception delta sync (§9) pulls the flag.
    batch.update(doc.ref, { duplicatePhone: true, updatedAt: FieldValue.serverTimestamp() });
  }
  await batch.commit();
  return same.docs.map((d) => d.id);
}

export const checkDuplicateFamilyPhone = onDocumentCreated(
  "families/{familyId}",
  async (event) => {
    await checkDuplicateFamilyPhoneCore(getFirestore(), event.params.familyId);
  }
);

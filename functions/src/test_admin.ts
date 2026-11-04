import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineBoolean } from "firebase-functions/params";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import type { Deps, UserClaims } from "./users";

// Development helper (FIREBASE_ARCHITECTURE.md §5, DEVELOPMENT_PLAN.md §1):
// a callable that creates, or restores, one fixed admin account so the owner
// can sign in and exercise the app without an existing admin. Anyone may
// call it, so it only runs while ALLOW_TEST_ADMIN=true (functions/.env);
// Phase 9 sets it to false and deletes the account.

export const TEST_ADMIN = {
  email: "admin@mytester.com",
  password: "1234567890",
  displayName: "Test Admin",
} as const;

const allowTestAdmin = defineBoolean("ALLOW_TEST_ADMIN", { default: false });

const CLAIMS: UserClaims = { roles: ["admin"], doctorId: null, branchIds: ["main"] };
const ACTOR = "createTestAdmin";

export async function createTestAdminCore(
  deps: Deps,
  allowed: boolean
): Promise<{ uid: string; created: boolean }> {
  if (!allowed) {
    throw new HttpsError("failed-precondition", "The test admin is switched off.");
  }

  let uid: string;
  let created: boolean;
  try {
    const existing = await deps.auth.getUserByEmail(TEST_ADMIN.email);
    uid = existing.uid;
    created = false;
    await deps.auth.updateUser(uid, {
      password: TEST_ADMIN.password,
      displayName: TEST_ADMIN.displayName,
      disabled: false,
    });
  } catch (err) {
    if ((err as { code?: string })?.code !== "auth/user-not-found") throw err;
    const user = await deps.auth.createUser({
      email: TEST_ADMIN.email,
      password: TEST_ADMIN.password,
      displayName: TEST_ADMIN.displayName,
    });
    uid = user.uid;
    created = true;
  }

  await deps.auth.setCustomUserClaims(uid, CLAIMS);
  await deps.db.doc(`users/${uid}`).set(
    {
      email: TEST_ADMIN.email,
      displayName: TEST_ADMIN.displayName,
      roles: CLAIMS.roles,
      doctorId: null,
      active: true,
      branchIds: CLAIMS.branchIds,
      mustChangePassword: false,
      ...(created ? { createdAt: FieldValue.serverTimestamp(), createdBy: ACTOR } : {}),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: ACTOR,
    },
    { merge: true }
  );
  // Old sessions must pick up the admin claims again.
  await deps.auth.revokeRefreshTokens(uid);

  return { uid, created };
}

export const createTestAdmin = onCall(async () => {
  const deps: Deps = { auth: getAuth(), db: getFirestore() };
  return createTestAdminCore(deps, allowTestAdmin.value());
});

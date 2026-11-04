import { onCall, HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import { getAuth, type Auth } from "firebase-admin/auth";
import { getFirestore, FieldValue, type Firestore } from "firebase-admin/firestore";
import {
  validateCreateUserInput,
  validateSetUserRolesInput,
  validateResetUserPasswordInput,
  type Role,
} from "./validation";

// Phase 1 user-management callables (FIREBASE_ARCHITECTURE.md §4.3, §5).
// Each callable is a thin wrapper around a pure *Core function that receives
// its dependencies explicitly so tests can run it against the emulators.

export interface Deps {
  auth: Auth;
  db: Firestore;
}

export type Claims = Record<string, unknown> | undefined;

export interface UserClaims {
  roles: Role[];
  doctorId: string | null;
  branchIds: string[];
}

const DEFAULT_BRANCH_IDS = ["main"];

function rolesFromClaims(claims: Claims): Role[] {
  const raw = claims?.roles;
  return Array.isArray(raw) ? (raw.filter((r) => typeof r === "string") as Role[]) : [];
}

function branchIdsFromClaims(claims: Claims): string[] {
  const raw = claims?.branchIds;
  return Array.isArray(raw) && raw.length > 0
    ? (raw.filter((b) => typeof b === "string") as string[])
    : DEFAULT_BRANCH_IDS;
}

function doctorIdFromClaims(claims: Claims): string | null {
  const raw = claims?.doctorId;
  return typeof raw === "string" && raw.length > 0 ? raw : null;
}

function requireAdmin(callerClaims: Claims): void {
  if (!rolesFromClaims(callerClaims).includes("admin")) {
    throw new HttpsError("permission-denied", "Only admins may manage users.");
  }
}

function authErrorCode(err: unknown): string | undefined {
  if (typeof err === "object" && err !== null && "code" in err) {
    const code = (err as { code: unknown }).code;
    return typeof code === "string" ? code : undefined;
  }
  return undefined;
}

/** Translate firebase-admin Auth errors into HttpsErrors for the client. */
function mapAuthError(err: unknown): never {
  if (err instanceof HttpsError) throw err;
  switch (authErrorCode(err)) {
    case "auth/email-already-exists":
      throw new HttpsError("already-exists", "A user with this email already exists.");
    case "auth/user-not-found":
      throw new HttpsError("not-found", "No user with this uid exists.");
    case "auth/invalid-email":
    case "auth/invalid-password":
    case "auth/invalid-display-name":
      throw new HttpsError("invalid-argument", (err as Error).message);
    default:
      throw new HttpsError("internal", (err as Error)?.message ?? "Auth operation failed.");
  }
}

// ---------------------------------------------------------------------------
// Doctor link (Phase 2, FIREBASE_ARCHITECTURE.md §4.5)
// ---------------------------------------------------------------------------

/** Read-only pre-check so createUser can fail before creating the Auth user. */
export async function assertDoctorLinkable(
  db: Firestore,
  doctorId: string,
  uid: string | null
): Promise<void> {
  const snap = await db.doc(`doctors/${doctorId}`).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "No doctor record with this id exists.");
  }
  const linked = snap.get("userId");
  if (typeof linked === "string" && linked.length > 0 && linked !== uid) {
    throw new HttpsError("already-exists", "This doctor is already linked to another login.");
  }
}

/**
 * Keeps `doctors/{id}.userId` in step with `users/{uid}.doctorId`.
 * One login per doctor: linking a doctor already linked to another login is
 * refused with `already-exists`; a missing doctor is `not-found`. The old
 * doctor of this login, if any, is unlinked in the same transaction.
 */
export async function syncDoctorLink(
  db: Firestore,
  uid: string,
  callerUid: string,
  previousDoctorId: string | null,
  nextDoctorId: string | null
): Promise<void> {
  if (previousDoctorId === nextDoctorId) return;
  await db.runTransaction(async (tx) => {
    const stamp = { updatedAt: FieldValue.serverTimestamp(), updatedBy: callerUid };
    // All reads first: Firestore transactions refuse a read after a write.
    const nextRef = nextDoctorId === null ? null : db.doc(`doctors/${nextDoctorId}`);
    const prevRef =
      previousDoctorId === null ? null : db.doc(`doctors/${previousDoctorId}`);
    const nextSnap = nextRef === null ? null : await tx.get(nextRef);
    const prevSnap = prevRef === null ? null : await tx.get(prevRef);

    if (nextRef !== null && nextSnap !== null) {
      if (!nextSnap.exists) {
        throw new HttpsError("not-found", "No doctor record with this id exists.");
      }
      const linked = nextSnap.get("userId");
      if (typeof linked === "string" && linked.length > 0 && linked !== uid) {
        throw new HttpsError(
          "already-exists",
          "This doctor is already linked to another login."
        );
      }
      tx.set(nextRef, { userId: uid, ...stamp }, { merge: true });
    }
    if (prevRef !== null && prevSnap !== null) {
      if (prevSnap.exists && prevSnap.get("userId") === uid) {
        tx.set(prevRef, { userId: null, ...stamp }, { merge: true });
      }
    }
  });
}

// ---------------------------------------------------------------------------
// createUser
// ---------------------------------------------------------------------------

export async function createUserCore(
  deps: Deps,
  callerUid: string,
  callerClaims: Claims,
  data: unknown
): Promise<{ uid: string }> {
  requireAdmin(callerClaims);
  const input = validateCreateUserInput(data);

  // Fail before touching Auth when the doctor record is missing or taken.
  if (input.doctorId !== null) {
    await assertDoctorLinkable(deps.db, input.doctorId, null);
  }

  let uid: string;
  try {
    const user = await deps.auth.createUser({
      email: input.email,
      password: input.temporaryPassword,
      displayName: input.displayName,
    });
    uid = user.uid;
  } catch (err) {
    mapAuthError(err);
  }

  const claims: UserClaims = {
    roles: input.roles,
    doctorId: input.doctorId,
    branchIds: DEFAULT_BRANCH_IDS,
  };

  try {
    await deps.auth.setCustomUserClaims(uid, claims);
    await deps.db.doc(`users/${uid}`).set({
      email: input.email,
      displayName: input.displayName,
      roles: input.roles,
      doctorId: input.doctorId,
      active: true,
      branchIds: DEFAULT_BRANCH_IDS,
      mustChangePassword: true,
      createdAt: FieldValue.serverTimestamp(),
      createdBy: callerUid,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: callerUid,
    });
  } catch (err) {
    // Do not leave an Auth account without a users doc behind.
    await deps.auth.deleteUser(uid).catch(() => undefined);
    throw new HttpsError("internal", (err as Error)?.message ?? "Failed to write user.");
  }

  if (input.doctorId !== null) {
    try {
      await syncDoctorLink(deps.db, uid, callerUid, null, input.doctorId);
    } catch (err) {
      await deps.db.doc(`users/${uid}`).delete().catch(() => undefined);
      await deps.auth.deleteUser(uid).catch(() => undefined);
      throw err;
    }
  }

  return { uid };
}

// ---------------------------------------------------------------------------
// setUserRoles
// ---------------------------------------------------------------------------

export async function setUserRolesCore(
  deps: Deps,
  callerUid: string,
  callerClaims: Claims,
  data: unknown
): Promise<{ ok: true }> {
  requireAdmin(callerClaims);
  const input = validateSetUserRolesInput(data);

  if (input.uid === callerUid) {
    if (input.roles !== undefined && !input.roles.includes("admin")) {
      throw new HttpsError(
        "failed-precondition",
        "You cannot remove the admin role from your own account."
      );
    }
    if (input.active === false) {
      throw new HttpsError("failed-precondition", "You cannot deactivate your own account.");
    }
  }

  let current;
  try {
    current = await deps.auth.getUser(input.uid);
  } catch (err) {
    mapAuthError(err);
  }
  const currentClaims = current.customClaims as Claims;

  const roles = input.roles ?? rolesFromClaims(currentClaims);
  const previousDoctorId = doctorIdFromClaims(currentClaims);
  const doctorId = input.doctorId !== undefined ? input.doctorId : previousDoctorId;
  if (roles.includes("doctor") && doctorId === null) {
    throw new HttpsError("invalid-argument", "doctorId is required when roles include doctor.");
  }

  // Doctor record first: a missing or taken doctor leaves the account untouched.
  await syncDoctorLink(deps.db, input.uid, callerUid, previousDoctorId, doctorId);

  const claims: UserClaims = {
    roles,
    doctorId,
    branchIds: branchIdsFromClaims(currentClaims),
  };

  const docUpdate: Record<string, unknown> = {
    updatedAt: FieldValue.serverTimestamp(),
    updatedBy: callerUid,
  };
  if (input.roles !== undefined) docUpdate.roles = roles;
  if (input.doctorId !== undefined) docUpdate.doctorId = doctorId;
  if (input.displayName !== undefined) docUpdate.displayName = input.displayName;
  if (input.active !== undefined) docUpdate.active = input.active;

  try {
    await deps.auth.setCustomUserClaims(input.uid, claims);
    if (input.active !== undefined || input.displayName !== undefined) {
      await deps.auth.updateUser(input.uid, {
        ...(input.active !== undefined ? { disabled: !input.active } : {}),
        ...(input.displayName !== undefined ? { displayName: input.displayName } : {}),
      });
    }
    await deps.db.doc(`users/${input.uid}`).set(docUpdate, { merge: true });
    if (input.active === false) {
      await deps.auth.revokeRefreshTokens(input.uid);
    }
  } catch (err) {
    mapAuthError(err);
  }

  return { ok: true };
}

// ---------------------------------------------------------------------------
// resetUserPassword
// ---------------------------------------------------------------------------

export async function resetUserPasswordCore(
  deps: Deps,
  callerUid: string,
  callerClaims: Claims,
  data: unknown
): Promise<{ ok: true }> {
  requireAdmin(callerClaims);
  const input = validateResetUserPasswordInput(data);

  try {
    await deps.auth.updateUser(input.uid, { password: input.temporaryPassword });
    await deps.db.doc(`users/${input.uid}`).set(
      {
        mustChangePassword: true,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: callerUid,
      },
      { merge: true }
    );
    await deps.auth.revokeRefreshTokens(input.uid);
  } catch (err) {
    mapAuthError(err);
  }

  return { ok: true };
}

// ---------------------------------------------------------------------------
// onCall wrappers (region/maxInstances come from setGlobalOptions in index.ts)
// ---------------------------------------------------------------------------

type Core<R> = (deps: Deps, callerUid: string, callerClaims: Claims, data: unknown) => Promise<R>;

function wrap<R>(core: Core<R>) {
  return async (request: CallableRequest<unknown>): Promise<R> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const deps: Deps = { auth: getAuth(), db: getFirestore() };
    return core(deps, request.auth.uid, request.auth.token, request.data);
  };
}

export const createUser = onCall(wrap(createUserCore));
export const setUserRoles = onCall(wrap(setUserRolesCore));
export const resetUserPassword = onCall(wrap(resetUserPasswordCore));

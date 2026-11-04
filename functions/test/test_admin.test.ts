// Runs against the Auth + Firestore emulators (env set in test/setup.ts).
import { initializeApp, getApps } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { createTestAdminCore, TEST_ADMIN } from "../src/test_admin";
import type { Deps } from "../src/users";

const PROJECT_ID = "ramzan-clinic-web";

let deps: Deps;

async function clearEmulators() {
  const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const fsHost = process.env.FIRESTORE_EMULATOR_HOST;
  await fetch(`http://${authHost}/emulator/v1/projects/${PROJECT_ID}/accounts`, {
    method: "DELETE",
  });
  await fetch(
    `http://${fsHost}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
    { method: "DELETE" }
  );
}

beforeAll(() => {
  if (getApps().length === 0) initializeApp({ projectId: PROJECT_ID });
  deps = { auth: getAuth(), db: getFirestore() };
});

beforeEach(clearEmulators);

describe("createTestAdminCore", () => {
  it("uses the fixed test credentials", () => {
    expect(TEST_ADMIN.email).toBe("admin@mytester.com");
    expect(TEST_ADMIN.password).toBe("1234567890");
  });

  it("creates the admin account, claims and users doc when missing", async () => {
    const result = await createTestAdminCore(deps, true);

    expect(result.created).toBe(true);
    const user = await deps.auth.getUserByEmail(TEST_ADMIN.email);
    expect(user.uid).toBe(result.uid);
    expect(user.disabled).toBe(false);
    expect(user.customClaims).toEqual({ roles: ["admin"], doctorId: null, branchIds: ["main"] });
    const doc = (await deps.db.doc(`users/${result.uid}`).get()).data();
    expect(doc).toMatchObject({
      email: TEST_ADMIN.email,
      displayName: TEST_ADMIN.displayName,
      roles: ["admin"],
      doctorId: null,
      active: true,
      branchIds: ["main"],
      mustChangePassword: false,
    });
  });

  it("is repeatable: restores an existing, disabled or demoted account", async () => {
    const first = await createTestAdminCore(deps, true);
    await deps.auth.updateUser(first.uid, { disabled: true, password: "Changed123" });
    await deps.auth.setCustomUserClaims(first.uid, { roles: ["reception"] });
    await deps.db.doc(`users/${first.uid}`).set({ active: false, roles: ["reception"] }, { merge: true });

    const second = await createTestAdminCore(deps, true);

    expect(second).toEqual({ uid: first.uid, created: false });
    const user = await deps.auth.getUser(first.uid);
    expect(user.disabled).toBe(false);
    expect(user.customClaims).toEqual({ roles: ["admin"], doctorId: null, branchIds: ["main"] });
    const doc = (await deps.db.doc(`users/${first.uid}`).get()).data();
    expect(doc).toMatchObject({ roles: ["admin"], active: true, mustChangePassword: false });
    // The password is back to the fixed one: the Auth emulator accepts it.
    const res = await fetch(
      `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake`,
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          email: TEST_ADMIN.email,
          password: TEST_ADMIN.password,
          returnSecureToken: true,
        }),
      }
    );
    expect(res.status).toBe(200);
  });

  it("refuses when the switch is off and creates nothing", async () => {
    let caught: unknown;
    try {
      await createTestAdminCore(deps, false);
    } catch (e) {
      caught = e;
    }
    expect(caught).toBeInstanceOf(HttpsError);
    expect((caught as HttpsError).code).toBe("failed-precondition");
    await expect(deps.auth.getUserByEmail(TEST_ADMIN.email)).rejects.toBeDefined();
  });
});

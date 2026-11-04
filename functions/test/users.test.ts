// Runs against the Auth + Firestore emulators (env set in test/setup.ts).
import { initializeApp, getApps } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import {
  createUserCore,
  setUserRolesCore,
  resetUserPasswordCore,
  type Deps,
} from "../src/users";

const PROJECT_ID = "ramzan-clinic-web";
const ADMIN_UID = "admin-caller";
const ADMIN_CLAIMS = { roles: ["admin"], doctorId: null, branchIds: ["main"] };
const RECEPTION_CLAIMS = { roles: ["reception"], doctorId: null, branchIds: ["main"] };

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

async function expectHttpsError(p: Promise<unknown>, code: string) {
  let caught: unknown;
  try {
    await p;
  } catch (e) {
    caught = e;
  }
  expect(caught).toBeInstanceOf(HttpsError);
  expect((caught as HttpsError).code).toBe(code);
}

async function seedDoctor(id: string, userId: string | null = null) {
  await deps.db.doc(`doctors/${id}`).set({
    userId,
    name: `Dr ${id}`,
    departmentId: "eye",
    departmentCode: "E",
    specialisation: "",
    salary: 0,
    sharePercent: 0,
    shareBasis: "gross",
    fees: {},
    active: true,
    branchId: "main",
  });
}

const receptionInput = {
  email: "reception@clinic.pk",
  displayName: "Reception One",
  roles: ["reception"],
  temporaryPassword: "Temp12345",
};

beforeAll(() => {
  if (getApps().length === 0) initializeApp({ projectId: PROJECT_ID });
  deps = { auth: getAuth(), db: getFirestore() };
});

beforeEach(async () => {
  await clearEmulators();
  // The admin caller exists as a real Auth user so self-targeting tests work.
  await deps.auth.createUser({ uid: ADMIN_UID, email: "admin@clinic.pk", password: "Admin12345" });
  await deps.auth.setCustomUserClaims(ADMIN_UID, ADMIN_CLAIMS);
  await deps.db.doc(`users/${ADMIN_UID}`).set({
    email: "admin@clinic.pk",
    displayName: "Admin",
    roles: ["admin"],
    doctorId: null,
    active: true,
    branchIds: ["main"],
    mustChangePassword: false,
  });
});

describe("createUserCore", () => {
  it("creates the Auth user, sets claims and writes users/{uid}", async () => {
    await seedDoctor("doc-1");
    const { uid } = await createUserCore(deps, ADMIN_UID, ADMIN_CLAIMS, {
      ...receptionInput,
      roles: ["doctor", "reception"],
      doctorId: "doc-1",
    });

    const user = await deps.auth.getUser(uid);
    expect(user.email).toBe("reception@clinic.pk");
    expect(user.displayName).toBe("Reception One");
    expect(user.disabled).toBe(false);
    expect(user.customClaims).toEqual({
      roles: ["doctor", "reception"],
      doctorId: "doc-1",
      branchIds: ["main"],
    });

    const snap = await deps.db.doc(`users/${uid}`).get();
    expect(snap.exists).toBe(true);
    const doc = snap.data()!;
    expect(doc).toMatchObject({
      email: "reception@clinic.pk",
      displayName: "Reception One",
      roles: ["doctor", "reception"],
      doctorId: "doc-1",
      active: true,
      branchIds: ["main"],
      mustChangePassword: true,
      createdBy: ADMIN_UID,
      updatedBy: ADMIN_UID,
    });
    expect(doc.createdAt).toBeDefined();
    expect(doc.updatedAt).toBeDefined();
    // The doctor record points back at the new login.
    expect((await deps.db.doc("doctors/doc-1").get()).get("userId")).toBe(uid);
  });

  it("refuses a missing or already linked doctor without creating an account", async () => {
    await expectHttpsError(
      createUserCore(deps, ADMIN_UID, ADMIN_CLAIMS, {
        ...receptionInput,
        roles: ["doctor"],
        doctorId: "ghost",
      }),
      "not-found"
    );
    await seedDoctor("doc-taken", "someone-else");
    await expectHttpsError(
      createUserCore(deps, ADMIN_UID, ADMIN_CLAIMS, {
        ...receptionInput,
        roles: ["doctor"],
        doctorId: "doc-taken",
      }),
      "already-exists"
    );
    expect((await deps.auth.listUsers()).users.map((u) => u.uid)).toEqual([ADMIN_UID]);
    expect((await deps.db.doc("doctors/doc-taken").get()).get("userId")).toBe("someone-else");
  });

  it("stores doctorId as null for non-doctors", async () => {
    const { uid } = await createUserCore(deps, ADMIN_UID, ADMIN_CLAIMS, receptionInput);
    const snap = await deps.db.doc(`users/${uid}`).get();
    expect(snap.data()!.doctorId).toBeNull();
    expect((await deps.auth.getUser(uid)).customClaims!.doctorId).toBeNull();
  });

  it("maps a duplicate email to already-exists", async () => {
    await createUserCore(deps, ADMIN_UID, ADMIN_CLAIMS, receptionInput);
    await expectHttpsError(
      createUserCore(deps, ADMIN_UID, ADMIN_CLAIMS, receptionInput),
      "already-exists"
    );
  });

  it("rejects a non-admin caller with permission-denied", async () => {
    await expectHttpsError(
      createUserCore(deps, "someone", RECEPTION_CLAIMS, receptionInput),
      "permission-denied"
    );
    await expectHttpsError(
      createUserCore(deps, "someone", undefined, receptionInput),
      "permission-denied"
    );
    // Nothing was created.
    expect((await deps.auth.listUsers()).users.map((u) => u.uid)).toEqual([ADMIN_UID]);
  });

  it("rejects invalid input with invalid-argument", async () => {
    await expectHttpsError(
      createUserCore(deps, ADMIN_UID, ADMIN_CLAIMS, { ...receptionInput, roles: ["doctor"] }),
      "invalid-argument"
    );
  });
});

describe("setUserRolesCore", () => {
  let uid: string;
  beforeEach(async () => {
    ({ uid } = await createUserCore(deps, ADMIN_UID, ADMIN_CLAIMS, receptionInput));
  });

  it("updates claims and the users doc", async () => {
    await seedDoctor("doc-9");
    const res = await setUserRolesCore(deps, ADMIN_UID, ADMIN_CLAIMS, {
      uid,
      roles: ["doctor"],
      doctorId: "doc-9",
      displayName: "Dr Nine",
    });
    expect(res).toEqual({ ok: true });

    const user = await deps.auth.getUser(uid);
    expect(user.customClaims).toEqual({ roles: ["doctor"], doctorId: "doc-9", branchIds: ["main"] });
    expect(user.displayName).toBe("Dr Nine");

    const doc = (await deps.db.doc(`users/${uid}`).get()).data()!;
    expect(doc).toMatchObject({
      roles: ["doctor"],
      doctorId: "doc-9",
      displayName: "Dr Nine",
      active: true,
      updatedBy: ADMIN_UID,
    });
    // Untouched fields are preserved.
    expect(doc.email).toBe("reception@clinic.pk");
    expect(doc.mustChangePassword).toBe(true);
    expect((await deps.db.doc("doctors/doc-9").get()).get("userId")).toBe(uid);
  });

  it("moving the link unlinks the old doctor, dropping the role clears it", async () => {
    await seedDoctor("doc-a");
    await seedDoctor("doc-b");
    await setUserRolesCore(deps, ADMIN_UID, ADMIN_CLAIMS, { uid, roles: ["doctor"], doctorId: "doc-a" });
    await setUserRolesCore(deps, ADMIN_UID, ADMIN_CLAIMS, { uid, doctorId: "doc-b" });
    expect((await deps.db.doc("doctors/doc-a").get()).get("userId")).toBeNull();
    expect((await deps.db.doc("doctors/doc-b").get()).get("userId")).toBe(uid);
    expect((await deps.auth.getUser(uid)).customClaims!.doctorId).toBe("doc-b");

    await setUserRolesCore(deps, ADMIN_UID, ADMIN_CLAIMS, {
      uid,
      roles: ["reception"],
      doctorId: null,
    });
    expect((await deps.db.doc("doctors/doc-b").get()).get("userId")).toBeNull();
    expect((await deps.auth.getUser(uid)).customClaims!.doctorId).toBeNull();
    expect((await deps.db.doc(`users/${uid}`).get()).get("doctorId")).toBeNull();
  });

  it("refuses a missing or taken doctor and leaves claims untouched", async () => {
    await expectHttpsError(
      setUserRolesCore(deps, ADMIN_UID, ADMIN_CLAIMS, { uid, roles: ["doctor"], doctorId: "ghost" }),
      "not-found"
    );
    await seedDoctor("doc-taken", "other-login");
    await expectHttpsError(
      setUserRolesCore(deps, ADMIN_UID, ADMIN_CLAIMS, { uid, roles: ["doctor"], doctorId: "doc-taken" }),
      "already-exists"
    );
    const user = await deps.auth.getUser(uid);
    expect(user.customClaims).toEqual({ roles: ["reception"], doctorId: null, branchIds: ["main"] });
    expect((await deps.db.doc("doctors/doc-taken").get()).get("userId")).toBe("other-login");
  });

  it("keeps existing claims when only some fields change", async () => {
    await setUserRolesCore(deps, ADMIN_UID, ADMIN_CLAIMS, { uid, displayName: "Renamed" });
    const user = await deps.auth.getUser(uid);
    expect(user.customClaims).toEqual({ roles: ["reception"], doctorId: null, branchIds: ["main"] });
  });

  it("deactivation disables the Auth account and sets active=false", async () => {
    await setUserRolesCore(deps, ADMIN_UID, ADMIN_CLAIMS, { uid, active: false });
    const user = await deps.auth.getUser(uid);
    expect(user.disabled).toBe(true);
    expect(user.tokensValidAfterTime).toBeDefined();
    expect((await deps.db.doc(`users/${uid}`).get()).data()!.active).toBe(false);

    await setUserRolesCore(deps, ADMIN_UID, ADMIN_CLAIMS, { uid, active: true });
    expect((await deps.auth.getUser(uid)).disabled).toBe(false);
    expect((await deps.db.doc(`users/${uid}`).get()).data()!.active).toBe(true);
  });

  it("admin cannot deactivate self", async () => {
    await expectHttpsError(
      setUserRolesCore(deps, ADMIN_UID, ADMIN_CLAIMS, { uid: ADMIN_UID, active: false }),
      "failed-precondition"
    );
    expect((await deps.auth.getUser(ADMIN_UID)).disabled).toBe(false);
  });

  it("admin cannot drop own admin role", async () => {
    await expectHttpsError(
      setUserRolesCore(deps, ADMIN_UID, ADMIN_CLAIMS, { uid: ADMIN_UID, roles: ["reception"] }),
      "failed-precondition"
    );
    // Keeping admin in the list is fine.
    await setUserRolesCore(deps, ADMIN_UID, ADMIN_CLAIMS, {
      uid: ADMIN_UID,
      roles: ["admin", "reception"],
    });
    expect((await deps.auth.getUser(ADMIN_UID)).customClaims!.roles).toEqual(["admin", "reception"]);
  });

  it("requires doctorId when granting the doctor role", async () => {
    await expectHttpsError(
      setUserRolesCore(deps, ADMIN_UID, ADMIN_CLAIMS, { uid, roles: ["doctor"] }),
      "invalid-argument"
    );
  });

  it("rejects a non-admin caller and unknown uid", async () => {
    await expectHttpsError(
      setUserRolesCore(deps, uid, RECEPTION_CLAIMS, { uid, active: false }),
      "permission-denied"
    );
    await expectHttpsError(
      setUserRolesCore(deps, ADMIN_UID, ADMIN_CLAIMS, { uid: "nope", active: false }),
      "not-found"
    );
  });
});

describe("resetUserPasswordCore", () => {
  it("sets the password, flags mustChangePassword and revokes tokens", async () => {
    const { uid } = await createUserCore(deps, ADMIN_UID, ADMIN_CLAIMS, receptionInput);
    await deps.db.doc(`users/${uid}`).update({ mustChangePassword: false });
    const before = (await deps.auth.getUser(uid)).passwordHash;

    const res = await resetUserPasswordCore(deps, ADMIN_UID, ADMIN_CLAIMS, {
      uid,
      temporaryPassword: "NewTemp9876",
    });
    expect(res).toEqual({ ok: true });

    const user = await deps.auth.getUser(uid);
    expect(user.passwordHash).not.toBe(before);
    expect(user.tokensValidAfterTime).toBeDefined();
    const doc = (await deps.db.doc(`users/${uid}`).get()).data()!;
    expect(doc.mustChangePassword).toBe(true);
    expect(doc.updatedBy).toBe(ADMIN_UID);
  });

  it("rejects non-admin and short passwords", async () => {
    await expectHttpsError(
      resetUserPasswordCore(deps, "x", RECEPTION_CLAIMS, { uid: ADMIN_UID, temporaryPassword: "Temp12345" }),
      "permission-denied"
    );
    await expectHttpsError(
      resetUserPasswordCore(deps, ADMIN_UID, ADMIN_CLAIMS, { uid: ADMIN_UID, temporaryPassword: "short" }),
      "invalid-argument"
    );
  });
});

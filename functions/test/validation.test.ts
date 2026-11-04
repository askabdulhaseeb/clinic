import { HttpsError } from "firebase-functions/v2/https";
import {
  validateCreateUserInput,
  validateSetUserRolesInput,
  validateResetUserPasswordInput,
  validateEmail,
  validateDisplayName,
  validateRoles,
  validateTemporaryPassword,
  validateDoctorId,
  validateUid,
  validateActive,
} from "../src/validation";

function expectInvalid(fn: () => unknown, messagePart?: string) {
  let caught: unknown;
  try {
    fn();
  } catch (e) {
    caught = e;
  }
  expect(caught).toBeInstanceOf(HttpsError);
  expect((caught as HttpsError).code).toBe("invalid-argument");
  if (messagePart) expect((caught as HttpsError).message).toContain(messagePart);
}

describe("validateEmail", () => {
  it("accepts and normalises a valid email", () => {
    expect(validateEmail("  Admin@Clinic.PK ")).toBe("admin@clinic.pk");
  });
  it.each(["", "nope", "a@b", "a b@c.com", 42, null, undefined])(
    "rejects %p",
    (v) => expectInvalid(() => validateEmail(v), "email")
  );
});

describe("validateDisplayName", () => {
  it("trims a valid name", () => {
    expect(validateDisplayName("  Dr Ali ")).toBe("Dr Ali");
  });
  it.each(["", "   ", 1, null, undefined])("rejects %p", (v) =>
    expectInvalid(() => validateDisplayName(v), "displayName")
  );
});

describe("validateRoles", () => {
  it("accepts a subset of the three roles and de-duplicates", () => {
    expect(validateRoles(["admin", "doctor", "admin"])).toEqual(["admin", "doctor"]);
    expect(validateRoles(["reception"])).toEqual(["reception"]);
  });
  it.each([[], "admin", ["owner"], ["admin", "nurse"], [1], null, undefined])(
    "rejects %p",
    (v) => expectInvalid(() => validateRoles(v), "roles")
  );
});

describe("validateTemporaryPassword", () => {
  it("accepts 8+ characters", () => {
    expect(validateTemporaryPassword("12345678")).toBe("12345678");
  });
  it.each(["1234567", "", 12345678, null, undefined])("rejects %p", (v) =>
    expectInvalid(() => validateTemporaryPassword(v), "temporaryPassword")
  );
});

describe("validateDoctorId", () => {
  it("requires doctorId when roles include doctor", () => {
    expectInvalid(() => validateDoctorId(undefined, ["doctor"]), "doctorId");
    expectInvalid(() => validateDoctorId(null, ["doctor", "admin"]), "doctorId");
    expect(validateDoctorId("doc1", ["doctor"])).toBe("doc1");
  });
  it("allows null/undefined when not a doctor", () => {
    expect(validateDoctorId(undefined, ["admin"])).toBeNull();
    expect(validateDoctorId(null, ["reception"])).toBeNull();
  });
  it("rejects non-string or empty doctorId", () => {
    expectInvalid(() => validateDoctorId("", ["doctor"]), "doctorId");
    expectInvalid(() => validateDoctorId(7, ["admin"]), "doctorId");
  });
});

describe("validateUid / validateActive", () => {
  it("accepts a uid and a boolean", () => {
    expect(validateUid("abc")).toBe("abc");
    expect(validateActive(false)).toBe(false);
  });
  it("rejects bad values", () => {
    expectInvalid(() => validateUid(""), "uid");
    expectInvalid(() => validateUid(undefined), "uid");
    expectInvalid(() => validateActive("true"), "active");
  });
});

describe("validateCreateUserInput", () => {
  const good = {
    email: "r@clinic.pk",
    displayName: "Reception One",
    roles: ["reception"],
    temporaryPassword: "Temp12345",
  };
  it("returns typed data with doctorId defaulting to null", () => {
    expect(validateCreateUserInput(good)).toEqual({ ...good, doctorId: null });
  });
  it("keeps doctorId for doctors", () => {
    const out = validateCreateUserInput({ ...good, roles: ["doctor"], doctorId: "d1" });
    expect(out.doctorId).toBe("d1");
  });
  it("rejects non-object payloads", () => {
    expectInvalid(() => validateCreateUserInput(null));
    expectInvalid(() => validateCreateUserInput([]));
    expectInvalid(() => validateCreateUserInput("x"));
  });
  it("rejects each bad field", () => {
    expectInvalid(() => validateCreateUserInput({ ...good, email: "bad" }), "email");
    expectInvalid(() => validateCreateUserInput({ ...good, displayName: "" }), "displayName");
    expectInvalid(() => validateCreateUserInput({ ...good, roles: [] }), "roles");
    expectInvalid(() => validateCreateUserInput({ ...good, roles: ["doctor"] }), "doctorId");
    expectInvalid(
      () => validateCreateUserInput({ ...good, temporaryPassword: "short" }),
      "temporaryPassword"
    );
  });
});

describe("validateSetUserRolesInput", () => {
  it("accepts any subset of optional fields", () => {
    expect(validateSetUserRolesInput({ uid: "u1", active: false })).toEqual({
      uid: "u1",
      active: false,
    });
    expect(
      validateSetUserRolesInput({ uid: "u1", roles: ["doctor"], doctorId: "d1", displayName: "X" })
    ).toEqual({ uid: "u1", roles: ["doctor"], doctorId: "d1", displayName: "X" });
    expect(validateSetUserRolesInput({ uid: "u1", doctorId: null })).toEqual({
      uid: "u1",
      doctorId: null,
    });
  });
  it("requires uid and at least one field", () => {
    expectInvalid(() => validateSetUserRolesInput({ roles: ["admin"] }), "uid");
    expectInvalid(() => validateSetUserRolesInput({ uid: "u1" }), "At least one");
  });
  it("rejects bad optional fields", () => {
    expectInvalid(() => validateSetUserRolesInput({ uid: "u1", roles: ["x"] }), "roles");
    expectInvalid(() => validateSetUserRolesInput({ uid: "u1", doctorId: "" }), "doctorId");
    expectInvalid(() => validateSetUserRolesInput({ uid: "u1", displayName: " " }), "displayName");
    expectInvalid(() => validateSetUserRolesInput({ uid: "u1", active: 1 }), "active");
  });
});

describe("validateResetUserPasswordInput", () => {
  it("accepts uid + password", () => {
    expect(validateResetUserPasswordInput({ uid: "u1", temporaryPassword: "Temp12345" })).toEqual({
      uid: "u1",
      temporaryPassword: "Temp12345",
    });
  });
  it("rejects missing fields", () => {
    expectInvalid(() => validateResetUserPasswordInput({ temporaryPassword: "Temp12345" }), "uid");
    expectInvalid(() => validateResetUserPasswordInput({ uid: "u1" }), "temporaryPassword");
  });
});

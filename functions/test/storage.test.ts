// Storage rules (FIREBASE_ARCHITECTURE.md §7): clinic logo (Phase 2) and
// patient report files (Phase 5B). Runs against the Storage emulator on 9199.
import * as fs from "node:fs";
import * as path from "node:path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "ramzan-clinic-web";
const adminToken = { roles: ["admin"], doctorId: null, branchIds: ["main"] };
const receptionToken = { roles: ["reception"], doctorId: null, branchIds: ["main"] };
const doctorToken = { roles: ["doctor"], doctorId: "d1", branchIds: ["main"] };

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    storage: {
      rules: fs.readFileSync(path.resolve(__dirname, "../../storage.rules"), "utf8"),
      host: "127.0.0.1",
      port: 9199,
    },
  });
});

afterAll(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearStorage();
});

const pdf = new Uint8Array([0x25, 0x50, 0x44, 0x46, 0x2d]); // %PDF-
const asReception = () => env.authenticatedContext("alice-uid", receptionToken).storage();
const asAdmin = () => env.authenticatedContext("admin-uid", adminToken).storage();
const asDoctor = () => env.authenticatedContext("doctor-uid", doctorToken).storage();
const asAnon = () => env.unauthenticatedContext().storage();

describe("patient report files", () => {
  const file = "patients/p1/reports/r1.pdf";
  it("reception and admin upload PDF, JPEG and PNG under the patient's folder", async () => {
    await assertSucceeds(asReception().ref(file).put(pdf, { contentType: "application/pdf" }));
    await assertSucceeds(
      asAdmin().ref("patients/p1/reports/r2.jpg").put(pdf, { contentType: "image/jpeg" })
    );
    await assertSucceeds(
      asReception().ref("patients/p1/reports/r3.png").put(pdf, { contentType: "image/png" })
    );
  });
  it("any signed-in user reads; anonymous cannot", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage().ref(file).put(pdf, { contentType: "application/pdf" });
    });
    await assertSucceeds(asDoctor().ref(file).getDownloadURL());
    await assertFails(asAnon().ref(file).getDownloadURL());
  });
  it("doctor, anonymous, other types and oversize files are refused", async () => {
    await assertFails(asDoctor().ref(file).put(pdf, { contentType: "application/pdf" }));
    await assertFails(asAnon().ref(file).put(pdf, { contentType: "application/pdf" }));
    await assertFails(asReception().ref("patients/p1/reports/r1.gif").put(pdf, { contentType: "image/gif" }));
    await assertFails(asReception().ref("patients/p1/reports/r1.txt").put(pdf, { contentType: "text/plain" }));
    await assertFails(
      asReception().ref(file).put(new Uint8Array(10 * 1024 * 1024 + 1), { contentType: "application/pdf" })
    );
  });
  it("files are never deleted from the client and other paths stay closed", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage().ref(file).put(pdf, { contentType: "application/pdf" });
    });
    await assertFails(asAdmin().ref(file).delete());
    await assertFails(asReception().ref("patients/p1/other/x.pdf").put(pdf, { contentType: "application/pdf" }));
    await assertFails(asAdmin().ref("misc/x.pdf").put(pdf, { contentType: "application/pdf" }));
  });
});

describe("clinic logo", () => {
  it("admin writes an image, reception reads, reception cannot write", async () => {
    await assertSucceeds(asAdmin().ref("clinic/logo.png").put(pdf, { contentType: "image/png" }));
    await assertSucceeds(asReception().ref("clinic/logo.png").getDownloadURL());
    await assertFails(asReception().ref("clinic/logo.png").put(pdf, { contentType: "image/png" }));
    await assertFails(asAdmin().ref("clinic/logo.png").put(pdf, { contentType: "application/pdf" }));
  });
});

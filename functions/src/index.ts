import { setGlobalOptions } from "firebase-functions/v2";
import { initializeApp } from "firebase-admin/app";

// All functions run in Mumbai next to Firestore (FIREBASE_ARCHITECTURE.md §1).
setGlobalOptions({ region: "asia-south1", maxInstances: 10 });

initializeApp();

// Phase 1: createUser, setUserRoles, resetUserPassword (users.ts)
// Phase 3: assignPatientNo, checkDuplicateFamilyPhone (patients.ts, families.ts)
// Phase 8: applyDailySummaryDelta, recomputeDay (summaries.ts)
// Phase 9: audit*                              (audit.ts)
export { createUser, setUserRoles, resetUserPassword } from "./users";
export { assignPatientNo } from "./patients";
export { checkDuplicateFamilyPhone } from "./families";
// Development helper, enabled by ALLOW_TEST_ADMIN in functions/.env (test_admin.ts)
export { createTestAdmin } from "./test_admin";

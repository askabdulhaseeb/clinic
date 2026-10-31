import { setGlobalOptions } from "firebase-functions/v2";
import { initializeApp } from "firebase-admin/app";

// All functions run in Mumbai next to Firestore and Storage (FIREBASE_ARCHITECTURE.md §1).
setGlobalOptions({ region: "asia-south1", maxInstances: 10 });

initializeApp();

// Phase 1: createUser, setUserRoles            (users.ts)
// Phase 3: assignPatientNo, checkDuplicateFamilyPhone (patients.ts, families.ts)
// Phase 8: recomputeDailySummary               (summaries.ts)
// Phase 9: audit*, dailyBackup                 (audit.ts, backup.ts)
export {};

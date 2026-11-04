// Jest setup: point firebase-admin and the client SDKs at the local emulators.
// Ports match firebase.json; the project id matches .firebaserc.
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= "127.0.0.1:9099";
process.env.FIRESTORE_EMULATOR_HOST ??= "127.0.0.1:8080";
process.env.GCLOUD_PROJECT ??= "ramzan-clinic-web";

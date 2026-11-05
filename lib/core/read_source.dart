/// Where a one-shot read is answered from (FIREBASE_ARCHITECTURE §9).
///
/// [cache] costs nothing and returns only what this device has seen;
/// [server] is billed per document and, when offline, falls back to the
/// cache like any Firestore read.
enum ReadSource { cache, server }

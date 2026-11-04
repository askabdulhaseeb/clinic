import { HttpsError } from "firebase-functions/v2/https";

// Pure input validators for the Phase 1 callables (FIREBASE_ARCHITECTURE.md §5).
// Each takes the raw `request.data` (unknown) and returns typed data, or throws
// HttpsError("invalid-argument") with a message that names the offending field.

export const ROLES = ["reception", "doctor", "admin"] as const;
export type Role = (typeof ROLES)[number];

export const MIN_PASSWORD_LENGTH = 8;

// Simple, permissive email shape check: something@something.tld, no spaces.
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export interface CreateUserInput {
  email: string;
  displayName: string;
  roles: Role[];
  doctorId: string | null;
  temporaryPassword: string;
}

export interface SetUserRolesInput {
  uid: string;
  roles?: Role[];
  doctorId?: string | null;
  displayName?: string;
  active?: boolean;
}

export interface ResetUserPasswordInput {
  uid: string;
  temporaryPassword: string;
}

function invalid(message: string): HttpsError {
  return new HttpsError("invalid-argument", message);
}

function asRecord(data: unknown): Record<string, unknown> {
  if (typeof data !== "object" || data === null || Array.isArray(data)) {
    throw invalid("Request data must be an object.");
  }
  return data as Record<string, unknown>;
}

export function validateEmail(value: unknown): string {
  if (typeof value !== "string" || !EMAIL_RE.test(value.trim())) {
    throw invalid("email must be a valid email address.");
  }
  return value.trim().toLowerCase();
}

export function validateDisplayName(value: unknown): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw invalid("displayName must be a non-empty string.");
  }
  return value.trim();
}

export function validateRoles(value: unknown): Role[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw invalid("roles must be a non-empty array.");
  }
  const roles: Role[] = [];
  for (const r of value) {
    if (typeof r !== "string" || !(ROLES as readonly string[]).includes(r)) {
      throw invalid(`roles may only contain ${ROLES.join(", ")}.`);
    }
    if (!roles.includes(r as Role)) roles.push(r as Role);
  }
  return roles;
}

export function validateTemporaryPassword(value: unknown): string {
  if (typeof value !== "string" || value.length < MIN_PASSWORD_LENGTH) {
    throw invalid(
      `temporaryPassword must be at least ${MIN_PASSWORD_LENGTH} characters.`
    );
  }
  return value;
}

export function validateUid(value: unknown): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw invalid("uid must be a non-empty string.");
  }
  return value;
}

/**
 * doctorId is required (non-empty string) when roles include "doctor";
 * otherwise it may be omitted or null. Returns the normalised value.
 */
export function validateDoctorId(value: unknown, roles: Role[]): string | null {
  const isDoctor = roles.includes("doctor");
  if (value === undefined || value === null) {
    if (isDoctor) throw invalid("doctorId is required when roles include doctor.");
    return null;
  }
  if (typeof value !== "string" || value.trim().length === 0) {
    throw invalid("doctorId must be a non-empty string or null.");
  }
  return value;
}

export function validateActive(value: unknown): boolean {
  if (typeof value !== "boolean") {
    throw invalid("active must be a boolean.");
  }
  return value;
}

export function validateCreateUserInput(data: unknown): CreateUserInput {
  const d = asRecord(data);
  const roles = validateRoles(d.roles);
  return {
    email: validateEmail(d.email),
    displayName: validateDisplayName(d.displayName),
    roles,
    doctorId: validateDoctorId(d.doctorId, roles),
    temporaryPassword: validateTemporaryPassword(d.temporaryPassword),
  };
}

/**
 * At least one of roles, doctorId, displayName, active must be supplied.
 * doctorId/roles consistency is checked against the *effective* roles in
 * users.ts because the current roles may live only in the stored claims.
 */
export function validateSetUserRolesInput(data: unknown): SetUserRolesInput {
  const d = asRecord(data);
  const out: SetUserRolesInput = { uid: validateUid(d.uid) };
  if (d.roles !== undefined) out.roles = validateRoles(d.roles);
  if (d.displayName !== undefined) out.displayName = validateDisplayName(d.displayName);
  if (d.active !== undefined) out.active = validateActive(d.active);
  if (d.doctorId !== undefined) {
    if (d.doctorId !== null && (typeof d.doctorId !== "string" || d.doctorId.trim() === "")) {
      throw invalid("doctorId must be a non-empty string or null.");
    }
    out.doctorId = d.doctorId as string | null;
  }
  if (
    out.roles === undefined &&
    out.displayName === undefined &&
    out.active === undefined &&
    out.doctorId === undefined
  ) {
    throw invalid("At least one of roles, doctorId, displayName, active is required.");
  }
  return out;
}

export function validateResetUserPasswordInput(data: unknown): ResetUserPasswordInput {
  const d = asRecord(data);
  return {
    uid: validateUid(d.uid),
    temporaryPassword: validateTemporaryPassword(d.temporaryPassword),
  };
}

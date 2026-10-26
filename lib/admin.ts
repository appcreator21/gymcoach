import { db } from '@/lib/db';
import { ApiError, requireApiUserId } from '@/lib/api';

// Admin access. A user is an admin when their stored role is ADMIN, or when
// their email is listed in ADMIN_EMAILS (comma separated, case-insensitive).
// The check always reads the database, never the JWT claims, so a demotion
// takes effect immediately.

export function adminEmailList(env: NodeJS.ProcessEnv = process.env): string[] {
  return (env.ADMIN_EMAILS ?? '')
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
}

export function isAdmin(
  user: { email: string; role: string },
  env: NodeJS.ProcessEnv = process.env,
): boolean {
  return user.role === 'ADMIN' || adminEmailList(env).includes(user.email.toLowerCase());
}

// For the admin API routes: 401 without a session, 403 for a non-admin.
export async function requireAdminUserId(): Promise<string> {
  const userId = await requireApiUserId();
  const user = await db.user.findUnique({
    where: { id: userId },
    select: { email: true, role: true },
  });
  if (!user || !isAdmin(user)) {
    throw new ApiError(403, 'Admin access required.');
  }
  return userId;
}

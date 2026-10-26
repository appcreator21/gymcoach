import { describe, it, expect } from 'vitest';
import { adminEmailList, isAdmin } from './admin';

describe('adminEmailList', () => {
  it('parses a comma separated list, trimmed and lower-cased', () => {
    expect(adminEmailList({ ADMIN_EMAILS: ' A@x.com, b@y.com ,, ' } as unknown as NodeJS.ProcessEnv)).toEqual([
      'a@x.com',
      'b@y.com',
    ]);
  });

  it('is empty when unset', () => {
    expect(adminEmailList({} as NodeJS.ProcessEnv)).toEqual([]);
  });
});

describe('isAdmin', () => {
  const none = {} as NodeJS.ProcessEnv;

  it('accepts the ADMIN role', () => {
    expect(isAdmin({ email: 'a@x.com', role: 'ADMIN' }, none)).toBe(true);
  });

  it('rejects a plain user', () => {
    expect(isAdmin({ email: 'a@x.com', role: 'USER' }, none)).toBe(false);
  });

  it('accepts an email from ADMIN_EMAILS regardless of case', () => {
    const env = { ADMIN_EMAILS: 'boss@x.com' } as unknown as NodeJS.ProcessEnv;
    expect(isAdmin({ email: 'Boss@X.com', role: 'USER' }, env)).toBe(true);
  });
});

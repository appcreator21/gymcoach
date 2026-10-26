import { describe, it, expect } from 'vitest';
import { announcementInputSchema } from './announcement';

describe('announcementInputSchema', () => {
  it('trims and defaults pinned to false', () => {
    const r = announcementInputSchema.parse({ title: '  Hi ', body: ' Welcome ' });
    expect(r).toEqual({ title: 'Hi', body: 'Welcome', pinned: false });
  });

  it('rejects an empty title or body', () => {
    expect(announcementInputSchema.safeParse({ title: ' ', body: 'x' }).success).toBe(false);
    expect(announcementInputSchema.safeParse({ title: 'x', body: '' }).success).toBe(false);
  });
});

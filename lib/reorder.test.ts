import { describe, it, expect } from 'vitest';
import { validateReorder } from './reorder';

describe('validateReorder', () => {
  it('accepts a permutation', () => {
    expect(validateReorder(['a', 'b', 'c'], ['c', 'a', 'b'])).toBeNull();
  });
  it('rejects missing, extra and duplicate ids', () => {
    expect(validateReorder(['a', 'b'], ['a'])).not.toBeNull();
    expect(validateReorder(['a', 'b'], ['a', 'b', 'c'])).not.toBeNull();
    expect(validateReorder(['a', 'b'], ['a', 'a'])).not.toBeNull();
    expect(validateReorder(['a', 'b'], ['a', 'x'])).not.toBeNull();
  });
});

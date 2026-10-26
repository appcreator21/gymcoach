// Validation for "set this order" requests: the new list must contain exactly
// the ids that exist, once each, so a stale client can never drop or invent rows.
export function validateReorder(current: string[], requested: string[]): string | null {
  if (requested.length !== current.length) return 'The list does not match the current items.';
  if (new Set(requested).size !== requested.length) return 'The list has duplicates.';
  const known = new Set(current);
  if (requested.some((id) => !known.has(id))) return 'The list does not match the current items.';
  return null;
}

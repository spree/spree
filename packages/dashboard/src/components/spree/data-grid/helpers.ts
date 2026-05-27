/**
 * Counts editable (non-header) rows up to and including the given row id so
 * the cell at that position has stable grid coords that exclude section
 * headers. Used by every spreadsheet that mixes a `renderSectionHeader`
 * with `<NumberCell>` / `<MoneyCell>` etc.
 */
export function editableRowIndex<T extends { kind: 'header' | 'item'; id: string }>(
  rows: ReadonlyArray<{ id: string; original: T }>,
  rowId: string,
): number {
  let i = 0
  for (const row of rows) {
    if (row.original.kind !== 'item') continue
    if (row.id === rowId) return i
    i++
  }
  return i
}

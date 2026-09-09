/**
 * Counts editable (non-header) rows up to and including the given row id so
 * the cell at that position has stable grid coords that exclude section
 * headers. Used by every spreadsheet that mixes a `renderSectionHeader`
 * with `<NumberCell>` / `<MoneyCell>` etc.
 *
 * Every kind but `header` counts, so a sheet that indents child rows under a
 * parent — a variant's quantity breaks, say — keeps Tab and the arrow keys
 * flowing through them in the order they are read.
 */
export function editableRowIndex<T extends { kind: string; id: string }>(
  rows: ReadonlyArray<{ id: string; original: T }>,
  rowId: string,
): number {
  let i = 0
  for (const row of rows) {
    if (row.original.kind === 'header') continue
    if (row.id === rowId) return i
    i++
  }
  return i
}

export interface DiffRow {
  kind: 'same' | 'removed' | 'added' | 'changed'
  before: string | null
  after: string | null
}

/**
 * Lines of two texts aligned side by side, from their longest common
 * subsequence: unchanged lines pair up, a removed run next to an added run
 * pairs line by line as changed.
 */
export function diffLines(before: string, after: string): DiffRow[] {
  const left = before.split('\n')
  const right = after.split('\n')
  const lengths: number[][] = Array.from({ length: left.length + 1 }, () =>
    new Array<number>(right.length + 1).fill(0),
  )

  for (let i = left.length - 1; i >= 0; i--) {
    for (let j = right.length - 1; j >= 0; j--) {
      lengths[i][j] =
        left[i] === right[j]
          ? lengths[i + 1][j + 1] + 1
          : Math.max(lengths[i + 1][j], lengths[i][j + 1])
    }
  }

  const rows: DiffRow[] = []
  let removed: string[] = []
  let added: string[] = []
  const flush = () => {
    const paired = Math.max(removed.length, added.length)
    for (let k = 0; k < paired; k++) {
      const was = removed[k] ?? null
      const now = added[k] ?? null
      rows.push({
        kind: was === null ? 'added' : now === null ? 'removed' : 'changed',
        before: was,
        after: now,
      })
    }
    removed = []
    added = []
  }

  let i = 0
  let j = 0
  while (i < left.length || j < right.length) {
    if (i < left.length && j < right.length && left[i] === right[j]) {
      flush()
      rows.push({ kind: 'same', before: left[i], after: right[j] })
      i++
      j++
    } else if (j < right.length && (i === left.length || lengths[i][j + 1] >= lengths[i + 1][j])) {
      added.push(right[j++])
    } else {
      removed.push(left[i++])
    }
  }
  flush()

  return rows
}

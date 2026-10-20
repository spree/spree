import { describe, expect, it } from 'vitest'
import { diffLines } from './line-diff'

describe('diffLines', () => {
  it('pairs unchanged lines and marks the rest', () => {
    expect(diffLines('a\nb\nc', 'a\nB\nc\nd')).toEqual([
      { kind: 'same', before: 'a', after: 'a' },
      { kind: 'changed', before: 'b', after: 'B' },
      { kind: 'same', before: 'c', after: 'c' },
      { kind: 'added', before: null, after: 'd' },
    ])
  })

  it('reports removed lines', () => {
    expect(diffLines('a\nb', 'a')).toEqual([
      { kind: 'same', before: 'a', after: 'a' },
      { kind: 'removed', before: 'b', after: null },
    ])
  })

  it('treats identical texts as unchanged', () => {
    expect(diffLines('x\ny', 'x\ny').every((row) => row.kind === 'same')).toBe(true)
  })
})

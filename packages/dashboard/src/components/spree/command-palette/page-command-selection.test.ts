import { describe, expect, it } from 'vitest'
import { nextPagedIndex } from './page-command-selection'

// 8 rows, 40px apart — a 200px list shows five, so a page jumps past four.
const OFFSETS = [0, 40, 80, 120, 160, 200, 240, 280]
const PAGE = 200

describe('nextPagedIndex', () => {
  it('moves down by one viewport and lands on the first item at or past the target', () => {
    expect(nextPagedIndex(OFFSETS, 0, PAGE, 1)).toBe(5)
  })

  it('moves up by one viewport toward the matching offset', () => {
    expect(nextPagedIndex(OFFSETS, 5, PAGE, -1)).toBe(0)
  })

  it('stops at the last item when a page would overshoot', () => {
    expect(nextPagedIndex(OFFSETS, 6, PAGE, 1)).toBe(7)
  })

  it('stops at the first item when a page would overshoot upward', () => {
    expect(nextPagedIndex(OFFSETS, 1, PAGE, -1)).toBe(0)
  })

  it('stays put when the list is empty', () => {
    expect(nextPagedIndex([], 0, PAGE, 1)).toBe(0)
  })

  it('clamps a current index that is out of range', () => {
    expect(nextPagedIndex(OFFSETS, 99, PAGE, -1)).toBe(2)
  })

  it('keeps a single item selected', () => {
    expect(nextPagedIndex([0], 0, PAGE, 1)).toBe(0)
    expect(nextPagedIndex([0], 0, PAGE, -1)).toBe(0)
  })
})

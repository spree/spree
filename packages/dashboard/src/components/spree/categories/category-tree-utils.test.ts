import type { Category } from '@spree/admin-sdk'
import { describe, expect, it } from 'vitest'
import {
  buildForest,
  collapsibleIds,
  flatten,
  getProjection,
  removeChildrenOf,
  INDENTATION_WIDTH as W,
} from './category-tree-utils'

// Minimal fixtures — buildForest reads id/name/parent_id/lft.
function cat(id: string, parentId: string | null, lft: number): Category {
  return { id, name: id, parent_id: parentId, lft } as Category
}

// Top-level (parentless) categories A, B are shown as roots — A, B ARE the
// taxonomy roots (today) / parentless categories (6.0), not synthetic.
// A -> A1, A2 ; A1 -> A1a   (lft = tree order)
const CATEGORIES: Category[] = [
  cat('A', null, 1),
  cat('A1', 'A', 2),
  cat('A1a', 'A1', 3),
  cat('A2', 'A', 4),
  cat('B', null, 5),
]

describe('buildForest', () => {
  it('shows top-level categories and nests by parent_id, ordered by lft', () => {
    const forest = buildForest(CATEGORIES)
    expect(forest.map((n) => n.id)).toEqual(['A', 'B'])
    const a = forest[0]
    expect(a.parentId).toBeNull()
    expect(a.children.map((c) => c.id)).toEqual(['A1', 'A2'])
    expect(a.children[0].children[0].id).toBe('A1a')
  })

  it('treats a category whose parent is absent from the list as top-level', () => {
    const orphan = [cat('child', 'missing-parent', 1)]
    const forest = buildForest(orphan)
    expect(forest.map((n) => n.id)).toEqual(['child'])
    expect(forest[0].parentId).toBeNull()
  })

  it('honors lft order over name', () => {
    const reordered = [cat('Z', null, 1), cat('A', null, 2)]
    expect(buildForest(reordered).map((n) => n.id)).toEqual(['Z', 'A'])
  })
})

describe('collapsibleIds', () => {
  it('returns every node with children', () => {
    expect([...collapsibleIds(buildForest(CATEGORIES))].sort()).toEqual(['A', 'A1'])
  })
})

describe('flatten', () => {
  it('skips collapsed subtrees', () => {
    const rows = flatten(buildForest(CATEGORIES), new Set(['A']))
    expect(rows.map((r) => r.id)).toEqual(['A', 'B'])
  })

  it('fully expands with no collapse', () => {
    const rows = flatten(buildForest(CATEGORIES), new Set())
    expect(rows.map((r) => [r.id, r.depth])).toEqual([
      ['A', 0],
      ['A1', 1],
      ['A1a', 2],
      ['A2', 1],
      ['B', 0],
    ])
  })
})

describe('removeChildrenOf', () => {
  it('removes a node’s descendants (drag-self-guard)', () => {
    const rows = flatten(buildForest(CATEGORIES), new Set())
    const out = removeChildrenOf(rows, ['A'])
    expect(out.map((r) => r.id)).toEqual(['A', 'B'])
  })
})

describe('getProjection', () => {
  // Active subtree removed (as during a real drag of B, a leaf → nothing removed):
  // A(0) A1(1) A1a(2) A2(1) B(0)
  const rows = flatten(buildForest(CATEGORIES), new Set())

  it('reorders B to top level when dropped over A with no horizontal drag', () => {
    const p = getProjection(rows, 'B', 'A', 0)
    expect(p.depth).toBe(0)
    expect(p.parentId).toBeNull()
    expect(p.position).toBe(0)
  })

  it('nests B under A (sibling of A2) when dropped over A2 with one indent', () => {
    // arrayMove → A A1 A1a [B] A2 ; projectedDepth 0+1=1, clamped to [1,3] = 1.
    // depth 1 < previous(A1a).depth 2 → backward-search depth 1 → A1.parentId = A.
    const p = getProjection(rows, 'B', 'A2', W)
    expect(p.depth).toBe(1)
    expect(p.parentId).toBe('A')
  })

  it('keeps B at top level when dropped over A2 with no drag', () => {
    const p = getProjection(rows, 'B', 'A2', 0)
    expect(p.depth).toBe(1) // next item after A2 is B(0)? minDepth uses nextItem
    expect(p.parentId).toBe('A')
  })

  it('clamps to top level when dropped over the first row (no previous item)', () => {
    // arrayMove → [B] A A1 … ; no previousItem → maxDepth 0, so any rightward
    // drag is clamped back to the top level.
    const p = getProjection(rows, 'B', 'A', W * 9)
    expect(p.depth).toBe(0)
    expect(p.parentId).toBeNull()
  })

  it('clamps to previous depth + 1 when dragged far right mid-list', () => {
    // Dragging A1 hides its subtree → A(0) A1(1) A2(1) B(0). Drop A1 far-right
    // over A2: arrayMove → A A2 [A1] B ; maxDepth = A2.depth(1)+1 = 2 → nests
    // A1 under A2.
    const dragRows = removeChildrenOf(rows, ['A1'])
    const p = getProjection(dragRows, 'A1', 'A2', W * 9)
    expect(p.depth).toBe(2)
    expect(p.parentId).toBe('A2')
  })
})

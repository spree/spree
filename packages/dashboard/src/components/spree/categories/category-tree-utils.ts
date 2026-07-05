import { arrayMove } from '@dnd-kit/sortable'
import type { Category } from '@spree/admin-sdk'

export const INDENTATION_WIDTH = 24 // px per depth level

export interface TreeNode {
  id: string
  name: string
  parentId: string | null
  productsCount: number
  /** Nested-set left bound — the canonical tree order. */
  lft: number
  children: TreeNode[]
}

export interface FlatNode {
  id: string
  name: string
  parentId: string | null
  depth: number
  childCount: number
  productsCount: number
  collapsed: boolean
}

export interface Projection {
  depth: number
  parentId: string | null
  /** 0-based index among the projected parent's children, after the move. */
  position: number
}

/**
 * Nest the flat category list by parent_id, hiding the synthetic taxonomy root
 * (its children become the top-level nodes). Siblings are ordered by `lft` —
 * the nested-set traversal order, which is what a reposition changes (sorting
 * by name would ignore manual ordering and snap back after a move).
 */
export function buildForest(categories: Category[]): TreeNode[] {
  const byId = new Map<string, TreeNode>()
  for (const c of categories) {
    byId.set(c.id, {
      id: c.id,
      name: c.name,
      parentId: c.parent_id ?? null,
      productsCount: c.products_count ?? 0,
      lft: c.lft ?? 0,
      children: [],
    })
  }

  // Every category is shown. A category whose parent isn't in the list (today's
  // taxonomy roots; in 6.0, regular parentless categories) becomes a top-level
  // node.
  const roots: TreeNode[] = []
  for (const node of byId.values()) {
    const parent = node.parentId ? byId.get(node.parentId) : undefined
    if (parent) parent.children.push(node)
    else {
      node.parentId = null
      roots.push(node)
    }
  }

  const sortRec = (nodes: TreeNode[]) => {
    nodes.sort((a, b) => a.lft - b.lft)
    for (const n of nodes) sortRec(n.children)
  }
  sortRec(roots)

  return roots
}

/** Every node id that has children — the default-collapsed set. */
export function collapsibleIds(roots: TreeNode[]): Set<string> {
  const ids = new Set<string>()
  const walk = (nodes: TreeNode[]) => {
    for (const n of nodes) {
      if (n.children.length > 0) {
        ids.add(n.id)
        walk(n.children)
      }
    }
  }
  walk(roots)
  return ids
}

/**
 * Depth-first flatten of the visible tree (collapsed subtrees are skipped). The
 * dragged item's subtree is removed via `removeChildrenOf` while dragging so it
 * can't drop into itself.
 */
export function flatten(roots: TreeNode[], collapsed: Set<string>): FlatNode[] {
  const out: FlatNode[] = []
  const walk = (nodes: TreeNode[], depth: number) => {
    for (const n of nodes) {
      const isCollapsed = collapsed.has(n.id)
      out.push({
        id: n.id,
        name: n.name,
        parentId: n.parentId,
        depth,
        childCount: n.children.length,
        productsCount: n.productsCount,
        collapsed: isCollapsed,
      })
      if (n.children.length > 0 && !isCollapsed) walk(n.children, depth + 1)
    }
  }
  walk(roots, 0)
  return out
}

/** Remove the given ids and their descendants from a flattened list. */
export function removeChildrenOf(items: FlatNode[], ids: string[]): FlatNode[] {
  const excluded = new Set(ids)
  return items.filter((item) => {
    if (item.parentId && excluded.has(item.parentId)) {
      if (item.childCount > 0) excluded.add(item.id)
      return false
    }
    return true
  })
}

function getDragDepth(offset: number, indentationWidth: number) {
  return Math.round(offset / indentationWidth)
}

function getMaxDepth(previousItem: FlatNode | undefined) {
  return previousItem ? previousItem.depth + 1 : 0
}

function getMinDepth(nextItem: FlatNode | undefined) {
  return nextItem ? nextItem.depth : 0
}

/**
 * Project the dragged row's target depth, parent, and sibling index — a
 * faithful port of the canonical dnd-kit tree `getProjection`, with the sibling
 * index derived for our reposition API.
 *
 * @param items the visible flat rows (active subtree already removed)
 */
export function getProjection(
  items: FlatNode[],
  activeId: string,
  overId: string,
  dragOffset: number,
  indentationWidth = INDENTATION_WIDTH,
): Projection {
  const overItemIndex = items.findIndex((i) => i.id === overId)
  const activeItemIndex = items.findIndex((i) => i.id === activeId)
  const activeItem = items[activeItemIndex]
  const newItems = arrayMove(items, activeItemIndex, overItemIndex)
  const previousItem = newItems[overItemIndex - 1]
  const nextItem = newItems[overItemIndex + 1]
  const dragDepth = getDragDepth(dragOffset, indentationWidth)
  const projectedDepth = activeItem.depth + dragDepth
  const maxDepth = getMaxDepth(previousItem)
  const minDepth = getMinDepth(nextItem)

  let depth = projectedDepth
  if (projectedDepth >= maxDepth) depth = maxDepth
  else if (projectedDepth < minDepth) depth = minDepth

  const parentId = getParentId()
  return { depth, parentId, position: getPosition(parentId) }

  function getParentId(): string | null {
    if (depth === 0 || !previousItem) return null
    if (depth === previousItem.depth) return previousItem.parentId
    if (depth > previousItem.depth) return previousItem.id
    return (
      newItems
        .slice(0, overItemIndex)
        .reverse()
        .find((item) => item.depth === depth)?.parentId ?? null
    )
  }

  // Index among the projected parent's children, counting same-parent rows that
  // precede the drop point in the post-move ordering (the active row excluded).
  function getPosition(parentId: string | null): number {
    let position = 0
    for (let i = 0; i < overItemIndex; i++) {
      const row = newItems[i]
      if (row.id === activeId) continue
      if (row.parentId === parentId) position++
    }
    return position
  }
}

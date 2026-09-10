const ITEM_SELECTOR = '[cmdk-item]:not([aria-disabled="true"])'
const LIST_SELECTOR = '[cmdk-list]'

/**
 * Index of the item one viewport away from the current selection.
 * Offsets are positions along the scrollable list, so group headings
 * shrink the jump the same way they shrink the visible page.
 */
export function nextPagedIndex(
  itemOffsets: readonly number[],
  currentIndex: number,
  pageHeight: number,
  direction: 1 | -1,
): number {
  if (itemOffsets.length === 0) return 0

  const current = Math.max(0, Math.min(itemOffsets.length - 1, currentIndex))
  const target = itemOffsets[current] + direction * pageHeight

  if (direction === 1) {
    let index = current
    while (index < itemOffsets.length - 1 && itemOffsets[index] < target) {
      index += 1
    }
    return index
  }

  let index = current
  while (index > 0 && itemOffsets[index] > target) {
    index -= 1
  }
  return index
}

/** The command item one page from the current selection, or `undefined` if the list is empty. */
export function pagedCommandItem(
  root: ParentNode,
  key: 'PageDown' | 'PageUp',
): HTMLElement | undefined {
  const list = root.querySelector(LIST_SELECTOR)
  if (!(list instanceof HTMLElement)) return undefined

  const items = Array.from(list.querySelectorAll(ITEM_SELECTOR)).filter(
    (node): node is HTMLElement => node instanceof HTMLElement,
  )
  if (items.length === 0) return undefined

  const selectedIndex = items.findIndex((item) => item.getAttribute('aria-selected') === 'true')
  const listTop = list.getBoundingClientRect().top
  const nextIndex = nextPagedIndex(
    items.map((item) => item.getBoundingClientRect().top - listTop + list.scrollTop),
    selectedIndex >= 0 ? selectedIndex : 0,
    list.clientHeight,
    key === 'PageDown' ? 1 : -1,
  )

  return items[nextIndex]
}

// Keeps the dashboard working while a browser translator rewrites the page.
//
// Google Translate (Chrome, the Google app on iOS, Edge's Translator) swaps the
// text nodes React rendered for `<font>` wrappers holding the translation. React
// still holds the original nodes, so the next commit that removes or inserts
// next to one asks the DOM to touch a node that is no longer where React left
// it. The browser throws `NotFoundError` ("The object can not be found here",
// "Failed to execute 'removeChild' on 'Node'"), React unmounts the tree to the
// nearest error boundary, and the admin sees a crash screen for something as
// small as ticking a checkbox.
//
// Blocking translation (`translate="no"`) would leave admins whose language the
// dashboard does not ship without a way to read it. Instead, the two DOM calls
// React makes on its own children tolerate a node a translator has moved: a
// removal of a node that is already gone is a no-op, and an insert next to a
// moved node appends instead. React re-renders the text on its next update.
// For every node still where React put it — every page with no translator —
// the original method runs unchanged.
//
// See https://github.com/facebook/react/issues/11538.

const GUARDED = Symbol.for('spree.dashboard.browserTranslationGuard')

type GuardableNode = {
  removeChild<T>(child: T): T
  insertBefore<T>(node: T, child: unknown): T
  appendChild<T>(node: T): T
}

type GuardableChild = { parentNode?: unknown } | null | undefined

/**
 * Makes `removeChild` and `insertBefore` tolerate nodes a browser translator
 * has moved. Safe to call more than once; only the first call patches.
 *
 * @param proto the prototype to patch — `Node.prototype` in a browser, a fake in tests
 * @returns whether this call installed the guard
 */
export function guardAgainstBrowserTranslation(
  proto: GuardableNode | undefined = typeof Node === 'function'
    ? (Node.prototype as unknown as GuardableNode)
    : undefined,
): boolean {
  if (!proto) return false
  const marked = proto as GuardableNode & { [GUARDED]?: true }
  if (marked[GUARDED]) return false

  const removeChild = proto.removeChild
  const insertBefore = proto.insertBefore

  proto.removeChild = function <T>(this: GuardableNode, child: T): T {
    if ((child as GuardableChild)?.parentNode !== this) {
      warnMoved('removeChild')
      return child
    }
    return removeChild.call(this, child) as T
  }

  proto.insertBefore = function <T>(this: GuardableNode, node: T, reference: unknown): T {
    if (reference && (reference as GuardableChild)?.parentNode !== this) {
      warnMoved('insertBefore')
      return this.appendChild(node)
    }
    return insertBefore.call(this, node, reference) as T
  }

  Object.defineProperty(marked, GUARDED, { value: true })
  return true
}

let warned = false

// Once per page: a translated page can hit this on every render, and the
// console is the only place it is worth noting.
function warnMoved(method: string): void {
  if (warned || typeof console === 'undefined') return
  warned = true
  console.warn(
    `[spree] ${method} skipped a node moved by a browser translator; the dashboard keeps running.`,
  )
}

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
// dashboard does not ship without a way to read it. Instead, the guard keeps
// track of which `<font>` took the place of which text node, and sends React's
// DOM calls to it:
//
// - removing a replaced text node removes its `<font>`, so no stale text stays;
// - inserting before a replaced text node inserts before its `<font>`, so the
//   new content lands where React asked;
// - React changing a replaced text node's text writes the new text into the
//   `<font>`, which the translator then translates again.
//
// Anything else — every node still where React put it, every page with no
// translator — goes to the browser's own methods unchanged.
//
// See https://github.com/facebook/react/issues/11538.

const GUARDED = Symbol.for('spree.dashboard.browserTranslationGuard')
const TEXT_NODE = 3

type DomNode = {
  parentNode: unknown
  nodeType?: number
  nodeName?: string
  textContent?: string | null
}

type GuardableNode = {
  removeChild<T>(child: T): T
  insertBefore<T>(node: T, child: unknown): T
}

/** The parts of a `MutationRecord` the guard reads. */
export type TranslatorMutation = {
  removedNodes: ArrayLike<DomNode>
  addedNodes: ArrayLike<DomNode>
  previousSibling: DomNode | null
}

// Original text node → the translator's `<font>` that took its place. Weak, so
// a node React has let go of is not kept alive.
const replacements = new WeakMap<object, DomNode>()
let observer: { takeRecords(): TranslatorMutation[] } | null = null

function isTranslatorWrapper(node: DomNode | null | undefined): node is DomNode {
  return node?.nodeName?.toUpperCase() === 'FONT'
}

/**
 * Remembers each text node a translator swapped for a `<font>`. A translator
 * either replaces the node in one step (one record that removes the text and
 * adds the `<font>`) or inserts the `<font>` before it and then removes it (the
 * removal's previous sibling is the `<font>`).
 *
 * @param records mutation records from a `MutationObserver` on the document
 */
export function recordTranslatorReplacements(records: Iterable<TranslatorMutation>): void {
  for (const { removedNodes, addedNodes, previousSibling } of records) {
    for (let i = 0; i < removedNodes.length; i++) {
      const removed = removedNodes[i]
      if (removed.nodeType !== TEXT_NODE) continue
      const replacement =
        addedNodes.length === removedNodes.length ? addedNodes[i] : i === 0 ? previousSibling : null
      if (isTranslatorWrapper(replacement)) replacements.set(removed, replacement)
    }
  }
}

// The translator's wrapper standing in for `node` among `parent`'s children:
// the `<font>` that replaced it, or the `<font>` it was moved into.
function standIn(node: DomNode | null | undefined, parent: unknown): DomNode | null {
  if (!node) return null
  for (let n = node.parentNode as DomNode | null; n; n = n.parentNode as DomNode | null) {
    if (n.parentNode === parent) return isTranslatorWrapper(n) ? n : null
  }
  if (observer && !replacements.has(node)) recordTranslatorReplacements(observer.takeRecords())
  const replacement = replacements.get(node)
  return replacement && replacement.parentNode === parent ? replacement : null
}

function ownDescriptor(proto: object, key: string): PropertyDescriptor | undefined {
  for (let p: object | null = proto; p; p = Object.getPrototypeOf(p)) {
    const descriptor = Object.getOwnPropertyDescriptor(p, key)
    if (descriptor) return descriptor
  }
  return undefined
}

/**
 * Makes `removeChild`, `insertBefore` and `nodeValue` follow nodes a browser
 * translator has replaced, and starts watching the document for those
 * replacements. Safe to call more than once; only the first call patches.
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
    const node = child as DomNode | null
    if (node?.parentNode === this) return removeChild.call(this, child) as T
    const wrapper = standIn(node, this)
    if (wrapper) removeChild.call(this, wrapper)
    else warnMoved('removeChild')
    return child
  }

  proto.insertBefore = function <T>(this: GuardableNode, node: T, reference: unknown): T {
    const ref = reference as DomNode | null
    if (!ref || ref.parentNode === this) return insertBefore.call(this, node, reference) as T
    const wrapper = standIn(ref, this)
    if (!wrapper) warnMoved('insertBefore')
    return insertBefore.call(this, node, wrapper) as T
  }

  const nodeValue = ownDescriptor(proto, 'nodeValue')
  if (nodeValue?.get && nodeValue.set) {
    const { get, set } = nodeValue
    Object.defineProperty(proto, 'nodeValue', {
      configurable: true,
      enumerable: nodeValue.enumerable,
      get,
      set(this: DomNode, value: string | null) {
        set.call(this, value)
        const wrapper = replacements.get(this)
        if (wrapper?.parentNode && !this.parentNode) wrapper.textContent = value
      },
    })
  }

  Object.defineProperty(marked, GUARDED, { value: true })
  watchDocument()
  return true
}

function watchDocument(): void {
  if (typeof MutationObserver === 'undefined' || typeof document === 'undefined') return
  const watcher = new MutationObserver((records) => recordTranslatorReplacements(records))
  watcher.observe(document.documentElement, { childList: true, subtree: true })
  observer = watcher
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

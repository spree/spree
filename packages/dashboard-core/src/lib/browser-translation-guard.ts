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
// A node the guard cannot account for is skipped (removal) or appended
// (insertion) only while the page is being translated. Otherwise — every node
// still where React put it, every page with no translator — the browser's own
// methods run unchanged, errors included.
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
  nextSibling: DomNode | null
}

/** The `MutationObserver` feeding {@link recordTranslatorReplacements}. */
export type TranslatorWatcher = { takeRecords(): TranslatorMutation[] }

export type BrowserTranslationGuardOptions = {
  /** What reports the translator's swaps — a `MutationObserver` on the document by default. */
  watcher?: TranslatorWatcher | null
  /** Whether the page is being translated — read from the document by default. */
  isTranslated?: () => boolean
}

// Original text node → the translator's `<font>` that took its place. Weak, so
// a node React has let go of is not kept alive.
const replacements = new WeakMap<object, DomNode>()
// Text node → the `<font>` inserted right before it: the first half of a
// translator's insert-then-remove swap.
const insertedBefore = new WeakMap<object, DomNode>()
let replacementSeen = false

const isText = (node: DomNode | null | undefined): node is DomNode => node?.nodeType === TEXT_NODE
const isFont = (node: DomNode | null | undefined): node is DomNode =>
  node?.nodeName?.toUpperCase() === 'FONT'

function remember(text: DomNode, font: DomNode): void {
  replacements.set(text, font)
  replacementSeen = true
}

/**
 * Remembers each text node a translator swapped for a `<font>`. A translator
 * either replaces the node in one step (one record that removes the text and
 * adds the `<font>`), or inserts the `<font>` right before the text and then
 * removes the text. A `<font>` that merely sits next to a removed text node is
 * not a swap.
 *
 * @param records mutation records from a `MutationObserver` on the document
 */
export function recordTranslatorReplacements(records: Iterable<TranslatorMutation>): void {
  for (const { removedNodes, addedNodes, previousSibling, nextSibling } of records) {
    if (removedNodes.length > 0 && addedNodes.length === removedNodes.length) {
      for (let i = 0; i < removedNodes.length; i++) {
        if (isText(removedNodes[i]) && isFont(addedNodes[i]))
          remember(removedNodes[i], addedNodes[i])
      }
    } else if (removedNodes.length === 0 && addedNodes.length === 1) {
      if (isFont(addedNodes[0]) && isText(nextSibling))
        insertedBefore.set(nextSibling, addedNodes[0])
    } else if (addedNodes.length === 0 && removedNodes.length === 1) {
      const font = insertedBefore.get(removedNodes[0])
      if (font && font === previousSibling) remember(removedNodes[0], font)
    }
  }
}

function translatedDocument(): boolean {
  if (replacementSeen) return true
  if (typeof document === 'undefined') return false
  const { classList } = document.documentElement
  return classList.contains('translated-ltr') || classList.contains('translated-rtl')
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
 * @param options the watcher and the translation check, replaced in tests
 * @returns whether this call installed the guard
 */
export function guardAgainstBrowserTranslation(
  proto: GuardableNode | undefined = typeof Node === 'function'
    ? (Node.prototype as unknown as GuardableNode)
    : undefined,
  options: BrowserTranslationGuardOptions = {},
): boolean {
  if (!proto) return false
  const marked = proto as GuardableNode & { [GUARDED]?: true }
  if (marked[GUARDED]) return false

  const watcher = options.watcher === undefined ? watchDocument() : options.watcher
  const isTranslated = options.isTranslated ?? translatedDocument

  // The `<font>` that replaced a text node. When none is attached, read the
  // records the observer has queued but not delivered yet: the translator and
  // React can both touch the node within one task.
  const replacementOf = (node: DomNode): DomNode | undefined => {
    const known = replacements.get(node)
    if (known?.parentNode || !watcher) return known
    recordTranslatorReplacements(watcher.takeRecords())
    return replacements.get(node)
  }

  // Only text nodes are replaced, and only by the `<font>` recorded for them.
  const standIn = (node: DomNode | null | undefined, parent: unknown): DomNode | null => {
    if (!isText(node)) return null
    const replacement = replacementOf(node)
    return replacement && replacement.parentNode === parent ? replacement : null
  }

  const removeChild = proto.removeChild
  const insertBefore = proto.insertBefore

  proto.removeChild = function <T>(this: GuardableNode, child: T): T {
    const node = child as DomNode | null
    if (node?.parentNode === this) return removeChild.call(this, child) as T
    const wrapper = standIn(node, this)
    if (wrapper) {
      removeChild.call(this, wrapper)
      return child
    }
    if (!isTranslated()) return removeChild.call(this, child) as T
    warnMoved('removeChild')
    return child
  }

  proto.insertBefore = function <T>(this: GuardableNode, node: T, reference: unknown): T {
    const ref = reference as DomNode | null
    if (!ref || ref.parentNode === this) return insertBefore.call(this, node, reference) as T
    const wrapper = standIn(ref, this)
    if (wrapper) return insertBefore.call(this, node, wrapper) as T
    if (!isTranslated()) return insertBefore.call(this, node, reference) as T
    warnMoved('insertBefore')
    return insertBefore.call(this, node, null) as T
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
        if (this.parentNode || !isText(this)) return
        const wrapper = replacementOf(this)
        if (wrapper?.parentNode) wrapper.textContent = value
      },
    })
  }

  Object.defineProperty(marked, GUARDED, { value: true })
  return true
}

function watchDocument(): TranslatorWatcher | null {
  if (typeof MutationObserver === 'undefined' || typeof document === 'undefined') return null
  const watcher = new MutationObserver((records) => recordTranslatorReplacements(records))
  watcher.observe(document.documentElement, { childList: true, subtree: true })
  return watcher
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

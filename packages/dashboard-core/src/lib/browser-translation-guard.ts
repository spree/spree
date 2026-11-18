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
  style?: { verticalAlign?: string }
}

type GuardableNode = {
  removeChild<T>(child: T): T
  insertBefore<T>(node: T, child: unknown): T
  appendChild<T>(node: T): T
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

/** Text node → the `<font>` inserted right before it, still waiting for the text's removal. */
export type SwapCandidates = Map<DomNode, DomNode>

export type BrowserTranslationGuardOptions = {
  /** What reports the translator's swaps — a `MutationObserver` on the document by default. */
  watcher?: TranslatorWatcher | null
  /** Whether the page is being translated — read from the document by default. */
  isTranslated?: () => boolean
}

// Original text node → the translator's `<font>` that took its place. Weak, so
// a node React has let go of is not kept alive.
const replacements = new WeakMap<object, DomNode>()
// Every `<font>` recorded as a translation. The guard moves these itself, and
// a move reads like a fresh insertion; a translator always makes a new one.
const wrappers = new WeakSet<object>()

const isText = (node: DomNode | null | undefined): node is DomNode => node?.nodeType === TEXT_NODE
const isFont = (node: DomNode | null | undefined): node is DomNode =>
  node?.nodeName?.toUpperCase() === 'FONT'

function markedTranslated(): boolean {
  if (typeof document === 'undefined') return false
  const { classList } = document.documentElement
  return classList.contains('translated-ltr') || classList.contains('translated-rtl')
}

// Google Translate gives every wrapper it creates `vertical-align: inherit`.
// Read from the parsed style, so spacing or other declarations in the
// attribute make no difference.
const translatorStyled = (font: DomNode): boolean => font.style?.verticalAlign === 'inherit'

// A `<font>` swapped in for text is a translator's only with evidence of one:
// Google Translate marks the root element as translated and styles its
// wrappers. Code formatting its own text with a `<font>` has neither.
const fromTranslator = (font: DomNode): boolean => translatorStyled(font) || markedTranslated()

function remember(text: DomNode, font: DomNode): void {
  if (!fromTranslator(font)) return
  replacements.set(text, font)
  wrappers.add(font)
}

/**
 * Remembers each text node a translator swapped for a `<font>`. A translator
 * either replaces the node in one step (one record that removes the text and
 * adds the `<font>`), or inserts the `<font>` right before the text and then
 * removes the text. A translator does both halves in one task, so an insertion
 * is only paired with a removal from the same task: the same batch of records,
 * or — when the guard reads records early, within the task — the candidates
 * kept for it. A `<font>` that merely sits next to a removed text node, or was
 * inserted before it some time earlier, is not a swap.
 *
 * @param records mutation records from a `MutationObserver` on the document
 * @param insertedBefore insertions still waiting for their removal; a fresh
 *   map unless records of the same task were read before these
 */
export function recordTranslatorReplacements(
  records: Iterable<TranslatorMutation>,
  insertedBefore: SwapCandidates = new Map(),
): void {
  for (const { removedNodes, addedNodes, previousSibling, nextSibling } of records) {
    if (removedNodes.length > 0 && addedNodes.length === removedNodes.length) {
      for (let i = 0; i < removedNodes.length; i++) {
        if (isText(removedNodes[i]) && isFont(addedNodes[i]))
          remember(removedNodes[i], addedNodes[i])
      }
    } else if (removedNodes.length === 0 && addedNodes.length === 1) {
      // A recorded `<font>` landing before a text node is the guard moving a
      // translation along with its text, not a translator swapping that node.
      const font = addedNodes[0]
      if (isFont(font) && !wrappers.has(font) && isText(nextSibling))
        insertedBefore.set(nextSibling, font)
    } else if (addedNodes.length === 0 && removedNodes.length === 1) {
      const font = insertedBefore.get(removedNodes[0])
      if (font && font === previousSibling) remember(removedNodes[0], font)
    }
  }
}

// Whether the page is being translated now: marked as translated, or still
// holding a wrapper Google Translate made — judged by the same style check
// used when recording swaps. Both go away when the translation is reverted, so
// the fallback below does too. Only read once a node is already missing.
function translatedDocument(): boolean {
  if (markedTranslated()) return true
  if (typeof document === 'undefined') return false
  for (const font of Array.from(document.querySelectorAll<HTMLElement>('font[style]'))) {
    if (translatorStyled(font)) return true
  }
  return false
}

// Whether `node` sits somewhere inside `ancestor`.
function within(node: DomNode, ancestor: DomNode): boolean {
  for (let p = node.parentNode as DomNode | null; p; p = p.parentNode as DomNode | null) {
    if (p === ancestor) return true
  }
  return false
}

function ownDescriptor(proto: object, key: string): PropertyDescriptor | undefined {
  for (let p: object | null = proto; p; p = Object.getPrototypeOf(p)) {
    const descriptor = Object.getOwnPropertyDescriptor(p, key)
    if (descriptor) return descriptor
  }
  return undefined
}

/**
 * Makes `removeChild`, `insertBefore`, `appendChild` and `nodeValue` follow nodes a browser
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
  const target: GuardableNode = proto
  if (marked[GUARDED]) return false

  // Insertions read early, within a task, whose removal may still come in the
  // same task. Cleared once the task's records have all been delivered, so a
  // later task cannot adopt an unrelated `<font>`.
  const candidates: SwapCandidates = new Map()
  let clearing = false
  const clearAfterDelivery = () => {
    if (clearing || candidates.size === 0) return
    clearing = true
    // The observer's delivery was queued by the records just read, before
    // this, so it still sees the candidates.
    const later =
      typeof queueMicrotask === 'function'
        ? queueMicrotask
        : (fn: () => void) => void Promise.resolve().then(fn)
    later(() => {
      clearing = false
      candidates.clear()
    })
  }
  const deliver = (records: Iterable<TranslatorMutation>) => {
    recordTranslatorReplacements(records, candidates)
    candidates.clear()
  }

  const watcher = options.watcher === undefined ? watchDocument(deliver) : options.watcher
  const isTranslated = options.isTranslated ?? translatedDocument

  // The `<font>` that replaced a text node. Records the observer has queued
  // but not delivered yet are read first: the translator and React can both
  // touch the node within one task, and a newer swap replaces an older one.
  // Only reached for a node no longer where React put it.
  const replacementOf = (node: DomNode): DomNode | undefined => {
    if (watcher) {
      recordTranslatorReplacements(watcher.takeRecords(), candidates)
      clearAfterDelivery()
    }
    return replacements.get(node)
  }

  // Only text nodes are replaced, and only by the `<font>` recorded for them.
  const standIn = (node: DomNode | null | undefined, parent: unknown): DomNode | null => {
    if (!isText(node)) return null
    const replacement = replacementOf(node)
    return replacement && replacement.parentNode === parent ? replacement : null
  }

  // React moving a text node the translator replaced moves its `<font>`, or
  // the translation would stay behind and show next to the moved text. The
  // text is either detached or kept inside its own `<font>`; a text node
  // anywhere else is an ordinary child and moves itself.
  const movedStandIn = (node: unknown, parent: unknown): DomNode | null => {
    const text = node as DomNode | null
    if (!isText(text) || text.parentNode === parent) return null
    const wrapper = standIn(text, parent)
    if (!wrapper) return null
    return !text.parentNode || within(text, wrapper) ? wrapper : null
  }

  const removeChild = proto.removeChild
  const insertBefore = proto.insertBefore
  const appendChild = proto.appendChild
  const nodeValue = ownDescriptor(proto, 'nodeValue')

  // A page that froze the DOM prototypes keeps the browser's methods: the
  // guard backs out instead of failing the dashboard's start-up.
  try {
    patch()
    Object.defineProperty(marked, GUARDED, { value: true })
    return true
  } catch {
    restore()
    ;(watcher as { disconnect?: () => void } | null)?.disconnect?.()
    return false
  }

  function restore(): void {
    try {
      target.removeChild = removeChild
      target.insertBefore = insertBefore
      target.appendChild = appendChild
      if (nodeValue) Object.defineProperty(target, 'nodeValue', nodeValue)
    } catch {
      // Frozen before anything was replaced: nothing to put back.
    }
  }

  function patch(): void {
    target.removeChild = function <T>(this: GuardableNode, child: T): T {
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

    target.insertBefore = function <T>(this: GuardableNode, node: T, reference: unknown): T {
      // Putting the text back before its own `<font>` is the translation being
      // undone, not React moving it.
      const standing = movedStandIn(node, this)
      const moved = standing === reference ? null : standing
      const inserted = moved ?? node
      const ref = reference as DomNode | null
      if (!ref || ref.parentNode === this) {
        insertBefore.call(this, inserted, reference)
        return node
      }
      const wrapper = standIn(ref, this)
      if (wrapper) {
        insertBefore.call(this, inserted, wrapper)
        return node
      }
      if (!isTranslated()) return insertBefore.call(this, node, reference) as T
      warnMoved('insertBefore')
      insertBefore.call(this, inserted, null)
      return node
    }

    target.appendChild = function <T>(this: GuardableNode, node: T): T {
      const moved = movedStandIn(node, this)
      if (!moved) return appendChild.call(this, node) as T
      appendChild.call(this, moved)
      return node
    }

    if (nodeValue?.get && nodeValue.set) {
      const { get, set } = nodeValue
      Object.defineProperty(target, 'nodeValue', {
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
  }
}

function watchDocument(
  deliver: (records: Iterable<TranslatorMutation>) => void,
): TranslatorWatcher | null {
  if (typeof MutationObserver === 'undefined' || typeof document === 'undefined') return null
  const watcher = new MutationObserver(deliver)
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

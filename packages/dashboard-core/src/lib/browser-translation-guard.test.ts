import { afterEach, describe, expect, it, vi } from 'vitest'
import {
  guardAgainstBrowserTranslation,
  recordTranslatorReplacements,
  type TranslatorMutation,
} from './browser-translation-guard'

// A minimal DOM: just enough parent/child bookkeeping to reproduce what a
// translator does to React's nodes. The real methods throw like a browser does.
class FakeNode {
  parentNode: FakeNode | null = null
  childNodes: FakeNode[] = []
  style: { verticalAlign?: string } = {}
  readonly nodeName: string
  readonly nodeType: number
  private value: string | null

  constructor(nodeName: string, value: string | null = null) {
    this.nodeName = nodeName
    this.nodeType = nodeName === '#text' ? 3 : 1
    this.value = value
  }

  get nodeValue(): string | null {
    return this.value
  }

  set nodeValue(value: string | null) {
    this.value = value
  }

  get textContent(): string {
    return this.value ?? this.childNodes.map((c) => c.textContent).join('')
  }

  set textContent(value: string) {
    for (const child of this.childNodes) child.parentNode = null
    this.childNodes = []
    this.appendChild(new FakeNode('#text', value))
  }

  appendChild<T>(node: T): T {
    return this.insertBefore(node, null)
  }

  removeChild<T>(node: T): T {
    const child = node as unknown as FakeNode
    if (child.parentNode !== this)
      throw new Error('NotFoundError: The object can not be found here.')
    this.childNodes = this.childNodes.filter((c) => c !== child)
    child.parentNode = null
    return node
  }

  insertBefore<T>(node: T, reference: unknown): T {
    const ref = reference as FakeNode | null
    if (ref && ref.parentNode !== this)
      throw new Error('NotFoundError: The object can not be found here.')
    const child = node as unknown as FakeNode
    if (child.parentNode) child.parentNode.removeChild(child)
    const at = ref ? this.childNodes.indexOf(ref) : this.childNodes.length
    this.childNodes.splice(at, 0, child)
    child.parentNode = this
    return node
  }
}

type Setup = { guarded?: boolean; translated?: boolean; pending?: TranslatorMutation[] }

function setup({ guarded = true, translated = true, pending = [] }: Setup = {}) {
  class Node extends FakeNode {}
  if (guarded) {
    guardAgainstBrowserTranslation(Node.prototype, {
      watcher: { takeRecords: () => pending.splice(0) },
      isTranslated: () => translated,
    })
  }
  const el = (name: string, value?: string) => new Node(name, value)
  return { el, text: (value: string) => el('#text', value) }
}

// Google Translate's swap of a text node for its translation, as the document's
// MutationObserver reports it: in one step, or as an insert before the text
// followed by the text's removal.
function translate(
  text: FakeNode,
  translation: string,
  { oneStep = false, deliver = true }: { oneStep?: boolean; deliver?: boolean } = {},
): { font: FakeNode; records: TranslatorMutation[] } {
  const parent = text.parentNode as FakeNode
  const font = new (Object.getPrototypeOf(text).constructor)('FONT') as FakeNode
  font.style.verticalAlign = 'inherit'
  font.textContent = translation
  const after = parent.childNodes[parent.childNodes.indexOf(text) + 1] ?? null
  parent.insertBefore(font, text)
  parent.removeChild(text)
  const records: TranslatorMutation[] = oneStep
    ? [{ removedNodes: [text], addedNodes: [font], previousSibling: null, nextSibling: after }]
    : [
        { removedNodes: [], addedNodes: [font], previousSibling: null, nextSibling: text },
        { removedNodes: [text], addedNodes: [], previousSibling: font, nextSibling: after },
      ]
  if (deliver) recordTranslatorReplacements(records)
  return { font, records }
}

const texts = (parent: FakeNode) => parent.childNodes.map((c) => c.textContent)

describe('guardAgainstBrowserTranslation', () => {
  afterEach(() => vi.restoreAllMocks())

  it('reproduces the crash without the guard', () => {
    const { el, text } = setup({ guarded: false })
    const parent = el('div')
    const label = text('1 selected')
    parent.appendChild(label)
    translate(label, '1 sélectionné')

    expect(() => parent.removeChild(label)).toThrow(/NotFoundError/)
  })

  it.each([false, true])(
    'removes the translation with the text it replaced (one step: %s)',
    (oneStep) => {
      const { el, text } = setup()
      const parent = el('div')
      const label = text('Saving…')
      const button = el('BUTTON')
      parent.appendChild(label)
      parent.appendChild(button)
      translate(label, 'Enregistrement…', { oneStep })

      expect(parent.removeChild(label)).toBe(label)
      expect(parent.childNodes).toEqual([button])
    },
  )

  it('inserts before the translation that replaced the reference node', () => {
    const { el, text } = setup()
    const parent = el('div')
    const label = text('Save')
    const button = el('BUTTON')
    parent.appendChild(label)
    parent.appendChild(button)
    const { font } = translate(label, 'Enregistrer')
    const spinner = el('SVG')

    expect(parent.insertBefore(spinner, label)).toBe(spinner)
    expect(parent.childNodes).toEqual([spinner, font, button])
  })

  it('moves the translation when React reorders the text it replaced', () => {
    const { el, text } = setup()
    const parent = el('div')
    const label = text('A')
    const b = el('B')
    const c = el('C')
    parent.appendChild(label)
    parent.appendChild(b)
    parent.appendChild(c)
    const { font } = translate(label, 'À')

    expect(parent.insertBefore(label, c)).toBe(label)
    expect(parent.childNodes).toEqual([b, font, c])
    expect(label.parentNode).toBeNull()
    expect(parent.appendChild(label)).toBe(label)
    expect(parent.childNodes).toEqual([b, c, font])
  })

  it('follows a text node the translator moved into its wrapper', () => {
    const { el, text } = setup()
    const parent = el('div')
    const label = text('Save')
    parent.appendChild(label)
    const font = el('FONT')
    font.style.verticalAlign = 'inherit'
    parent.insertBefore(font, label)
    font.appendChild(label)
    recordTranslatorReplacements([
      { removedNodes: [], addedNodes: [font], previousSibling: null, nextSibling: label },
      { removedNodes: [label], addedNodes: [], previousSibling: font, nextSibling: null },
    ])
    const spinner = el('SVG')

    parent.insertBefore(spinner, label)
    expect(parent.childNodes).toEqual([spinner, font])
    parent.removeChild(label)
    expect(parent.childNodes).toEqual([spinner])
  })

  it('shows React’s new text in place of a stale translation', () => {
    const { el, text } = setup()
    const parent = el('div')
    const label = text('1 selected')
    parent.appendChild(label)
    const { font } = translate(label, '1 sélectionné')

    label.nodeValue = '2 selected'
    expect(texts(parent)).toEqual(['2 selected'])
    expect(parent.childNodes).toEqual([font])
  })

  it('reads replacements the observer has not delivered yet', () => {
    // The translator swaps the text and React changes it within one task, so
    // the records are still queued in the observer when the new text arrives.
    const pending: TranslatorMutation[] = []
    const { el, text } = setup({ pending })
    const parent = el('div')
    const label = text('1 selected')
    parent.appendChild(label)
    const { records } = translate(label, '1 sélectionné', { deliver: false })
    pending.push(...records)

    label.nodeValue = '2 selected'
    expect(texts(parent)).toEqual(['2 selected'])
    expect(pending).toEqual([])
  })

  it('follows a text node translated again after React restored it', () => {
    const pending: TranslatorMutation[] = []
    const { el, text } = setup({ pending })
    const parent = el('div')
    const label = text('1 selected')
    parent.appendChild(label)
    const { font: first } = translate(label, '1 sélectionné')
    parent.insertBefore(label, first)
    parent.removeChild(first)
    const { records } = translate(label, '1 sélectionné', { deliver: false })
    pending.push(...records)

    label.nodeValue = '2 selected'
    expect(texts(parent)).toEqual(['2 selected'])
  })

  it('follows a newer translation while the older one sits in a fragment', () => {
    const pending: TranslatorMutation[] = []
    const { el, text } = setup({ pending })
    const parent = el('div')
    const label = text('1 selected')
    parent.appendChild(label)
    const { font: first } = translate(label, '1 sélectionné')
    parent.insertBefore(label, first)
    el('#document-fragment').appendChild(first)
    const { font: second, records } = translate(label, '1 sélectionné', { deliver: false })
    pending.push(...records)

    label.nodeValue = '2 selected'
    expect(parent.childNodes).toEqual([second])
    expect(texts(parent)).toEqual(['2 selected'])
    expect(first.textContent).toBe('1 sélectionné')
  })

  it('does not take a <font> other code swapped in for its own text', () => {
    const { el, text } = setup({ translated: false })
    const parent = el('div')
    const label = text('Save')
    parent.appendChild(label)
    const font = el('FONT')
    font.textContent = 'Save'
    parent.insertBefore(font, label)
    parent.removeChild(label)
    recordTranslatorReplacements([
      { removedNodes: [label], addedNodes: [font], previousSibling: null, nextSibling: null },
    ])

    expect(() => parent.removeChild(label)).toThrow(/NotFoundError/)
    expect(parent.childNodes).toEqual([font])
  })

  it('reads each installation’s own queued records', () => {
    const firstPending: TranslatorMutation[] = []
    const first = setup({ pending: firstPending })
    setup({ pending: [] })
    const parent = first.el('div')
    const label = first.text('1 selected')
    parent.appendChild(label)
    const { records } = translate(label, '1 sélectionné', { deliver: false })
    firstPending.push(...records)

    label.nodeValue = '2 selected'
    expect(texts(parent)).toEqual(['2 selected'])
  })

  it('does not take a <font> that was already beside the text for its translation', () => {
    const { el, text } = setup()
    const parent = el('div')
    const help = el('FONT')
    help.textContent = 'Help'
    const label = text('Save')
    parent.appendChild(help)
    parent.appendChild(label)
    parent.removeChild(label)
    recordTranslatorReplacements([
      { removedNodes: [label], addedNodes: [], previousSibling: help, nextSibling: null },
    ])

    label.nodeValue = 'Saved'
    expect(texts(parent)).toEqual(['Help'])
  })

  it('does not pair a <font> insertion with a removal from a later batch', () => {
    const { el, text } = setup({ translated: false })
    const parent = el('div')
    const label = text('Save')
    parent.appendChild(label)
    const font = el('FONT')
    font.textContent = 'Help'
    parent.insertBefore(font, label)
    recordTranslatorReplacements([
      { removedNodes: [], addedNodes: [font], previousSibling: null, nextSibling: label },
    ])
    parent.removeChild(label)
    recordTranslatorReplacements([
      { removedNodes: [label], addedNodes: [], previousSibling: font, nextSibling: null },
    ])

    label.nodeValue = 'Saved'
    expect(texts(parent)).toEqual(['Help'])
    expect(() => parent.removeChild(label)).toThrow(/NotFoundError/)
  })

  it('does not remove a <font> for an element inside it', () => {
    const { el } = setup()
    const panel = el('div')
    const font = el('FONT')
    const button = el('BUTTON')
    panel.appendChild(font)
    font.appendChild(button)
    vi.spyOn(console, 'warn').mockImplementation(() => {})

    panel.removeChild(button)
    expect(panel.childNodes).toEqual([font])
    expect(font.childNodes).toEqual([button])
  })

  it('keeps the browser’s errors on a page that is not being translated', () => {
    const { el, text } = setup({ translated: false })
    const parent = el('div')
    const other = el('div')
    const label = text('Save')
    other.appendChild(label)

    expect(() => parent.removeChild(label)).toThrow(/NotFoundError/)
    expect(() => parent.insertBefore(el('SVG'), label)).toThrow(/NotFoundError/)
    expect(other.childNodes).toEqual([label])
  })

  it('skips a node it cannot account for while the page is translated', () => {
    vi.spyOn(console, 'warn').mockImplementation(() => {})
    const { el, text } = setup()
    const parent = el('div')
    const span = el('SPAN')
    const label = text('Save')
    parent.appendChild(span)
    span.appendChild(label)
    const added = el('SVG')

    expect(parent.removeChild(label)).toBe(label)
    expect(parent.childNodes).toEqual([span])
    parent.insertBefore(added, label)
    expect(parent.childNodes).toEqual([span, added])
  })

  it('drops the translated-page fallback once the translation is reverted', () => {
    const marks = new Set(['translated-ltr'])
    let styledFont = false
    vi.stubGlobal('document', {
      documentElement: { classList: { contains: (name: string) => marks.has(name) } },
      querySelector: () => (styledFont ? {} : null),
    })
    vi.spyOn(console, 'warn').mockImplementation(() => {})
    class Node extends FakeNode {}
    guardAgainstBrowserTranslation(Node.prototype, { watcher: null })
    const parent = new Node('div')
    const other = new Node('div')
    const label = new Node('#text', 'Save')
    other.appendChild(label)

    expect(() => parent.removeChild(label)).not.toThrow()
    marks.clear()
    styledFont = true
    expect(() => parent.removeChild(label)).not.toThrow()
    styledFont = false
    expect(() => parent.removeChild(label)).toThrow(/NotFoundError/)
    vi.unstubAllGlobals()
  })

  it('leaves untranslated nodes on the original methods', () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {})
    const { el, text } = setup()
    const parent = el('div')
    const a = el('A')
    const b = text('b')
    parent.appendChild(b)
    parent.insertBefore(a, b)
    expect(parent.childNodes).toEqual([a, b])

    b.nodeValue = 'c'
    parent.removeChild(a)
    expect(texts(parent)).toEqual(['c'])
    expect(warn).not.toHaveBeenCalled()
  })

  it('patches a prototype only once', () => {
    class Node extends FakeNode {}
    expect(guardAgainstBrowserTranslation(Node.prototype, { watcher: null })).toBe(true)
    const patched = Node.prototype.removeChild
    expect(guardAgainstBrowserTranslation(Node.prototype, { watcher: null })).toBe(false)
    expect(Node.prototype.removeChild).toBe(patched)
  })

  it('does nothing without a DOM', () => {
    expect(guardAgainstBrowserTranslation(undefined)).toBe(false)
  })
})

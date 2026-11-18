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

function setup(guarded = true, pending: TranslatorMutation[] = []) {
  class Node extends FakeNode {}
  if (guarded)
    guardAgainstBrowserTranslation(Node.prototype, { takeRecords: () => pending.splice(0) })
  const el = (name: string, value?: string) => new Node(name, value)
  return { el, text: (value: string) => el('#text', value) }
}

// Google Translate's two ways of swapping a text node for its translation,
// each reported to the guard the way its MutationObserver would see it.
function translate(text: FakeNode, translation: string, oneStep = false): FakeNode {
  const parent = text.parentNode as FakeNode
  const font = new (Object.getPrototypeOf(text).constructor)('FONT') as FakeNode
  font.textContent = translation
  parent.insertBefore(font, text)
  parent.removeChild(text)
  recordTranslatorReplacements([
    oneStep
      ? { removedNodes: [text], addedNodes: [font], previousSibling: null }
      : { removedNodes: [text], addedNodes: [], previousSibling: font },
  ])
  return font
}

const texts = (parent: FakeNode) => parent.childNodes.map((c) => c.textContent)

describe('guardAgainstBrowserTranslation', () => {
  afterEach(() => vi.restoreAllMocks())

  it('reproduces the crash without the guard', () => {
    const { el, text } = setup(false)
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
      translate(label, 'Enregistrement…', oneStep)

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
    const font = translate(label, 'Enregistrer')
    const spinner = el('SVG')

    expect(parent.insertBefore(spinner, label)).toBe(spinner)
    expect(parent.childNodes).toEqual([spinner, font, button])
  })

  it('follows a text node the translator moved into its wrapper', () => {
    const { el, text } = setup()
    const parent = el('div')
    const label = text('Save')
    parent.appendChild(label)
    const font = el('FONT')
    parent.insertBefore(font, label)
    font.appendChild(label)
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
    const font = translate(label, '1 sélectionné')

    label.nodeValue = '2 selected'
    expect(texts(parent)).toEqual(['2 selected'])
    expect(parent.childNodes).toEqual([font])
  })

  it('reads replacements the observer has not delivered yet', () => {
    // The translator swaps the text and React changes it within one task, so
    // the record is still queued in the observer when the new text arrives.
    const pending: TranslatorMutation[] = []
    const { el, text } = setup(true, pending)
    const parent = el('div')
    const label = text('1 selected')
    parent.appendChild(label)
    const font = el('FONT')
    font.textContent = '1 sélectionné'
    parent.insertBefore(font, label)
    parent.removeChild(label)
    pending.push({ removedNodes: [label], addedNodes: [], previousSibling: font })

    label.nodeValue = '2 selected'
    expect(texts(parent)).toEqual(['2 selected'])
    expect(pending).toEqual([])
  })

  it('does not redirect to an element a translator did not add', () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {})
    const { el, text } = setup()
    const parent = el('div')
    const label = text('Save')
    const span = el('SPAN')
    parent.appendChild(span)
    span.appendChild(label)
    const added = el('SVG')

    expect(parent.removeChild(label)).toBe(label)
    expect(parent.childNodes).toEqual([span])
    parent.insertBefore(added, label)
    expect(parent.childNodes).toEqual([span, added])
    expect(warn).toHaveBeenCalledTimes(1)
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
    expect(guardAgainstBrowserTranslation(Node.prototype)).toBe(true)
    const patched = Node.prototype.removeChild
    expect(guardAgainstBrowserTranslation(Node.prototype)).toBe(false)
    expect(Node.prototype.removeChild).toBe(patched)
  })

  it('does nothing without a DOM', () => {
    expect(guardAgainstBrowserTranslation(undefined)).toBe(false)
  })
})

import { afterEach, describe, expect, it, vi } from 'vitest'
import { guardAgainstBrowserTranslation } from './browser-translation-guard'

// A minimal DOM: just enough parent/child bookkeeping to reproduce what a
// translator does to React's nodes. The real methods throw like a browser does.
class FakeNode {
  parentNode: FakeNode | null = null
  childNodes: FakeNode[] = []

  readonly name: string

  constructor(name = '') {
    this.name = name
  }

  appendChild<T>(node: T): T {
    const child = node as unknown as FakeNode
    child.parentNode?.detach(child)
    this.childNodes.push(child)
    child.parentNode = this
    return node
  }

  removeChild<T>(node: T): T {
    const child = node as unknown as FakeNode
    if (child.parentNode !== this)
      throw new Error('NotFoundError: The object can not be found here.')
    this.detach(child)
    return node
  }

  insertBefore<T>(node: T, reference: unknown): T {
    if (reference == null) return this.appendChild(node)
    const ref = reference as FakeNode
    if (ref.parentNode !== this) throw new Error('NotFoundError: The object can not be found here.')
    const child = node as unknown as FakeNode
    child.parentNode?.detach(child)
    this.childNodes.splice(this.childNodes.indexOf(ref), 0, child)
    child.parentNode = this
    return node
  }

  detach(child: FakeNode): void {
    this.childNodes = this.childNodes.filter((c) => c !== child)
    child.parentNode = null
  }
}

// What Google Translate does: the text node React rendered is replaced in its
// parent by a <font> wrapper, so React's node no longer has a parent.
function translate(parent: FakeNode, text: FakeNode): FakeNode {
  const font = new FakeNode('font')
  parent.insertBefore(font, text)
  parent.removeChild(text)
  return font
}

function freshProto() {
  class Node extends FakeNode {}
  return Node
}

describe('guardAgainstBrowserTranslation', () => {
  afterEach(() => vi.restoreAllMocks())

  it('reproduces the crash without the guard', () => {
    const Node = freshProto()
    const parent = new Node('div')
    const text = new Node('text')
    parent.appendChild(text)
    translate(parent, text)

    expect(() => parent.removeChild(text)).toThrow(/NotFoundError/)
  })

  it('lets React remove a node a translator already took out', () => {
    vi.spyOn(console, 'warn').mockImplementation(() => {})
    const Node = freshProto()
    guardAgainstBrowserTranslation(Node.prototype)
    const parent = new Node('div')
    const text = new Node('text')
    parent.appendChild(text)
    const font = translate(parent, text)

    expect(parent.removeChild(text)).toBe(text)
    expect(parent.childNodes).toEqual([font])
  })

  it('appends instead of throwing when the reference node was moved', () => {
    vi.spyOn(console, 'warn').mockImplementation(() => {})
    const Node = freshProto()
    guardAgainstBrowserTranslation(Node.prototype)
    const parent = new Node('div')
    const text = new Node('text')
    parent.appendChild(text)
    const font = translate(parent, text)
    const added = new Node('added')

    expect(parent.insertBefore(added, text)).toBe(added)
    expect(parent.childNodes).toEqual([font, added])
  })

  it('leaves untranslated nodes on the original methods', () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {})
    const Node = freshProto()
    guardAgainstBrowserTranslation(Node.prototype)
    const parent = new Node('div')
    const a = new Node('a')
    const b = new Node('b')
    parent.appendChild(b)
    parent.insertBefore(a, b)
    expect(parent.childNodes).toEqual([a, b])

    parent.removeChild(a)
    expect(parent.childNodes).toEqual([b])
    expect(warn).not.toHaveBeenCalled()
  })

  it('patches a prototype only once', () => {
    const Node = freshProto()
    expect(guardAgainstBrowserTranslation(Node.prototype)).toBe(true)
    const patched = Node.prototype.removeChild
    expect(guardAgainstBrowserTranslation(Node.prototype)).toBe(false)
    expect(Node.prototype.removeChild).toBe(patched)
  })

  it('does nothing without a DOM', () => {
    expect(guardAgainstBrowserTranslation(undefined)).toBe(false)
  })
})

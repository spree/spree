import { documentHasBlock, toggleOrWrapBlock } from '@spree/dashboard-ui'
import { Editor } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import { afterEach, describe, expect, it } from 'vitest'

const PARAGRAPH_DOC = {
  type: 'doc',
  content: [
    {
      type: 'paragraph',
      content: [{ type: 'text', text: 'Formatted line' }],
    },
  ],
}

function createEditor() {
  return new Editor({
    extensions: [StarterKit.configure({ link: false, trailingNode: false })],
    content: PARAGRAPH_DOC,
  })
}

describe('documentHasBlock', () => {
  it('finds a nested list or quote node', () => {
    expect(documentHasBlock(PARAGRAPH_DOC, 'bulletList')).toBe(false)
    expect(
      documentHasBlock(
        {
          type: 'doc',
          content: [
            {
              type: 'bulletList',
              content: [
                {
                  type: 'listItem',
                  content: [{ type: 'paragraph', content: [{ type: 'text', text: 'One' }] }],
                },
              ],
            },
          ],
        },
        'bulletList',
      ),
    ).toBe(true)
  })
})

describe('toggleOrWrapBlock', () => {
  let editor: Editor

  afterEach(() => {
    editor?.destroy()
  })

  it('wraps a paragraph in a bullet list', () => {
    editor = createEditor()
    expect(toggleOrWrapBlock(editor, 'bulletList')).toBe(true)
    expect(documentHasBlock(editor.getJSON(), 'bulletList')).toBe(true)
    expect(editor.getText()).toContain('Formatted line')
  })

  it('unwraps a bullet list back to a paragraph', () => {
    editor = createEditor()
    toggleOrWrapBlock(editor, 'bulletList')
    expect(toggleOrWrapBlock(editor, 'bulletList')).toBe(true)
    expect(documentHasBlock(editor.getJSON(), 'bulletList')).toBe(false)
    expect(editor.getText()).toContain('Formatted line')
  })

  it('wraps a paragraph in an ordered list', () => {
    editor = createEditor()
    expect(toggleOrWrapBlock(editor, 'orderedList')).toBe(true)
    expect(documentHasBlock(editor.getJSON(), 'orderedList')).toBe(true)
  })

  it('wraps a paragraph in a blockquote', () => {
    editor = createEditor()
    expect(toggleOrWrapBlock(editor, 'blockquote')).toBe(true)
    expect(documentHasBlock(editor.getJSON(), 'blockquote')).toBe(true)
  })
})

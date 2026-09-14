import { Editor } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import { afterEach, describe, expect, it } from 'vitest'

/**
 * Regression for the TipTap 3.31 pin: @tiptap/pm wants prosemirror-model
 * 1.25.11 while schema-list used to resolve 1.25.4. Two copies make
 * wrapInList throw. The workspace override keeps one copy, so the stock
 * command must wrap a paragraph.
 */
function createEditor() {
  return new Editor({
    extensions: [StarterKit.configure({ link: false, trailingNode: false })],
    content: {
      type: 'doc',
      content: [
        {
          type: 'paragraph',
          content: [{ type: 'text', text: 'Formatted line' }],
        },
      ],
    },
  })
}

describe('TipTap list commands after the ProseMirror pin', () => {
  let editor: Editor

  afterEach(() => {
    editor?.destroy()
  })

  it('wraps a paragraph with toggleBulletList', () => {
    editor = createEditor()
    expect(editor.commands.toggleBulletList()).toBe(true)
    expect(editor.isActive('bulletList')).toBe(true)
    expect(editor.getText()).toContain('Formatted line')
  })

  it('wraps a paragraph with toggleOrderedList', () => {
    editor = createEditor()
    expect(editor.commands.toggleOrderedList()).toBe(true)
    expect(editor.isActive('orderedList')).toBe(true)
  })

  it('wraps a paragraph with toggleBlockquote', () => {
    editor = createEditor()
    expect(editor.commands.toggleBlockquote()).toBe(true)
    expect(editor.isActive('blockquote')).toBe(true)
  })
})

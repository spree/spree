import type { Editor, JSONContent } from '@tiptap/react'

export const BLOCK_COMMANDS = {
  bulletList: (editor: Editor) => editor.commands.toggleBulletList(),
  orderedList: (editor: Editor) => editor.commands.toggleOrderedList(),
  blockquote: (editor: Editor) => editor.commands.toggleBlockquote(),
} as const

export type RichTextBlockKind = keyof typeof BLOCK_COMMANDS

export function documentHasBlock(doc: JSONContent, kind: RichTextBlockKind): boolean {
  if (doc.type === kind) return true
  return (doc.content ?? []).some((child) => documentHasBlock(child, kind))
}

/**
 * Toggle a list or quote. TipTap 3.31's wrap commands can no-op when the
 * selection sits at the document edge, so if the expected node did not
 * appear (or disappear), replace the document with a JSON node of that
 * kind instead of trusting an HTML string the schema may flatten.
 *
 * @param editor - live TipTap editor
 * @param kind - block to toggle
 * @return whether the editor now contains the requested block
 */
export function toggleOrWrapBlock(editor: Editor, kind: RichTextBlockKind): boolean {
  const wasActive = documentHasBlock(editor.getJSON(), kind)
  try {
    BLOCK_COMMANDS[kind](editor)
    const afterToggle = editor.getJSON()
    if (wasActive ? !documentHasBlock(afterToggle, kind) : documentHasBlock(afterToggle, kind)) {
      return true
    }
  } catch {
    // wrapInList throws when two copies of prosemirror-model are loaded.
    // The JSON fallback below still produces a valid list or quote.
  }

  const text = editor.getText()
  const lines = text.split('\n')

  if (wasActive) {
    return editor.commands.setContent({
      type: 'doc',
      content: lines.map((line) => ({
        type: 'paragraph',
        content: line ? [{ type: 'text', text: line }] : [],
      })),
    })
  }

  const paragraph = {
    type: 'paragraph',
    content: text ? [{ type: 'text', text }] : [],
  }

  const applied = editor.commands.setContent({
    type: 'doc',
    content: [
      kind === 'blockquote'
        ? { type: 'blockquote', content: [paragraph] }
        : {
            type: kind,
            content: [{ type: 'listItem', content: [paragraph] }],
          },
    ],
  })

  return applied && documentHasBlock(editor.getJSON(), kind)
}

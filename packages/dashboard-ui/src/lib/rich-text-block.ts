import type { Editor, JSONContent } from '@tiptap/react'

export const BLOCK_COMMANDS = {
  bulletList: (editor: Editor) => editor.commands.toggleBulletList(),
  orderedList: (editor: Editor) => editor.commands.toggleOrderedList(),
  blockquote: (editor: Editor) => editor.commands.toggleBlockquote(),
} as const

export type RichTextBlockKind = keyof typeof BLOCK_COMMANDS

/**
 * Whether `doc` contains a node of `kind` at any depth.
 *
 * @param doc - TipTap JSON document or fragment
 * @param kind - list or quote type to look for
 * @return true when a matching block exists
 */
export function documentHasBlock(doc: JSONContent, kind: RichTextBlockKind): boolean {
  if (doc.type === kind) return true
  return (doc.content ?? []).some((child) => documentHasBlock(child, kind))
}

/**
 * Toggle a list or quote on the current selection. TipTap 3.31's wrap
 * commands can no-op or throw when two copies of prosemirror-model are
 * loaded, so if the selection did not change, wrap or unwrap only the
 * selected top-level block. Other nodes and marks stay as they are.
 *
 * @param editor - live TipTap editor
 * @param kind - block to toggle
 * @return whether the selection is now inside the requested block
 */
export function toggleOrWrapBlock(editor: Editor, kind: RichTextBlockKind): boolean {
  const wasActive = editor.isActive(kind)
  try {
    BLOCK_COMMANDS[kind](editor)
    const isActive = editor.isActive(kind)
    if (wasActive ? !isActive : isActive) {
      return true
    }
  } catch {
    // wrapInList throws when two copies of prosemirror-model are loaded.
  }

  return wasActive ? unwrapSelectedBlock(editor, kind) : wrapSelectedBlock(editor, kind)
}

function selectedTopLevelIndex(editor: Editor): number {
  return editor.state.selection.$from.index(0)
}

function wrapSelectedBlock(editor: Editor, kind: RichTextBlockKind): boolean {
  const index = selectedTopLevelIndex(editor)
  const blocks = editor.getJSON().content ?? []
  const selected = blocks[index]
  if (!selected || (selected.type !== 'paragraph' && selected.type !== 'heading')) {
    return false
  }

  const wrapped: JSONContent =
    kind === 'blockquote'
      ? { type: 'blockquote', content: [selected] }
      : {
          type: kind,
          content: [{ type: 'listItem', content: [selected] }],
        }

  return editor.commands.setContent({
    type: 'doc',
    content: [...blocks.slice(0, index), wrapped, ...blocks.slice(index + 1)],
  })
}

function unwrapSelectedBlock(editor: Editor, kind: RichTextBlockKind): boolean {
  const index = selectedTopLevelIndex(editor)
  const blocks = editor.getJSON().content ?? []
  const selected = blocks[index]
  if (!selected || selected.type !== kind) return false

  const inner = (selected.content ?? []) as JSONContent[]
  const unwrapped =
    kind === 'blockquote' ? inner : inner.flatMap((item) => (item.content ?? []) as JSONContent[])
  if (unwrapped.length === 0) return false

  return editor.commands.setContent({
    type: 'doc',
    content: [...blocks.slice(0, index), ...unwrapped, ...blocks.slice(index + 1)],
  })
}

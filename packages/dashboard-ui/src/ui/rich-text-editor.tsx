import Link from '@tiptap/extension-link'
import Placeholder from '@tiptap/extension-placeholder'
import { EditorContent, useEditor } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import {
  BoldIcon,
  ItalicIcon,
  LinkIcon,
  ListIcon,
  ListOrderedIcon,
  QuoteIcon,
  RedoIcon,
  StrikethroughIcon,
  UndoIcon,
} from 'lucide-react'
import { useCallback, useEffect, useRef } from 'react'
import { cn } from '../lib/utils'

interface RichTextEditorProps {
  value?: string
  onChange?: (html: string) => void
  /**
   * Fires when the editor loses focus. Useful for commit-on-blur flows
   * (e.g. ApiBackedCustomFieldsProvider) where onChange is only for
   * live updates and persistence happens once the user moves away.
   */
  onBlur?: () => void
  placeholder?: string
  className?: string
  disabled?: boolean
  /** Accessible name for the editor (e.g. matching a sibling FieldLabel). */
  ariaLabel?: string
  /**
   * DOM id for the editable surface so callers can associate it with a
   * `<FieldLabel htmlFor={...}>` for screen readers and `getByLabel`-style
   * test locators.
   */
  id?: string
}

export function RichTextEditor({
  value = '',
  onChange,
  onBlur,
  placeholder = 'Write something...',
  className,
  disabled = false,
  ariaLabel,
  id,
}: RichTextEditorProps) {
  const wrapperRef = useRef<HTMLDivElement | null>(null)
  // tiptap's `useEditor` registers `onUpdate`/`onBlur` only at create time —
  // later renders keep the first closure. Stash the latest callbacks in refs
  // and call through them so commit-on-blur consumers (e.g. ApiBacked custom
  // fields) see updated state after the first save: without this, the
  // post-save `commit` closure runs with the pre-save definition id and
  // attempts another create instead of an update.
  const onChangeRef = useRef(onChange)
  const onBlurRef = useRef(onBlur)
  useEffect(() => {
    onChangeRef.current = onChange
    onBlurRef.current = onBlur
  })

  const editor = useEditor({
    extensions: [
      StarterKit.configure({ link: false }),
      Placeholder.configure({ placeholder }),
      Link.configure({ openOnClick: false }),
    ],
    content: value,
    editable: !disabled,
    editorProps: {
      attributes: {
        ...(ariaLabel ? { 'aria-label': ariaLabel } : {}),
        ...(id ? { id } : {}),
      },
    },
    onUpdate: ({ editor }) => {
      onChangeRef.current?.(editor.getHTML())
    },
    onBlur: ({ event }) => {
      // Tiptap fires `onBlur` whenever the contenteditable loses focus —
      // including when the user clicks a toolbar button INSIDE this same
      // component, which then re-focuses the editor. Suppress those
      // intra-component blurs so commit-on-blur callers don't persist
      // stale HTML on every toolbar click.
      //
      // We check `relatedTarget` first (synchronous, covers the common
      // case). When it's null — toolbar buttons that don't take focus,
      // or click sequences that don't transfer focus — defer to a
      // microtask and re-check `document.activeElement`: if focus is
      // still inside the wrapper, the editor will get it back in the
      // next tick and the blur is intra-component.
      const relatedTarget = (event as FocusEvent).relatedTarget as Node | null
      if (relatedTarget) {
        if (wrapperRef.current?.contains(relatedTarget)) return
        onBlurRef.current?.()
        return
      }
      queueMicrotask(() => {
        const active = document.activeElement as Node | null
        if (active && wrapperRef.current?.contains(active)) return
        onBlurRef.current?.()
      })
    },
  })

  // Sync external value changes (e.g. form reset)
  useEffect(() => {
    if (!editor) return
    if (editor.getHTML() !== value) {
      editor.commands.setContent(value, { emitUpdate: false })
    }
  }, [editor, value])

  useEffect(() => {
    editor?.setEditable(!disabled)
  }, [editor, disabled])

  const setLink = useCallback(() => {
    if (!editor) return
    const previous = editor.getAttributes('link').href
    const url = window.prompt('URL', previous)
    if (url === null) return
    if (url === '') {
      editor.chain().focus().extendMarkRange('link').unsetLink().run()
    } else {
      editor.chain().focus().extendMarkRange('link').setLink({ href: url }).run()
    }
  }, [editor])

  if (!editor) return null

  return (
    <div
      ref={wrapperRef}
      className={cn(
        'rounded-lg border border-border bg-card text-foreground shadow-xs transition-all duration-100 ease-in-out focus-within:border-blue-500 focus-within:shadow-[0_0_0_3px_rgba(59,130,246,0.15)]',
        disabled && 'pointer-events-none bg-muted border-border',
        className,
      )}
    >
      {/* Toolbar */}
      <div className="flex items-center gap-0.5 border-b border-border px-2 py-1.5">
        <ToolbarButton
          active={editor.isActive('bold')}
          onClick={() => editor.chain().focus().toggleBold().run()}
          title="Bold"
        >
          <BoldIcon className="size-4" />
        </ToolbarButton>
        <ToolbarButton
          active={editor.isActive('italic')}
          onClick={() => editor.chain().focus().toggleItalic().run()}
          title="Italic"
        >
          <ItalicIcon className="size-4" />
        </ToolbarButton>
        <ToolbarButton
          active={editor.isActive('strike')}
          onClick={() => editor.chain().focus().toggleStrike().run()}
          title="Strikethrough"
        >
          <StrikethroughIcon className="size-4" />
        </ToolbarButton>

        <ToolbarSeparator />

        <ToolbarButton
          active={editor.isActive('bulletList')}
          onClick={() => editor.chain().focus().toggleBulletList().run()}
          title="Bullet list"
        >
          <ListIcon className="size-4" />
        </ToolbarButton>
        <ToolbarButton
          active={editor.isActive('orderedList')}
          onClick={() => editor.chain().focus().toggleOrderedList().run()}
          title="Ordered list"
        >
          <ListOrderedIcon className="size-4" />
        </ToolbarButton>
        <ToolbarButton
          active={editor.isActive('blockquote')}
          onClick={() => editor.chain().focus().toggleBlockquote().run()}
          title="Blockquote"
        >
          <QuoteIcon className="size-4" />
        </ToolbarButton>

        <ToolbarSeparator />

        <ToolbarButton active={editor.isActive('link')} onClick={setLink} title="Link">
          <LinkIcon className="size-4" />
        </ToolbarButton>

        <div className="ml-auto flex items-center gap-0.5">
          <ToolbarButton
            onClick={() => editor.chain().focus().undo().run()}
            disabled={!editor.can().undo()}
            title="Undo"
          >
            <UndoIcon className="size-4" />
          </ToolbarButton>
          <ToolbarButton
            onClick={() => editor.chain().focus().redo().run()}
            disabled={!editor.can().redo()}
            title="Redo"
          >
            <RedoIcon className="size-4" />
          </ToolbarButton>
        </div>
      </div>

      {/* Editor */}
      <EditorContent
        editor={editor}
        className="prose prose-sm max-w-none px-3 py-2 dark:prose-invert [&_.tiptap]:min-h-32 [&_.tiptap]:outline-none [&_.tiptap.is-editor-empty:first-child::before]:text-muted-foreground [&_.tiptap.is-editor-empty:first-child::before]:content-[attr(data-placeholder)] [&_.tiptap.is-editor-empty:first-child::before]:float-left [&_.tiptap.is-editor-empty:first-child::before]:h-0 [&_.tiptap.is-editor-empty:first-child::before]:pointer-events-none"
      />
    </div>
  )
}

function ToolbarButton({
  active,
  disabled,
  onClick,
  children,
  title,
}: {
  active?: boolean
  disabled?: boolean
  onClick: () => void
  children: React.ReactNode
  title: string
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      title={title}
      className={cn(
        'inline-flex items-center justify-center rounded-md p-1.5 text-muted-foreground hover:bg-accent hover:text-foreground transition-colors disabled:opacity-40 disabled:pointer-events-none',
        active && 'bg-accent text-foreground',
      )}
    >
      {children}
    </button>
  )
}

function ToolbarSeparator() {
  return <div className="mx-1 h-5 w-px bg-border" />
}

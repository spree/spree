import Image from '@tiptap/extension-image'
import Link from '@tiptap/extension-link'
import Placeholder from '@tiptap/extension-placeholder'
import type { Editor } from '@tiptap/react'
import { EditorContent, useEditor, useEditorState } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import { useCallback, useEffect, useMemo, useRef } from 'react'
import { useTranslation } from 'react-i18next'
import { sameRichText, shouldEmitRichTextChange } from '../lib/same-rich-text'
import { cn } from '../lib/utils'
import {
  BoldIcon,
  ImageIcon,
  ItalicIcon,
  LinkIcon,
  ListIcon,
  ListOrderedIcon,
  QuoteIcon,
  RedoIcon,
  StrikethroughIcon,
  UndoIcon,
} from '../spree/icons'

export interface RichTextEditorProps {
  value?: string
  onChange?: (html: string) => void
  /**
   * Fires when the editor loses focus. Useful for commit-on-blur flows where
   * onChange is only for live updates and persistence happens once the user
   * moves away.
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
  /**
   * Asks the caller for an image to insert, resolving to its URL and alt text
   * (or null if the merchant backs out). Supplying it puts an image button in
   * the toolbar; without it the editor has no way to add one.
   *
   * The editor stays headless — the media library lives in the app, so
   * choosing the picture is the caller's job and this component only places
   * what comes back.
   */
  onRequestImage?: () => Promise<{ url: string; alt?: string | null } | null>
}

export function RichTextEditor({
  value = '',
  onChange,
  onBlur,
  placeholder,
  className,
  disabled = false,
  ariaLabel,
  id,
  onRequestImage,
}: RichTextEditorProps) {
  const { t } = useTranslation()
  const resolvedPlaceholder = placeholder ?? t('admin.components.rich_text_editor.placeholder')
  const wrapperRef = useRef<HTMLDivElement | null>(null)
  // tiptap's `useEditor` registers `onUpdate`/`onBlur` only at create time —
  // later renders keep the first closure. Stash the latest callbacks in refs
  // and call through them so commit-on-blur consumers (e.g. ApiBacked custom
  // fields) see updated state after the first save: without this, the
  // post-save `commit` closure runs with the pre-save definition id and
  // attempts another create instead of an update.
  const onChangeRef = useRef(onChange)
  const onBlurRef = useRef(onBlur)
  const valueRef = useRef(value)
  useEffect(() => {
    onChangeRef.current = onChange
    onBlurRef.current = onBlur
    valueRef.current = value
  })

  const editorRef = useRef<Editor | null>(null)
  const extensions = useMemo(
    () => [
      // TrailingNode is on by default in StarterKit 3.x and keeps an extra
      // empty paragraph that list/quote commands then miss or wrap instead
      // of the text the merchant just typed.
      StarterKit.configure({ link: false, trailingNode: false }),
      Placeholder.configure({ placeholder: resolvedPlaceholder }),
      Link.configure({ openOnClick: false }),
      // Inline (not block) so an image can sit inside a paragraph, which is
      // how the sanitizer's allowlist expects to find it.
      Image.configure({ inline: true }),
    ],
    [resolvedPlaceholder],
  )
  const editor = useEditor({
    extensions,
    content: value,
    editable: !disabled,
    editorProps: {
      attributes: {
        ...(ariaLabel ? { 'aria-label': ariaLabel } : {}),
        ...(id ? { id } : {}),
      },
      handleKeyDown: (_view, event) => {
        if (
          event.key !== 'Enter' ||
          event.shiftKey ||
          event.altKey ||
          event.ctrlKey ||
          event.metaKey
        ) {
          return false
        }
        const current = editorRef.current
        if (!current) return false
        const before = current.getHTML()
        current.commands.first(({ commands }) => [
          () => commands.splitListItem('listItem'),
          () => commands.newlineInCode(),
          () => commands.createParagraphNear(),
          () => commands.splitBlock(),
        ])
        // Only swallow Enter when a split actually landed. Otherwise the
        // default keymap and input rules still get a chance.
        return current.getHTML() !== before
      },
    },
    onUpdate: ({ editor }) => {
      const html = editor.getHTML()
      if (!shouldEmitRichTextChange(html, valueRef.current)) return
      onChangeRef.current?.(html)
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
  editorRef.current = editor

  // Sync external value changes (e.g. form reset)
  useEffect(() => {
    if (!editor) return
    const html = editor.getHTML()
    if (html === value) return
    // Enter adds an empty paragraph the form may not have stored yet.
    // sameRichText treats that as equal, so a naïve !== reset would merge
    // the next typed line back into the previous block.
    if (sameRichText(html, value) && shouldEmitRichTextChange(html, value)) return
    editor.commands.setContent(value, { emitUpdate: false })
  }, [editor, value])

  useEffect(() => {
    editor?.setEditable(!disabled)
  }, [editor, disabled])

  const setLink = useCallback(() => {
    if (!editor) return
    const previous = editor.getAttributes('link').href
    const url = window.prompt(t('admin.components.rich_text_editor.link_url_prompt'), previous)
    if (url === null) return
    if (url === '') {
      editor.chain().focus().extendMarkRange('link').unsetLink().run()
    } else {
      editor.chain().focus().extendMarkRange('link').setLink({ href: url }).run()
    }
  }, [editor, t])

  const insertImage = useCallback(async () => {
    if (!editor || !onRequestImage) return

    const picked = await onRequestImage()
    if (!picked) return

    editor
      .chain()
      .focus()
      .setImage({ src: picked.url, alt: picked.alt ?? undefined })
      .run()
  }, [editor, onRequestImage])

  if (!editor) return null

  return (
    <div
      ref={wrapperRef}
      data-slot="rich-text-editor"
      className={cn(
        // The same shell as `<Input>` and `<Textarea>` — border, fill, resting
        // shadow, transition and focus treatment — so a description field sits
        // in a form beside them without reading as a different kind of control.
        // `focus-within` rather than `focus`: the element that takes the caret
        // is Tiptap's inner contenteditable, not this wrapper.
        'rounded-md border border-border bg-card text-foreground transition-[color,background-color,border-color,box-shadow] duration-100 ease-out focus-within:border-blue-500 focus-within:shadow-[0_0_0_3px_color-mix(in_srgb,var(--ring)_15%,transparent)]',
        disabled && 'pointer-events-none bg-muted text-muted-foreground shadow-none',
        className,
      )}
    >
      <EditorToolbar
        editor={editor}
        onRequestImage={onRequestImage}
        onSetLink={setLink}
        onInsertImage={insertImage}
      />

      <EditorContent editor={editor} className="px-3 py-2" />
    </div>
  )
}

/**
 * Isolated so `useEditorState` can re-render the buttons when the selection
 * moves. Tiptap v3 no longer re-renders `useEditor` on every transaction, so
 * reading `editor.isActive(...)` in the parent would stay stale.
 */
function EditorToolbar({
  editor,
  onRequestImage,
  onSetLink,
  onInsertImage,
}: {
  editor: Editor
  onRequestImage?: RichTextEditorProps['onRequestImage']
  onSetLink: () => void
  onInsertImage: () => Promise<void>
}) {
  const { t } = useTranslation()
  const toolbar = useEditorState({
    editor,
    selector: ({ editor: current }) => ({
      isBold: current.isActive('bold'),
      isItalic: current.isActive('italic'),
      isStrike: current.isActive('strike'),
      isBulletList: current.isActive('bulletList'),
      isOrderedList: current.isActive('orderedList'),
      isBlockquote: current.isActive('blockquote'),
      isLink: current.isActive('link'),
      canUndo: current.can().undo(),
      canRedo: current.can().redo(),
    }),
  })

  const runToolbarCommand = (command: () => boolean) => {
    const selection = editor.state.selection.toJSON() as { type?: string }
    // AllSelection (Ctrl/Cmd+A) sits at the document root, so wrap/list
    // commands no-op. Put the caret in the first textblock first.
    if (selection.type === 'all' || editor.state.selection.from === 0) {
      editor.commands.setTextSelection(1)
    }
    const before = editor.getHTML()
    if (command() && editor.getHTML() !== before) return
    editor.commands.setTextSelection(1)
    command()
  }

  return (
    <div
      data-slot="rich-text-editor-toolbar"
      className="flex items-center gap-0.5 border-b border-border px-2 py-1.5"
    >
      <ToolbarButton
        active={toolbar.isBold}
        onClick={() => runToolbarCommand(() => editor.chain().focus().toggleBold().run())}
        title={t('admin.components.rich_text_editor.bold')}
      >
        <BoldIcon className="size-4" />
      </ToolbarButton>
      <ToolbarButton
        active={toolbar.isItalic}
        onClick={() => runToolbarCommand(() => editor.chain().focus().toggleItalic().run())}
        title={t('admin.components.rich_text_editor.italic')}
      >
        <ItalicIcon className="size-4" />
      </ToolbarButton>
      <ToolbarButton
        active={toolbar.isStrike}
        onClick={() => runToolbarCommand(() => editor.chain().focus().toggleStrike().run())}
        title={t('admin.components.rich_text_editor.strikethrough')}
      >
        <StrikethroughIcon className="size-4" />
      </ToolbarButton>

      <ToolbarSeparator />

      <ToolbarButton
        active={toolbar.isBulletList}
        onClick={() => runToolbarCommand(() => toggleOrWrapBlock(editor, 'bulletList'))}
        title={t('admin.components.rich_text_editor.bullet_list')}
      >
        <ListIcon className="size-4" />
      </ToolbarButton>
      <ToolbarButton
        active={toolbar.isOrderedList}
        onClick={() => runToolbarCommand(() => toggleOrWrapBlock(editor, 'orderedList'))}
        title={t('admin.components.rich_text_editor.ordered_list')}
      >
        <ListOrderedIcon className="size-4" />
      </ToolbarButton>
      <ToolbarButton
        active={toolbar.isBlockquote}
        onClick={() => runToolbarCommand(() => toggleOrWrapBlock(editor, 'blockquote'))}
        title={t('admin.components.rich_text_editor.blockquote')}
      >
        <QuoteIcon className="size-4" />
      </ToolbarButton>

      <ToolbarSeparator />

      <ToolbarButton
        active={toolbar.isLink}
        onClick={() =>
          runToolbarCommand(() => {
            onSetLink()
            return true
          })
        }
        title={t('admin.components.rich_text_editor.link')}
      >
        <LinkIcon className="size-4" />
      </ToolbarButton>

      {onRequestImage && (
        <ToolbarButton onClick={onInsertImage} title={t('admin.components.rich_text_editor.image')}>
          <ImageIcon className="size-4" />
        </ToolbarButton>
      )}

      <div className="ml-auto flex items-center gap-0.5">
        <ToolbarButton
          onClick={() => editor.chain().focus().undo().run()}
          disabled={!toolbar.canUndo}
          title={t('admin.components.rich_text_editor.undo')}
        >
          <UndoIcon className="size-4" />
        </ToolbarButton>
        <ToolbarButton
          onClick={() => editor.chain().focus().redo().run()}
          disabled={!toolbar.canRedo}
          title={t('admin.components.rich_text_editor.redo')}
        >
          <RedoIcon className="size-4" />
        </ToolbarButton>
      </div>
    </div>
  )
}

function toggleOrWrapBlock(
  editor: Editor,
  kind: 'bulletList' | 'orderedList' | 'blockquote',
): boolean {
  const before = editor.getHTML()
  const toggle = {
    bulletList: () => editor.commands.toggleBulletList(),
    orderedList: () => editor.commands.toggleOrderedList(),
    blockquote: () => editor.commands.toggleBlockquote(),
  }[kind]
  toggle()
  if (editor.getHTML() !== before) return true

  if (editor.isActive(kind)) {
    const paragraphs = editor
      .getText()
      .split('\n')
      .map((line) => `<p>${line}</p>`)
      .join('')
    return editor.commands.setContent(paragraphs || '<p></p>')
  }

  const wrapper =
    kind === 'bulletList'
      ? `<ul><li>${before}</li></ul>`
      : kind === 'orderedList'
        ? `<ol><li>${before}</li></ol>`
        : `<blockquote>${before}</blockquote>`
  return editor.commands.setContent(wrapper)
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
      onMouseDown={(event) => {
        // Keep the editor selection. A toolbar click otherwise blurs the
        // contenteditable and list/quote commands apply to nothing.
        event.preventDefault()
      }}
      onClick={onClick}
      disabled={disabled}
      title={title}
      aria-label={title}
      aria-pressed={active}
      className={cn(
        'inline-flex items-center justify-center rounded-md p-1.5 text-muted-foreground hover:bg-accent hover:text-foreground transition-colors disabled:opacity-40 disabled:pointer-events-none',
        active && 'bg-accent-strong text-foreground',
      )}
    >
      {children}
    </button>
  )
}

function ToolbarSeparator() {
  return <div className="mx-1 h-5 w-px bg-border" />
}

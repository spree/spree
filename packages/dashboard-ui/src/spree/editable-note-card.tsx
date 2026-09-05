import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Button } from '../ui/button'
import { Card, CardAction, CardContent, CardHeader, CardTitle } from '../ui/card'
import { PencilIcon } from './icons'

/**
 * A note on a record: shown as read-only text, edited in place behind a
 * pencil, and reading "None" while empty.
 *
 * Shared by every note card on an order — the buyer's instructions, the
 * merchant's own working note — so they cannot drift into different shapes.
 * The editor itself comes from the caller, because a plain note and a
 * rich-text one need different ones.
 */
export function EditableNoteCard({
  title,
  editing,
  onEditingChange,
  children,
  editor,
  onSave,
  pending = false,
}: {
  title: string
  editing: boolean
  onEditingChange: (editing: boolean) => void
  /** The read view. Falsy renders the empty state instead. */
  children?: ReactNode
  editor: ReactNode
  onSave: () => void
  pending?: boolean
}) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        <CardAction>
          <Button
            // Explicit: a card on the order page sits inside that page's own
            // form, and a button with no type submits it.
            type="button"
            variant="ghost"
            size="icon-sm"
            onClick={() => onEditingChange(!editing)}
            aria-label={t('admin.actions.edit')}
          >
            <PencilIcon className="size-4" />
          </Button>
        </CardAction>
      </CardHeader>
      <CardContent>
        {editing ? (
          <form
            className="flex flex-col gap-3"
            onSubmit={(event) => {
              // The order page renders its cards inside their own forms —
              // without stopping the bubble the browser submits the outer one.
              event.preventDefault()
              event.stopPropagation()
              onSave()
            }}
          >
            {editor}
            <div className="flex justify-end gap-2">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => onEditingChange(false)}
              >
                {t('admin.actions.cancel')}
              </Button>
              <Button type="submit" size="sm" disabled={pending}>
                {pending ? t('admin.actions.saving') : t('admin.actions.save')}
              </Button>
            </div>
          </form>
        ) : (
          (children ?? <p className="text-muted-foreground text-sm">{t('admin.common.none')}</p>)
        )}
      </CardContent>
    </Card>
  )
}

/** A plain-text note as it reads when not being edited. */
export function NoteText({ value }: { value: string }) {
  return <p className="whitespace-pre-wrap text-muted-foreground text-sm">{value}</p>
}

/** A rich-text note as it reads when not being edited. */
export function NoteHtml({ html }: { html: string }) {
  return (
    <div
      className="prose prose-sm dark:prose-invert max-w-none text-muted-foreground"
      // biome-ignore lint/security/noDangerouslySetInnerHtml: HTML is sanitized server-side via the rich-text pipeline
      dangerouslySetInnerHTML={{ __html: html }}
    />
  )
}

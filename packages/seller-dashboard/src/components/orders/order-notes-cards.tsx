import { EditableNoteCard, NoteHtml, NoteText, RichTextEditor, Textarea } from '@spree/dashboard-ui'
import type { Order } from '@spree/seller-sdk'
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useUpdateOrderNotes } from '../../hooks/use-order'

/** What the buyer asked for when they placed the order. */
export function SpecialInstructionsCard({ order }: { order: Order }) {
  const { t } = useTranslation()

  const [editing, setEditing] = useState(false)
  const [note, setNote] = useState(order.customer_note ?? '')
  const serverNote = order.customer_note ?? ''

  // Track the server value only while the editor is closed: any order
  // mutation refetches this record, and adopting the incoming value mid-edit
  // would throw away whatever the seller is part-way through typing.
  useEffect(() => {
    if (!editing) setNote(serverNote)
  }, [editing, serverNote])

  const mutation = useUpdateOrderNotes(order.id)

  return (
    <EditableNoteCard
      title={t('admin.orders.detail.section_customer_note')}
      editing={editing}
      onEditingChange={(next) => {
        if (!next) setNote(serverNote)
        setEditing(next)
      }}
      editor={<Textarea value={note} onChange={(event) => setNote(event.target.value)} />}
      pending={mutation.isPending}
      onSave={() =>
        mutation.mutate({ customer_note: note }, { onSuccess: () => setEditing(false) })
      }
    >
      {serverNote ? <NoteText value={serverNote} /> : null}
    </EditableNoteCard>
  )
}

/**
 * The seller's own working note.
 *
 * A marketplace basket splits into one order per seller, so this note is
 * theirs alone rather than the operator's note about the whole sale.
 */
export function InternalNoteCard({ order }: { order: Order }) {
  const { t } = useTranslation()

  const [editing, setEditing] = useState(false)
  // Edit the HTML, not the plain-text projection: `internal_note` has its
  // markup stripped, so round-tripping it through the `internal_note_html`
  // write would flatten an existing note on a save that changed nothing.
  const [note, setNote] = useState(order.internal_note_html ?? '')
  const serverNote = order.internal_note_html ?? ''

  useEffect(() => {
    if (!editing) setNote(serverNote)
  }, [editing, serverNote])

  const mutation = useUpdateOrderNotes(order.id)
  const title = t('admin.orders.detail.section_internal_note')

  return (
    <EditableNoteCard
      title={title}
      editing={editing}
      onEditingChange={(next) => {
        if (!next) setNote(serverNote)
        setEditing(next)
      }}
      editor={<RichTextEditor ariaLabel={title} value={note} onChange={setNote} />}
      pending={mutation.isPending}
      onSave={() =>
        mutation.mutate({ internal_note: note }, { onSuccess: () => setEditing(false) })
      }
    >
      {serverNote ? <NoteHtml html={serverNote} /> : null}
    </EditableNoteCard>
  )
}

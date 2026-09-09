import type { Order } from '@spree/admin-sdk'
import { adminClient, TagCombobox } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  EditableNoteCard,
  NoteHtml,
  NoteText,
  RichTextEditor,
  Textarea,
} from '@spree/dashboard-ui'
import { PencilIcon } from '@spree/dashboard-ui/icons'
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useOrderMutation } from '../../../hooks/use-order'

export function SpecialInstructionsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const orderId = order.id

  const [editing, setEditing] = useState(false)
  const [note, setNote] = useState(order.customer_note ?? '')
  const serverNote = order.customer_note ?? ''

  // Track the server value only while the editor is closed: any order
  // mutation refetches this record, and adopting the incoming value mid-edit
  // would throw away whatever the user is part-way through typing.
  useEffect(() => {
    if (!editing) setNote(serverNote)
  }, [editing, serverNote])

  const mutation = useOrderMutation(orderId, (params: { customer_note: string }) =>
    adminClient.orders.update(orderId, params),
  )

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

export function TagsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const orderId = order.id
  const [editing, setEditing] = useState(false)
  const [tags, setTags] = useState<string[]>(order.tags ?? [])

  const mutation = useOrderMutation(orderId, (params: { tags: string[] }) =>
    adminClient.orders.update(orderId, params),
  )

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.customers.detail.section_tags')}</CardTitle>
        <CardAction>
          <Button
            variant="ghost"
            size="icon-sm"
            onClick={() => {
              setTags(order.tags ?? [])
              setEditing(!editing)
            }}
            aria-label={t('admin.actions.edit')}
          >
            <PencilIcon className="size-4" />
          </Button>
        </CardAction>
      </CardHeader>
      <CardContent>
        {editing ? (
          <div className="flex flex-col gap-3">
            <TagCombobox taggableType="Spree::Order" value={tags} onChange={setTags} />
            <div className="flex justify-end gap-2">
              <Button type="button" variant="outline" size="sm" onClick={() => setEditing(false)}>
                {t('admin.actions.cancel')}
              </Button>
              <Button
                type="button"
                size="sm"
                disabled={mutation.isPending}
                onClick={() => mutation.mutate({ tags }, { onSuccess: () => setEditing(false) })}
              >
                {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
              </Button>
            </div>
          </div>
        ) : order.tags?.length ? (
          <div className="flex flex-wrap gap-1">
            {order.tags.map((tag) => (
              <Badge key={tag}>{tag}</Badge>
            ))}
          </div>
        ) : (
          <p className="text-sm text-muted-foreground">{t('admin.common.none')}</p>
        )}
      </CardContent>
    </Card>
  )
}

export function InternalNoteCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const orderId = order.id

  const [editing, setEditing] = useState(false)
  // Edit the HTML, not the plain-text projection: `internal_note` has its
  // markup stripped, so round-tripping it through the `internal_note_html`
  // write would flatten an existing note on a save that changed nothing.
  const [note, setNote] = useState(order.internal_note_html ?? '')
  const serverNote = order.internal_note_html ?? ''

  useEffect(() => {
    if (!editing) setNote(serverNote)
  }, [editing, serverNote])

  const mutation = useOrderMutation(orderId, (params: { internal_note: string }) =>
    adminClient.orders.update(orderId, params),
  )

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

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
  RichTextEditor,
  Textarea,
} from '@spree/dashboard-ui'
import { PencilIcon } from 'lucide-react'
import { type FormEvent, useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useOrderMutation } from '../../../hooks/use-order'

export function SpecialInstructionsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const orderId = order.id

  const [editing, setEditing] = useState(false)
  const mutation = useOrderMutation(orderId, (params: { customer_note: string }) =>
    adminClient.orders.update(orderId, params),
  )

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const fd = new FormData(e.currentTarget)
    mutation.mutate(
      { customer_note: fd.get('customer_note') as string },
      { onSuccess: () => setEditing(false) },
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.orders.detail.section_customer_note')}</CardTitle>
        <CardAction>
          <Button variant="ghost" size="icon-xs" onClick={() => setEditing(!editing)}>
            <PencilIcon className="size-4" />
          </Button>
        </CardAction>
      </CardHeader>
      <CardContent>
        {editing ? (
          <form onSubmit={handleSubmit} className="flex flex-col gap-3">
            <Textarea name="customer_note" defaultValue={order.customer_note ?? ''} />
            <div className="flex justify-end gap-2">
              <Button type="button" variant="outline" size="sm" onClick={() => setEditing(false)}>
                {t('admin.actions.cancel')}
              </Button>
              <Button type="submit" size="sm" disabled={mutation.isPending}>
                {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
              </Button>
            </div>
          </form>
        ) : order.customer_note ? (
          <p className="text-sm text-muted-foreground whitespace-pre-wrap">{order.customer_note}</p>
        ) : (
          <p className="text-sm text-muted-foreground">{t('admin.common.none')}</p>
        )}
      </CardContent>
    </Card>
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
            size="icon-xs"
            onClick={() => {
              setTags(order.tags ?? [])
              setEditing(!editing)
            }}
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

  // Track the server value only while the editor is closed. Any order mutation
  // refetches this record, and adopting the incoming value mid-edit would throw
  // away whatever the user is part-way through typing.
  useEffect(() => {
    if (!editing) setNote(serverNote)
  }, [editing, serverNote])

  const mutation = useOrderMutation(orderId, (params: { internal_note: string }) =>
    adminClient.orders.update(orderId, params),
  )

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    mutation.mutate({ internal_note: note }, { onSuccess: () => setEditing(false) })
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.orders.detail.section_internal_note')}</CardTitle>
        <CardAction>
          <Button variant="ghost" size="icon-xs" onClick={() => setEditing(!editing)}>
            <PencilIcon className="size-4" />
          </Button>
        </CardAction>
      </CardHeader>
      <CardContent>
        {editing ? (
          <form onSubmit={handleSubmit} className="flex flex-col gap-3">
            <RichTextEditor
              ariaLabel={t('admin.orders.detail.section_internal_note')}
              value={note}
              onChange={setNote}
            />
            <div className="flex justify-end gap-2">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => {
                  setNote(serverNote)
                  setEditing(false)
                }}
              >
                {t('admin.actions.cancel')}
              </Button>
              <Button type="submit" size="sm" disabled={mutation.isPending}>
                {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
              </Button>
            </div>
          </form>
        ) : order.internal_note_html ? (
          <div
            className="prose prose-sm max-w-none text-muted-foreground dark:prose-invert"
            // biome-ignore lint/security/noDangerouslySetInnerHtml: HTML is sanitized server-side via the rich-text pipeline
            dangerouslySetInnerHTML={{ __html: order.internal_note_html }}
          />
        ) : (
          <p className="text-sm text-muted-foreground">{t('admin.common.none')}</p>
        )}
      </CardContent>
    </Card>
  )
}

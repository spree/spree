import type { Customer } from '@spree/admin-sdk'
import {
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  RichTextEditor,
} from '@spree/dashboard-ui'
import { PencilIcon } from 'lucide-react'
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useUpdateCustomer } from '../../../hooks/use-customers'

export function CustomerInternalNoteCard({ customer }: { customer: Customer }) {
  const { t } = useTranslation()
  const [editing, setEditing] = useState(false)
  const [note, setNote] = useState(customer.internal_note_html ?? '')
  const serverNote = customer.internal_note_html ?? ''

  // Track the server value only while the editor is closed, so a refetch from
  // an unrelated mutation can't discard a note the user is part-way through.
  useEffect(() => {
    if (!editing) setNote(serverNote)
  }, [editing, serverNote])

  const mutation = useUpdateCustomer(customer.id)

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.customers.detail.section_internal_note')}</CardTitle>
        {!editing && (
          <CardAction>
            <Button
              variant="ghost"
              size="icon-sm"
              onClick={() => setEditing(true)}
              aria-label={t('admin.actions.edit')}
            >
              <PencilIcon className="size-4" />
            </Button>
          </CardAction>
        )}
      </CardHeader>
      <CardContent>
        {editing ? (
          <div className="flex flex-col gap-3">
            <RichTextEditor
              ariaLabel={t('admin.pages.customers.detail.section_internal_note')}
              value={note}
              onChange={setNote}
              placeholder={t('admin.fields.customer.internal_note.placeholder')}
            />
            <div className="flex gap-2 justify-end">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => {
                  setEditing(false)
                  setNote(serverNote)
                }}
              >
                {t('admin.actions.cancel')}
              </Button>
              <Button
                type="button"
                size="sm"
                disabled={mutation.isPending}
                onClick={() =>
                  mutation.mutate({ internal_note: note }, { onSuccess: () => setEditing(false) })
                }
              >
                {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
              </Button>
            </div>
          </div>
        ) : customer.internal_note_html ? (
          <div
            className="text-sm prose-sm"
            // biome-ignore lint/security/noDangerouslySetInnerHtml: HTML is sanitized server-side via the rich-text pipeline
            dangerouslySetInnerHTML={{ __html: customer.internal_note_html }}
          />
        ) : (
          <p className="text-sm text-muted-foreground">
            {t('admin.customers.detail.no_internal_notes')}
          </p>
        )}
      </CardContent>
    </Card>
  )
}

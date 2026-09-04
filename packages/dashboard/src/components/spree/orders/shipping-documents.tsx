import { CardContent } from '@spree/dashboard-ui'
import { FileTextIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

/**
 * Paperwork the carrier produced beside the label. Customs forms are the
 * common case — a commercial invoice, a declaration, for anything crossing a
 * border — but what a provider files here is its own to decide.
 *
 * Owner-agnostic like the label row beside it: an export and a cross-border
 * return are declared the same way. The files are hosted by the carrier
 * rather than stored here, so these open in a new tab and a link can stop
 * working once the carrier expires it.
 */
export function ShippingDocuments({
  documents,
}: {
  documents?: Array<{ kind: string; url: string }>
}) {
  const { t } = useTranslation()

  if (!documents?.length) return null

  return (
    <CardContent className="flex flex-col gap-1.5 border-b border-border-subtle pt-3">
      <p className="text-sm font-medium">{t('admin.orders.detail.fulfillments.documents_title')}</p>
      {documents.map((document) => (
        <a
          key={document.url}
          href={document.url}
          target="_blank"
          rel="noreferrer"
          className="flex items-center gap-2 text-sm text-primary hover:underline"
        >
          <FileTextIcon className="size-4 shrink-0" />
          {t(`admin.orders.detail.fulfillments.document_kinds.${document.kind}`, {
            defaultValue: document.kind.replace(/_/g, ' '),
          })}
        </a>
      ))}
    </CardContent>
  )
}

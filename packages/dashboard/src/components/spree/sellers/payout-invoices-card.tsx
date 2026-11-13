import type { SellerPayout } from '@spree/admin-sdk'
import {
  downloadFromApi,
  getApiClient,
  InvoiceUploadSheet,
  Money,
  useAuth,
} from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Item,
  ItemContent,
  ItemDescription,
  ItemGroup,
  ItemTitle,
  StatusBadge,
} from '@spree/dashboard-ui'
import { UploadIcon } from '@spree/dashboard-ui/icons'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useCreatePayoutInvoice, usePayoutInvoices } from '../../../hooks/use-invoices'

/**
 * The marketplace's commission invoices to the seller for this payout,
 * uploaded from the operator's accounting system. The seller sees them in
 * their panel.
 */
export function PayoutInvoicesCard({
  payout,
  canEdit,
}: {
  payout: SellerPayout
  canEdit: boolean
}) {
  const { t } = useTranslation()
  const { token } = useAuth()
  const [uploading, setUploading] = useState(false)
  const { data, isLoading } = usePayoutInvoices(payout.id)
  const create = useCreatePayoutInvoice(payout.id)
  const invoices = data?.data ?? []

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          {t('admin.payouts.invoices.title')}
          {invoices.length > 0 && <Badge variant="outline">{invoices.length}</Badge>}
        </CardTitle>
        {canEdit && (
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setUploading(true)}>
              <UploadIcon className="size-4" />
              {t('admin.order_documents.upload_invoice')}
            </Button>
          </CardAction>
        )}
      </CardHeader>
      <CardContent>
        {isLoading ? (
          <p className="text-muted-foreground text-sm">{t('admin.common.loading')}</p>
        ) : invoices.length === 0 ? (
          <p className="text-muted-foreground text-sm">{t('admin.payouts.invoices.empty')}</p>
        ) : (
          <ItemGroup className="gap-2">
            {invoices.map((invoice) => (
              <Item key={invoice.id} role="listitem" variant="outline" size="sm">
                <ItemContent>
                  <ItemTitle>
                    <Button
                      type="button"
                      variant="link"
                      className="h-auto p-0"
                      onClick={() =>
                        invoice.download_url &&
                        downloadFromApi(
                          token,
                          invoice.download_url,
                          invoice.file_filename ?? invoice.number,
                          getApiClient().downloadHeaders?.() ?? {},
                        )
                      }
                    >
                      {invoice.number}
                    </Button>
                    <StatusBadge
                      status={invoice.kind}
                      tone={invoice.kind === 'credit_note' ? 'warning' : 'neutral'}
                      label={t(`admin.order_documents.kinds.${invoice.kind}`)}
                    />
                  </ItemTitle>
                  <ItemDescription className="text-xs">
                    {invoice.issued_on}
                    {' · '}
                    <Money amount={invoice.total} currency={invoice.currency} />
                  </ItemDescription>
                </ItemContent>
              </Item>
            ))}
          </ItemGroup>
        )}
      </CardContent>

      {uploading && (
        <InvoiceUploadSheet
          currency={payout.currency}
          invoices={invoices}
          onCreate={create.mutateAsync}
          onOpenChange={setUploading}
        />
      )}
    </Card>
  )
}

import { adminClient, useResourceKey } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Input,
  Pagination,
  StatusBadge,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  toastManager,
  useConfirm,
} from '@spree/dashboard-ui'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * The sellers listing against this product, and the operator's decision on
 * each (docs/plans/6.0-seller-master-catalog-listings.md, Decision 12).
 *
 * Not a page of its own: an offer is a row on a product, and what an operator
 * acts on is always the product in front of them. Finding the queue is the
 * products table's "offers awaiting review" filter.
 *
 * Renders nothing on a product that carries no seller offers, so an operator
 * whose catalog is entirely their own never meets it.
 */
export function ProductOffersCard({ productId }: { productId: string }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const queryClient = useQueryClient()
  const [rejectingId, setRejectingId] = useState<string | null>(null)
  const [reason, setReason] = useState('')
  const [page, setPage] = useState(1)

  // Paged, never capped: a popular master product carries the marketplace's
  // own rows plus every seller's offer in one collection, and an offer past a
  // cap could never be approved because nobody could see it.
  // Filtered server-side, not in the browser: paging a mixed collection and
  // then dropping the marketplace's own rows would page past offers the
  // operator never sees, and would count them in the pagination totals.
  const queryKey = useResourceKey('product-offers', `${productId}-${page}`)
  const { data } = useQuery({
    queryKey,
    queryFn: () =>
      adminClient.products.variants.list(productId, { expand: ['seller'], page, offers: true }),
  })

  // A reason typed for one offer must not follow the operator to the next.
  const openRejectFor = (variantId: string | null) => {
    setRejectingId(variantId)
    setReason('')
  }

  const decide = useMutation({
    mutationFn: ({
      variantId,
      action,
      note,
    }: {
      variantId: string
      action: 'approve' | 'reject'
      note?: string
    }) =>
      action === 'approve'
        ? adminClient.products.variants.approve(productId, variantId)
        : adminClient.products.variants.reject(productId, variantId, { reason: note }),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey })
      toastManager.add({ type: 'success', title: t('admin.products.offers.decided') })
      openRejectFor(null)
    },
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('admin.errors.generic'),
      }),
  })

  const offers = data?.data ?? []
  // Nothing to review on a product the marketplace sells alone, so the card
  // stays out of the way entirely.
  if (offers.length === 0) return null

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.products.offers.title')}</CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>{t('admin.products.offers.columns.seller')}</TableHead>
              <TableHead>{t('admin.products.offers.columns.options')}</TableHead>
              <TableHead>{t('admin.products.offers.columns.price')}</TableHead>
              <TableHead>{t('admin.products.offers.columns.status')}</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {offers.map((offer) => (
              <TableRow key={offer.id}>
                <TableCell>{offer.seller?.name ?? '—'}</TableCell>
                <TableCell>{offer.options_text || '—'}</TableCell>
                <TableCell>{offer.price?.display_amount ?? '—'}</TableCell>
                <TableCell>
                  <StatusBadge
                    status={offer.status}
                    label={t(`admin.products.offers.statuses.${offer.status}`)}
                  />
                </TableCell>
                <TableCell className="text-right">
                  {rejectingId === offer.id ? (
                    <div className="flex items-center justify-end gap-2">
                      <Input
                        value={reason}
                        onChange={(e) => setReason(e.target.value)}
                        placeholder={t('admin.products.offers.reason_placeholder')}
                        className="max-w-56"
                      />
                      <Button
                        variant="destructive"
                        size="sm"
                        disabled={decide.isPending}
                        onClick={() =>
                          decide.mutate({
                            variantId: offer.id,
                            action: 'reject',
                            note: reason.trim() || undefined,
                          })
                        }
                      >
                        {t('admin.products.offers.reject')}
                      </Button>
                      <Button variant="ghost" size="sm" onClick={() => openRejectFor(null)}>
                        {t('admin.common.cancel')}
                      </Button>
                    </div>
                  ) : (
                    // Approving is offered only for an offer actually
                    // awaiting review; rejecting also for one already sent
                    // back, so an operator can correct the reason they gave.
                    <div className="flex items-center justify-end gap-2">
                      {offer.status === 'proposed' && (
                        <Button
                          size="sm"
                          disabled={decide.isPending}
                          onClick={async () => {
                            const confirmed = await confirm({
                              title: t('admin.products.offers.approve_confirm_title'),
                              message: t('admin.products.offers.approve_confirm_message'),
                              confirmLabel: t('admin.products.offers.approve'),
                            })
                            if (confirmed) {
                              decide.mutate({ variantId: offer.id, action: 'approve' })
                            }
                          }}
                        >
                          {t('admin.products.offers.approve')}
                        </Button>
                      )}
                      {(offer.status === 'proposed' || offer.status === 'rejected') && (
                        <Button
                          variant="outline"
                          size="sm"
                          disabled={decide.isPending}
                          onClick={() => openRejectFor(offer.id)}
                        >
                          {t('admin.products.offers.reject')}
                        </Button>
                      )}
                    </div>
                  )}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
        {data?.meta && (
          <div className="p-4">
            <Pagination meta={data.meta} onPageChange={setPage} />
          </div>
        )}
      </CardContent>
    </Card>
  )
}

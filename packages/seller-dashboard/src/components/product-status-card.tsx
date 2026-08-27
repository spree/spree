import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  StatusBadge,
  toastManager,
  useConfirm,
} from '@spree/dashboard-ui'
import type { Product } from '@spree/seller-sdk'
import { useMutation } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'

/**
 * Where a product stands with the marketplace, and the one move available
 * from here.
 *
 * Not a status dropdown: a seller cannot choose to be on sale. They submit
 * and the operator decides, so each status offers only what it can actually
 * do next (docs/plans/6.0-seller-product-submission.md).
 */
export function ProductStatusCard({ product, onDone }: { product: Product; onDone: () => void }) {
  const { t } = useTranslation()
  const confirm = useConfirm()

  const move = useMutation({
    mutationFn: (action: 'submit' | 'draft' | 'archive') =>
      sellerClient().products[action](product.id),
    onSuccess: () => {
      toastManager.add({ type: 'success', title: t('products.status_updated') })
      onDone()
    },
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
  })

  const status = product.status
  const canSubmit = status === 'draft' || status === 'rejected'
  const canTakeDown = status === 'active' || status === 'proposed'

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('products.fields.status')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col items-start gap-3">
        <StatusBadge status={status} label={t(`products.statuses.${status}`)} />

        <p className="text-muted-foreground text-sm">{t(`products.status_help.${status}`)}</p>

        {/* Why the marketplace turned it down, so the seller knows what to
            fix. It lives on the submission rather than the product: a note
            the seller could overwrite by saving their own product was no
            record of anything. */}
        {status === 'rejected' && product.submission?.review_note && (
          <p className="text-sm">
            {t('products.rejection_reason', { reason: product.submission.review_note })}
          </p>
        )}

        <div className="flex flex-wrap gap-2">
          {canSubmit && (
            <Button disabled={move.isPending} onClick={() => move.mutate('submit')}>
              {t('products.submit_for_review')}
            </Button>
          )}

          {canTakeDown && (
            <Button
              variant="outline"
              disabled={move.isPending}
              onClick={async () => {
                const confirmed = await confirm({
                  title: t('products.take_down_confirm_title'),
                  message: t('products.take_down_confirm_description'),
                  confirmLabel: t('products.take_down'),
                })
                if (confirmed) move.mutate('draft')
              }}
            >
              {t('products.take_down')}
            </Button>
          )}

          {status !== 'archived' && (
            <Button
              variant="outline"
              disabled={move.isPending}
              onClick={async () => {
                const confirmed = await confirm({
                  title: t('products.archive_confirm_title'),
                  message: t('products.archive_confirm_description'),
                  confirmLabel: t('products.archive'),
                  variant: 'destructive',
                })
                if (confirmed) move.mutate('archive')
              }}
            >
              {t('products.archive')}
            </Button>
          )}
        </div>
      </CardContent>
    </Card>
  )
}

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
import type { Variant } from '@spree/seller-sdk'
import { useMutation } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'

/**
 * Where an offer stands with the marketplace, and the one move available
 * from here.
 *
 * The same shape as a product's status card, and for the same reason: a
 * seller cannot choose to be on sale. They submit and the operator decides,
 * so each status offers only what it can actually do next
 * (docs/plans/6.0-seller-master-catalog-listings.md).
 */
export function OfferStatusCard({ offer, onDone }: { offer: Variant; onDone: () => void }) {
  const { t } = useTranslation()
  const confirm = useConfirm()

  const move = useMutation({
    mutationFn: (action: 'submit' | 'draft' | 'archive') =>
      sellerClient().variants[action](offer.id),
    onSuccess: () => {
      toastManager.add({ type: 'success', title: t('offers.status_updated') })
      onDone()
    },
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
  })

  const status = offer.status
  const canSubmit = status === 'draft' || status === 'rejected'
  const canTakeDown = status === 'active' || status === 'proposed'

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('offers.fields.status')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col items-start gap-3">
        <StatusBadge status={status} label={t(`offers.statuses.${status}`)} />

        <p className="text-muted-foreground text-sm">{t(`offers.status_help.${status}`)}</p>

        {/* Why the marketplace turned it down, so the seller knows what to
            fix. It lives on the submission rather than on the offer, which
            the seller can write. */}
        {status === 'rejected' && offer.submission?.review_note && (
          <p className="text-sm">
            {t('offers.rejection_reason', { reason: offer.submission.review_note })}
          </p>
        )}

        <div className="flex flex-wrap gap-2">
          {canSubmit && (
            <Button disabled={move.isPending} onClick={() => move.mutate('submit')}>
              {t('offers.submit_for_review')}
            </Button>
          )}

          {canTakeDown && (
            <Button
              variant="outline"
              disabled={move.isPending}
              onClick={async () => {
                const confirmed = await confirm({
                  title: t('offers.take_down_confirm_title'),
                  message: t('offers.take_down_confirm_description'),
                  confirmLabel: t('offers.take_down'),
                })
                if (confirmed) move.mutate('draft')
              }}
            >
              {t('offers.take_down')}
            </Button>
          )}

          {status !== 'archived' && (
            <Button
              variant="outline"
              disabled={move.isPending}
              onClick={async () => {
                const confirmed = await confirm({
                  title: t('offers.archive_confirm_title'),
                  message: t('offers.archive_confirm_description'),
                  confirmLabel: t('offers.archive'),
                  variant: 'destructive',
                })
                if (confirmed) move.mutate('archive')
              }}
            >
              {t('offers.archive')}
            </Button>
          )}
        </div>
      </CardContent>
    </Card>
  )
}

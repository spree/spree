import { Button, Input, toastManager, useConfirm } from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useApproveProduct, useRejectProduct } from '../../../hooks/use-product'

/**
 * The operator's decision on a product a seller submitted.
 *
 * Lives here rather than in the shared card because approving is a mutation
 * against the Admin API — the framework's status card knows a product is in
 * review, but not who is allowed to end it.
 *
 * Approving is offered only for a product actually awaiting review.
 * Rejecting is offered for that and for one already rejected, so an operator
 * can correct the reason they gave.
 *
 * Neither decision saves the product form, so both wait until unsaved edits
 * (a category picked during review) are saved rather than dropping them.
 */
export function ProductReviewActions({
  productId,
  status,
  hasUnsavedChanges = false,
}: {
  productId: string
  status: string
  hasUnsavedChanges?: boolean
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const approve = useApproveProduct()
  const reject = useRejectProduct()
  const [reason, setReason] = useState('')
  const [rejecting, setRejecting] = useState(false)

  const awaitingReview = status === 'proposed'

  function blockedByUnsavedChanges() {
    if (!hasUnsavedChanges) return false
    toastManager.add({ type: 'warning', title: t('admin.products.review.save_first') })
    return true
  }

  async function handleApprove() {
    if (blockedByUnsavedChanges()) return

    const confirmed = await confirm({
      title: t('admin.products.review.approve_confirm_title'),
      message: t('admin.products.review.approve_confirm_message'),
      confirmLabel: t('admin.products.review.approve'),
    })
    if (!confirmed) return

    try {
      await approve.mutateAsync(productId)
      toastManager.add({ type: 'success', title: t('admin.products.review.approved') })
    } catch (err) {
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('admin.errors.generic'),
      })
    }
  }

  async function handleReject() {
    if (blockedByUnsavedChanges()) return

    try {
      await reject.mutateAsync({ id: productId, reason: reason.trim() || undefined })
      toastManager.add({ type: 'success', title: t('admin.products.review.rejected') })
      setRejecting(false)
      setReason('')
    } catch (err) {
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('admin.errors.generic'),
      })
    }
  }

  if (rejecting) {
    return (
      <div className="flex w-full flex-col gap-2">
        <Input
          value={reason}
          autoFocus
          placeholder={t('admin.products.review.reason_placeholder')}
          aria-label={t('admin.products.review.reason_label')}
          onChange={(event) => setReason(event.target.value)}
        />
        <div className="flex gap-2">
          <Button type="button" size="sm" disabled={reject.isPending} onClick={handleReject}>
            {t('admin.products.review.send_back')}
          </Button>
          <Button type="button" size="sm" variant="outline" onClick={() => setRejecting(false)}>
            {t('admin.actions.cancel')}
          </Button>
        </div>
      </div>
    )
  }

  return (
    <>
      {awaitingReview && (
        <Button type="button" size="sm" disabled={approve.isPending} onClick={handleApprove}>
          {t('admin.products.review.approve')}
        </Button>
      )}
      <Button type="button" size="sm" variant="outline" onClick={() => setRejecting(true)}>
        {awaitingReview
          ? t('admin.products.review.reject')
          : t('admin.products.review.edit_reason')}
      </Button>
    </>
  )
}

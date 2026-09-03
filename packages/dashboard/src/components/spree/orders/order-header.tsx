import type { Order } from '@spree/admin-sdk'
import { adminClient, PageHeader, useResourceMutation, useStore } from '@spree/dashboard-core'
import {
  Button,
  DropdownMenuItem,
  RelativeTime,
  StatusBadge,
  useConfirm,
} from '@spree/dashboard-ui'
import {
  CheckCircleIcon,
  ExternalLinkIcon,
  MailIcon,
  PencilIcon,
  ShieldCheckIcon,
  XCircleIcon,
} from '@spree/dashboard-ui/icons'
import { Link } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { orderQueryKey } from '../../../hooks/use-order'
import { GONE_STATUSES } from '../../../lib/fulfillment-items'
import { spreeJsonLinkResolver } from '../../../lib/json-link-resolver'
import { OrderCancelDialog } from './order-cancel-dialog'

export function OrderHeader({ order }: { order: Order }) {
  const { t } = useTranslation()
  const orderId = order.id
  const { storeId } = useStore()
  const confirm = useConfirm()
  const [cancelOpen, setCancelOpen] = useState(false)

  const backFallback = order.completed_at ? 'orders' : 'orders/drafts'

  const completeMutation = useResourceMutation({
    mutationFn: () => adminClient.orders.complete(orderId),
    invalidate: [orderQueryKey(orderId)],
    successMessage: t('admin.orders.detail.messages.completed'),
    errorMessage: t('admin.orders.detail.errors.complete_failed'),
  })
  const approveMutation = useResourceMutation({
    mutationFn: () => adminClient.orders.approve(orderId),
    invalidate: [orderQueryKey(orderId)],
    successMessage: t('admin.orders.detail.messages.approved'),
    errorMessage: t('admin.orders.detail.errors.approve_failed'),
  })
  const resendMutation = useResourceMutation({
    mutationFn: () => adminClient.orders.resendConfirmation(orderId, {}),
    successMessage: t('admin.orders.detail.messages.confirmation_sent'),
    errorMessage: t('admin.orders.detail.errors.confirmation_send_failed'),
  })

  const badges = (
    <>
      {order.payment_status && <StatusBadge status={order.payment_status} />}
      {order.fulfillment_status && <StatusBadge status={order.fulfillment_status} />}
    </>
  )

  const subtitle = order.completed_at ? (
    <RelativeTime iso={order.completed_at} prefix={t('admin.orders.detail.completed_prefix')} />
  ) : undefined

  const dropdownItems = (
    <>
      {order.considered_risky && !order.approved_at && (
        <DropdownMenuItem
          onClick={async () => {
            if (
              await confirm({
                title: t('admin.pages.orders.detail.dialogs.approve_title'),
                message: t('admin.orders.detail.confirm.approve_message'),
                confirmLabel: t('admin.pages.orders.detail.actions.approve'),
              })
            ) {
              approveMutation.mutate(undefined)
            }
          }}
          disabled={approveMutation.isPending}
        >
          <ShieldCheckIcon className="size-4" />
          {t('admin.pages.orders.detail.actions.approve')}
        </DropdownMenuItem>
      )}
      {order.completed_at && (
        <>
          <DropdownMenuItem>
            <ExternalLinkIcon className="size-4" />
            {t('admin.orders.detail.dropdown.preview_order')}
          </DropdownMenuItem>
          <DropdownMenuItem
            onClick={() => resendMutation.mutate(undefined)}
            disabled={resendMutation.isPending}
          >
            <MailIcon className="size-4" />
            {t('admin.orders.detail.dropdown.resend_confirmation')}
          </DropdownMenuItem>
        </>
      )}
    </>
  )

  const destructiveItems = (
    <>
      {order.status !== 'canceled' && (
        <DropdownMenuItem variant="destructive" onClick={() => setCancelOpen(true)}>
          <XCircleIcon className="size-4" />
          {t('admin.pages.orders.detail.actions.cancel')}
        </DropdownMenuItem>
      )}
    </>
  )

  return (
    <>
      {cancelOpen && <OrderCancelDialog orderId={orderId} onClose={() => setCancelOpen(false)} />}
      <PageHeader
        title={order.number}
        subtitle={subtitle}
        backTo={backFallback}
        badges={badges}
        actions={
          <>
            {/* Fully fulfilled means every unit has shipped, so there is
              nothing left an edit could lawfully change. */}
            {!GONE_STATUSES.includes(order.fulfillment_status ?? '') && (
              <Button variant="outline" asChild>
                <Link to="/$storeId/orders/$orderId/edit" params={{ storeId, orderId }}>
                  <PencilIcon className="size-4" />
                  {t('admin.orders.edit.action_label')}
                </Link>
              </Button>
            )}

            {order.status === 'draft' && (
              <Button
                onClick={async () => {
                  if (
                    await confirm({
                      message: t('admin.orders.detail.confirm.complete_message'),
                      confirmLabel: t('admin.orders.detail.dropdown.complete_order'),
                    })
                  ) {
                    completeMutation.mutate(undefined)
                  }
                }}
                disabled={completeMutation.isPending}
              >
                <CheckCircleIcon />
                {t('admin.orders.detail.dropdown.complete_order')}
              </Button>
            )}
          </>
        }
        dropdownItems={dropdownItems}
        destructiveItems={destructiveItems}
        resource={{ id: order.id, number: order.number }}
        jsonPreview={{
          title: `Order ${order.number}`,
          fetch: () => adminClient.orders.get(orderId),
          endpoint: `/api/v3/admin/orders/${orderId}`,
          resolveLink: spreeJsonLinkResolver(storeId),
        }}
      />
    </>
  )
}

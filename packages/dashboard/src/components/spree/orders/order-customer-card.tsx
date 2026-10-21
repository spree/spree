import type { Order } from '@spree/admin-sdk'
import { AddressFormDialog, type AddressParams, adminClient, useStore } from '@spree/dashboard-core'
import {
  AddressBlock,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  toastManager,
} from '@spree/dashboard-ui'
import { CopyIcon, PencilIcon } from '@spree/dashboard-ui/icons'
import { Link } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useOrderMutation } from '../../../hooks/use-order'
import { customerDisplayName, erasedFieldValue } from '../../../lib/erased-customer'
import { OrderCustomerDialog } from './order-customer-dialog'

type AddressType = 'shipping_address' | 'billing_address'

/**
 * Who the order is for and where it is going. The only place a placed order's
 * addresses can be changed, so each save writes straight through rather than
 * waiting for a page-level submit.
 */
export function CustomerCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { storeId } = useStore()
  const orderId = order.id
  const customer = order.customer
  const shippingAddress = order.shipping_address
  const billingSameAsShipping = !!shippingAddress && order.shipping_eq_billing_address
  const [editAddress, setEditAddress] = useState<AddressType | null>(null)
  const [editCustomer, setEditCustomer] = useState(false)

  const showError = (error: unknown) =>
    toastManager.add({
      type: 'error',
      title:
        error instanceof Error ? error.message : t('admin.orders.errors.failed_to_update_address'),
    })

  const addressMutation = useOrderMutation(
    orderId,
    (params: { type: AddressType; address: AddressParams }) =>
      adminClient.orders.update(orderId, { [params.type]: params.address }),
  )
  const sameAsShippingMutation = useOrderMutation(orderId, () =>
    adminClient.orders.update(orderId, { use_shipping: true }),
  )

  const editButton = (type: AddressType) => (
    <CardAction>
      <Button
        variant="ghost"
        size="icon-sm"
        onClick={() => setEditAddress(type)}
        aria-label={
          type === 'shipping_address'
            ? t('admin.orders.detail.address_edit.shipping_title')
            : t('admin.orders.detail.address_edit.billing_title')
        }
      >
        <PencilIcon className="size-4" />
      </Button>
    </CardAction>
  )

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>{t('admin.pages.orders.detail.section_customer')}</CardTitle>
          <CardAction>
            <Button
              variant="ghost"
              size="icon-sm"
              onClick={() => setEditCustomer(true)}
              aria-label={t('admin.orders.detail.customer_edit.title')}
            >
              <PencilIcon className="size-4" />
            </Button>
          </CardAction>
        </CardHeader>
        <CardContent className="flex flex-col gap-1 text-sm">
          {customer ? (
            <>
              <Link
                to={'/$storeId/customers/$customerId' as string}
                params={{ storeId, customerId: customer.id }}
                className="font-medium text-blue-600 no-underline hover:underline"
              >
                {customerDisplayName(customer, t('admin.customers.erased.name'))}
              </Link>
              <span className="text-muted-foreground">
                {erasedFieldValue(customer.email, customer.anonymized)}
              </span>
            </>
          ) : order.email ? (
            <span className="text-blue-600">{order.email}</span>
          ) : (
            <span className="text-muted-foreground">{t('admin.orders.detail.no_customer')}</span>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>{t('admin.pages.orders.detail.section_shipping_address')}</CardTitle>
          {editButton('shipping_address')}
        </CardHeader>
        <CardContent>
          <AddressBlock address={shippingAddress} />
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>{t('admin.pages.orders.detail.section_billing_address')}</CardTitle>
          {editButton('billing_address')}
        </CardHeader>
        <CardContent className="flex flex-col gap-3">
          <AddressBlock
            address={billingSameAsShipping ? null : order.billing_address}
            emptyText={
              billingSameAsShipping
                ? t('admin.orders.detail.address_edit.billing_same_as_shipping')
                : undefined
            }
          />
          {shippingAddress && !billingSameAsShipping && (
            <Button
              variant="outline"
              size="sm"
              className="self-start"
              disabled={sameAsShippingMutation.isPending}
              onClick={() => sameAsShippingMutation.mutate(undefined, { onError: showError })}
            >
              <CopyIcon className="size-4" />
              {t('admin.orders.detail.address_edit.billing_same_as_shipping')}
            </Button>
          )}
        </CardContent>
      </Card>

      {editCustomer && (
        <OrderCustomerDialog order={order} open={editCustomer} onOpenChange={setEditCustomer} />
      )}

      {editAddress && (
        <AddressFormDialog
          title={
            editAddress === 'shipping_address'
              ? t('admin.orders.detail.address_edit.shipping_title')
              : t('admin.orders.detail.address_edit.billing_title')
          }
          address={editAddress === 'shipping_address' ? shippingAddress : order.billing_address}
          open={!!editAddress}
          onOpenChange={(open) => !open && setEditAddress(null)}
          onSave={(address) =>
            addressMutation.mutate(
              { type: editAddress, address },
              {
                onSuccess: () => setEditAddress(null),
                // The dialog stays open on failure so the entered address is
                // not lost and can be corrected and resubmitted.
                onError: showError,
              },
            )
          }
          isPending={addressMutation.isPending}
        />
      )}
    </>
  )
}

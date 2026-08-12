import type { Order } from '@spree/admin-sdk'
import {
  AddressFormDialog,
  type AddressParams,
  adminClient,
  getInitials,
} from '@spree/dashboard-core'
import {
  AddressBlock,
  Avatar,
  AvatarFallback,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@spree/dashboard-ui'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { EllipsisVerticalIcon, PencilIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

export function CustomerCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const orderId = order.id
  const queryClient = useQueryClient()
  const customer = order.customer
  const [editAddress, setEditAddress] = useState<'shipping_address' | 'billing_address' | null>(
    null,
  )

  const addressMutation = useMutation({
    mutationFn: (params: {
      type: 'shipping_address' | 'billing_address'
      address: AddressParams
    }) => adminClient.orders.update(orderId, { [params.type]: params.address } as any),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['order', orderId] })
      setEditAddress(null)
    },
  })

  const editTitle =
    editAddress === 'shipping_address'
      ? t('admin.orders.detail.address_edit.shipping_title')
      : t('admin.orders.detail.address_edit.billing_title')

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>{t('admin.pages.orders.detail.section_customer')}</CardTitle>
          <CardAction>
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="icon-xs">
                  <EllipsisVerticalIcon className="size-4" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem onClick={() => setEditAddress('shipping_address')}>
                  <PencilIcon className="size-4" />
                  {t('admin.orders.detail.address_edit.shipping_title')}
                </DropdownMenuItem>
                <DropdownMenuItem onClick={() => setEditAddress('billing_address')}>
                  <PencilIcon className="size-4" />
                  {t('admin.orders.detail.address_edit.billing_title')}
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </CardAction>
        </CardHeader>
        <CardContent className="flex flex-col gap-5">
          {/* Contact info */}
          {customer ? (
            <div className="flex items-center gap-3 rounded-xl bg-muted p-3">
              <Avatar>
                <AvatarFallback>{getInitials(customer.full_name, customer.email)}</AvatarFallback>
              </Avatar>
              <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-medium">{customer.full_name}</div>
                <div className="truncate text-xs text-muted-foreground">{customer.email}</div>
              </div>
            </div>
          ) : order.email ? (
            <div className="text-sm text-blue-600">{order.email}</div>
          ) : (
            <span className="text-sm text-muted-foreground">
              {t('admin.orders.detail.no_customer')}
            </span>
          )}

          <AddressBlock
            title={t('admin.pages.orders.detail.section_shipping_address')}
            address={order.shipping_address}
          />
          <AddressBlock
            title={t('admin.pages.orders.detail.section_billing_address')}
            address={order.billing_address}
          />
        </CardContent>
      </Card>

      {editAddress && (
        <AddressFormDialog
          title={editTitle}
          address={
            editAddress === 'shipping_address' ? order.shipping_address : order.billing_address
          }
          open={!!editAddress}
          onOpenChange={(open) => !open && setEditAddress(null)}
          onSave={(address) => addressMutation.mutate({ type: editAddress, address })}
          isPending={addressMutation.isPending}
        />
      )}
    </>
  )
}

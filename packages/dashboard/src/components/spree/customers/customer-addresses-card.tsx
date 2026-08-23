import type { Address, Customer } from '@spree/admin-sdk'
import { AddressFormDialog, type AddressParams, useCountries } from '@spree/dashboard-core'
import {
  Badge,
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
  useConfirm,
} from '@spree/dashboard-ui'
import { EllipsisVerticalIcon, PencilIcon, PlusIcon, TrashIcon } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  useCreateCustomerAddress,
  useDeleteCustomerAddress,
  useUpdateCustomerAddress,
} from '../../../hooks/use-customers'

export function CustomerAddressesCard({ customer }: { customer: Customer }) {
  const { t } = useTranslation()
  const [addOpen, setAddOpen] = useState(false)
  const [editing, setEditing] = useState<Address | null>(null)
  const confirm = useConfirm()
  const addresses = useMemo(() => {
    const isDefault = (a: Address) => a.is_default_billing || a.is_default_shipping
    return [...(customer.addresses ?? [])].sort(
      (a, b) => Number(isDefault(b)) - Number(isDefault(a)),
    )
  }, [customer.addresses])

  const deleteMutation = useDeleteCustomerAddress(customer.id)

  const updateMutation = useUpdateCustomerAddress(customer.id)
  function setDefault(params: { id: string; kind: 'billing' | 'shipping' }) {
    return updateMutation.mutate({
      id: params.id,
      params: {
        [params.kind === 'billing' ? 'is_default_billing' : 'is_default_shipping']: true,
      },
    })
  }

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            {t('admin.pages.customers.detail.section_addresses')}
            {addresses.length > 0 && <Badge variant="outline">{addresses.length}</Badge>}
          </CardTitle>
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
              <PlusIcon className="size-4" />
              {t('admin.pages.customers.detail.add_address')}
            </Button>
          </CardAction>
        </CardHeader>
        {addresses.length === 0 ? (
          <CardContent>
            <p className="text-sm text-muted-foreground">
              {t('admin.pages.customers.detail.addresses_empty')}
            </p>
          </CardContent>
        ) : (
          <CardContent className="flex flex-col gap-3">
            {addresses.map((addr) => (
              <div
                key={addr.id}
                className="flex items-start justify-between gap-2 rounded-md border p-3"
              >
                <div className="text-sm">
                  <div className="font-medium">
                    {addr.full_name ?? '—'}
                    <span className="ml-2 inline-flex gap-1">
                      {addr.is_default_billing && (
                        <Badge variant="outline">
                          {t('admin.customers.detail.address.default_billing')}
                        </Badge>
                      )}
                      {addr.is_default_shipping && (
                        <Badge variant="outline">
                          {t('admin.customers.detail.address.default_shipping')}
                        </Badge>
                      )}
                    </span>
                  </div>
                  <div className="text-muted-foreground">{addr.address1}</div>
                  {addr.address2 && <div className="text-muted-foreground">{addr.address2}</div>}
                  <div className="text-muted-foreground">
                    {[addr.city, addr.state_code, addr.postal_code].filter(Boolean).join(', ')} ·{' '}
                    {addr.country_code}
                  </div>
                  {addr.phone && <div className="text-muted-foreground">{addr.phone}</div>}
                </div>
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="icon-xs">
                      <EllipsisVerticalIcon className="size-4" />
                      <span className="sr-only">{t('admin.actions.actions_menu')}</span>
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem onClick={() => setEditing(addr)}>
                      <PencilIcon className="size-4" />
                      {t('admin.actions.edit')}
                    </DropdownMenuItem>
                    {!addr.is_default_billing && (
                      <DropdownMenuItem
                        onClick={() => setDefault({ id: addr.id, kind: 'billing' })}
                      >
                        {t('admin.customers.detail.address.set_default_billing')}
                      </DropdownMenuItem>
                    )}
                    {!addr.is_default_shipping && (
                      <DropdownMenuItem
                        onClick={() => setDefault({ id: addr.id, kind: 'shipping' })}
                      >
                        {t('admin.customers.detail.address.set_default_shipping')}
                      </DropdownMenuItem>
                    )}
                    <DropdownMenuItem
                      className="text-destructive focus:text-destructive"
                      onClick={async () => {
                        if (
                          await confirm({
                            message: t('admin.customers.detail.address.delete_confirm_message'),
                            variant: 'destructive',
                            confirmLabel: t('admin.actions.delete'),
                          })
                        ) {
                          deleteMutation.mutate(addr.id)
                        }
                      }}
                    >
                      <TrashIcon className="size-4" />
                      {t('admin.actions.delete')}
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>
            ))}
          </CardContent>
        )}
      </Card>

      {addOpen && (
        <CustomerAddressDialog
          customer={customer}
          address={newAddressTemplate(customer)}
          onOpenChange={setAddOpen}
          title={t('admin.pages.customers.detail.add_address')}
        />
      )}
      {editing && (
        <CustomerAddressDialog
          customer={customer}
          address={editing}
          onOpenChange={(o) => {
            if (!o) setEditing(null)
          }}
          title={t('admin.pages.customers.detail.edit_address')}
        />
      )}
    </>
  )
}

function newAddressTemplate(customer: Customer): Address {
  return {
    first_name: customer.first_name ?? '',
    last_name: customer.last_name ?? '',
    phone: customer.phone ?? '',
  } as Address
}

function CustomerAddressDialog({
  customer,
  address,
  onOpenChange,
  title,
}: {
  customer: Customer
  address: Address
  onOpenChange: (open: boolean) => void
  title: string
}) {
  const { isLoading: countriesLoading } = useCountries()
  const isEdit = Boolean(address.id)
  const createMutation = useCreateCustomerAddress(customer.id)
  const updateMutation = useUpdateCustomerAddress(customer.id)
  const mutation = isEdit ? updateMutation : createMutation

  // Returns the promise so `AddressFormDialog` can map 422 errors onto fields.
  // Closes the sheet only on success.
  async function handleSave(params: AddressParams) {
    if (isEdit) {
      await updateMutation.mutateAsync({ id: address.id, params })
    } else {
      await createMutation.mutateAsync(params)
    }
    onOpenChange(false)
  }

  // Wait for countries before mounting so the country/state lazy initializer
  // can resolve the address's country_code/state_code to a real option.
  if (countriesLoading) return null

  return (
    <AddressFormDialog
      address={address}
      open
      onOpenChange={onOpenChange}
      onSave={handleSave}
      title={title}
      isPending={mutation.isPending}
      showLabel
      showDefaultFlags
    />
  )
}

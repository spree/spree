import type { Address, Customer } from '@spree/admin-sdk'
import { AddressFormDialog, type AddressParams, useCountries } from '@spree/dashboard-core'
import {
  AddressBookTable,
  AddressBookTableRow,
  Badge,
  Button,
  Card,
  CardContent,
  Empty,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  Section,
  SectionActions,
  SectionHeader,
  SectionTitle,
  useConfirm,
} from '@spree/dashboard-ui'
import { MapPinIcon, PlusIcon } from '@spree/dashboard-ui/icons'
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
      <Section>
        <SectionHeader>
          <SectionTitle>
            <MapPinIcon />
            {t('admin.pages.customers.detail.section_addresses')}
            {addresses.length > 0 && <Badge variant="outline">{addresses.length}</Badge>}
          </SectionTitle>
          <SectionActions>
            <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
              <PlusIcon className="size-4" />
              {t('admin.pages.customers.detail.add_address')}
            </Button>
          </SectionActions>
        </SectionHeader>
        {addresses.length === 0 ? (
          <Card>
            <CardContent>
              <Empty className="p-4">
                <EmptyHeader>
                  <EmptyMedia variant="icon">
                    <MapPinIcon />
                  </EmptyMedia>
                  <EmptyTitle>{t('admin.pages.customers.detail.addresses_empty')}</EmptyTitle>
                </EmptyHeader>
              </Empty>
            </CardContent>
          </Card>
        ) : (
          <Card>
            <AddressBookTable>
              {addresses.map((addr) => (
                <AddressBookTableRow
                  key={addr.id}
                  address={addr}
                  onEdit={() => setEditing(addr)}
                  onSetDefaultBilling={() => setDefault({ id: addr.id, kind: 'billing' })}
                  onSetDefaultShipping={() => setDefault({ id: addr.id, kind: 'shipping' })}
                  onRemove={async () => {
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
                />
              ))}
            </AddressBookTable>
          </Card>
        )}
      </Section>

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

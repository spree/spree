import type { Address } from '@spree/admin-sdk'
import { AddressFormDialog } from '@spree/dashboard-core'
import { useTranslation } from 'react-i18next'
import { useCreateCompanyAddress, useUpdateCompanyAddress } from '../../hooks/use-companies'

/**
 * Creates an entry in a company node's address book, or edits one. The node
 * owns the address outright, and points at one entry per kind as its default.
 *
 * A thin wrapper over the shared dialog: a book entry is an ordinary address
 * addressed to the company, which is exactly what `business` mode asks for.
 */
export function CompanyAddressSheet({
  companyId,
  companyName,
  entry,
  open,
  onOpenChange,
}: {
  companyId: string
  companyName: string
  entry?: Address
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateCompanyAddress(companyId)
  const updateMutation = useUpdateCompanyAddress(companyId)

  // A new entry is offered as both defaults: the node points at one address per
  // kind, so the first site it gets is the answer to both, and there is no
  // previous default for it to displace. The company line comes from the node,
  // so a new entry is born carrying it.
  const address = entry ?? {
    company: companyName,
    is_default_billing: true,
    is_default_shipping: true,
  }

  return (
    <AddressFormDialog
      title={
        entry
          ? t('admin.company_addresses.edit_sheet_title')
          : t('admin.company_addresses.add_sheet_title')
      }
      description={t('admin.company_addresses.sheet_description')}
      address={address}
      open={open}
      onOpenChange={onOpenChange}
      // Addressed to the company, so no contact name is asked for and the
      // company line is what cannot be left out.
      business
      companyReadOnly
      showLabel
      showDefaultFlags
      onSave={async (values) => {
        // The dialog speaks the customer address book's names for these; the
        // company endpoints take them without the prefix.
        const { is_default_billing, is_default_shipping, ...address } = values
        const params = {
          ...address,
          default_billing: is_default_billing,
          default_shipping: is_default_shipping,
        }

        if (entry) {
          await updateMutation.mutateAsync({ id: entry.id, params })
        } else {
          await createMutation.mutateAsync(params)
        }
        onOpenChange(false)
      }}
      isPending={createMutation.isPending || updateMutation.isPending}
    />
  )
}

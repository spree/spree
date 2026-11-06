import type { Customer } from '@spree/admin-sdk'
import { ResourceCombobox } from '@spree/dashboard-core'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { customerAutocompleteProps } from '../../../hooks/use-customers'
import { CustomerComboboxOption } from '../customer-combobox-option'
import { NewCustomerSheet } from './new-customer-sheet'

/**
 * The admin's one picker for a single customer: search by name or email, each
 * row the name with the email under it, and "Add new customer" at the end,
 * which opens the new-customer sheet and picks the customer it creates.
 */
export function CustomerCombobox({
  queryKey,
  value,
  onChange,
  companyId,
  allowCreate = !companyId,
  id,
  disabled,
}: {
  /** Unique per picker, so two on one page keep separate caches. */
  queryKey: string
  value: string | null | undefined
  onChange: (id: string | null, customer: Customer | null) => void
  /** Narrows the search to people who may buy for this company. */
  companyId?: string | null
  /**
   * Off where a new customer makes no sense, such as a filter. Off by default
   * under a company: a new customer has no standing to buy for it, so picking
   * them would only fail the order's validation.
   */
  allowCreate?: boolean
  id?: string
  disabled?: boolean
}) {
  const { t } = useTranslation()
  const [creating, setCreating] = useState(false)

  return (
    <>
      <ResourceCombobox<Customer>
        {...customerAutocompleteProps(queryKey, companyId)}
        id={id}
        disabled={disabled}
        value={value || undefined}
        onChange={(nextId, record) => onChange(nextId ?? null, record ?? null)}
        renderOption={(customer) => <CustomerComboboxOption customer={customer} />}
        action={
          allowCreate
            ? {
                label: t('admin.customers.autocomplete.add_new'),
                onSelect: () => setCreating(true),
              }
            : undefined
        }
      />
      {creating && (
        <NewCustomerSheet
          open
          onOpenChange={setCreating}
          onCreated={(created) => {
            setCreating(false)
            onChange(created.id, created)
          }}
        />
      )}
    </>
  )
}

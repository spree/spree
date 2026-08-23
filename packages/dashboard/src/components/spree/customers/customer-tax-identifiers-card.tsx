import type { Customer } from '@spree/admin-sdk'
import { Subject, usePermissions } from '@spree/dashboard-core'
import {
  useCreateCustomerTaxIdentifier,
  useCustomerTaxIdentifiers,
  useDeleteCustomerTaxIdentifier,
  useUpdateCustomerTaxIdentifier,
  useValidateCustomerTaxIdentifier,
} from '../../../hooks/use-customers'
import { TaxIdentifiersCard } from '../tax-identifiers-card'

export function CustomerTaxIdentifiersCard({ customer }: { customer: Customer }) {
  const { permissions } = usePermissions()
  const { data, isLoading } = useCustomerTaxIdentifiers(customer.id)
  const createMutation = useCreateCustomerTaxIdentifier(customer.id)
  const updateMutation = useUpdateCustomerTaxIdentifier(customer.id)
  const deleteMutation = useDeleteCustomerTaxIdentifier(customer.id)
  const validateMutation = useValidateCustomerTaxIdentifier(customer.id)

  return (
    <TaxIdentifiersCard
      identifiers={data?.data ?? []}
      isLoading={isLoading}
      canEdit={permissions.can('update', Subject.Customer)}
      mutations={{
        create: (params) => createMutation.mutateAsync(params),
        update: (id, params) => updateMutation.mutateAsync({ id, params }),
        remove: (id) => deleteMutation.mutateAsync(id),
        validate: (id) => validateMutation.mutateAsync(id),
        isValidating: validateMutation.isPending,
      }}
    />
  )
}

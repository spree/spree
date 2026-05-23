import { adminClient } from '@/client'
import { customerQueryKey } from '@/hooks/use-customers'
import { useResourceMutation } from '@/hooks/use-resource-mutation'
import { i18n } from '@/lib/i18n'

type StoreCreditCreateParams = Parameters<typeof adminClient.customers.storeCredits.create>[1]
type StoreCreditUpdateParams = Parameters<typeof adminClient.customers.storeCredits.update>[2]

export type { StoreCreditUpdateParams }

export function useCreateCustomerStoreCredit(customerId: string) {
  return useResourceMutation({
    mutationFn: (params: StoreCreditCreateParams) =>
      adminClient.customers.storeCredits.create(customerId, params),
    invalidate: [customerQueryKey(customerId)],
    successMessage: i18n.t('admin.messages.store_credit_saved'),
  })
}

export function useUpdateCustomerStoreCredit(customerId: string, creditId: string) {
  return useResourceMutation({
    mutationFn: (params: StoreCreditUpdateParams) =>
      adminClient.customers.storeCredits.update(customerId, creditId, params),
    invalidate: [customerQueryKey(customerId)],
    successMessage: i18n.t('admin.messages.store_credit_saved'),
  })
}

export function useDeleteCustomerStoreCredit(customerId: string) {
  return useResourceMutation({
    mutationFn: (id: string) => adminClient.customers.storeCredits.delete(customerId, id),
    invalidate: [customerQueryKey(customerId)],
    successMessage: i18n.t('admin.messages.store_credit_removed'),
  })
}

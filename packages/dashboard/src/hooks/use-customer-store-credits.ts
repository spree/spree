import { adminClient, i18n, useResourceMutation } from '@spree/dashboard-core'

type StoreCreditCreateParams = Parameters<typeof adminClient.customers.storeCredits.create>[1]
type StoreCreditUpdateParams = Parameters<typeof adminClient.customers.storeCredits.update>[2]

export type { StoreCreditUpdateParams }

// The `amount` arrives already normalized to canonical `"1234.56"` form — the
// form converts the merchant's localized input client-side (see
// docs/plans/5.5-client-side-money-normalization.md), so no request locale.
export function useCreateCustomerStoreCredit(customerId: string) {
  return useResourceMutation({
    mutationFn: (params: StoreCreditCreateParams) =>
      adminClient.customers.storeCredits.create(customerId, params),
    invalidate: [['customers', customerId]],
    successMessage: i18n.t('admin.messages.store_credit_saved'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateCustomerStoreCredit(customerId: string, creditId: string) {
  return useResourceMutation({
    mutationFn: (params: StoreCreditUpdateParams) =>
      adminClient.customers.storeCredits.update(customerId, creditId, params),
    invalidate: [['customers', customerId]],
    successMessage: i18n.t('admin.messages.store_credit_saved'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteCustomerStoreCredit(customerId: string) {
  return useResourceMutation({
    mutationFn: (id: string) => adminClient.customers.storeCredits.delete(customerId, id),
    invalidate: [['customers', customerId]],
    successMessage: i18n.t('admin.messages.store_credit_removed'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}

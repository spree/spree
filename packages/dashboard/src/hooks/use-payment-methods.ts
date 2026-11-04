import type {
  PaymentMethod,
  PaymentMethodCreateParams,
  PaymentMethodUpdateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  STORE_QUERY_RESOURCE,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

export function usePaymentMethodTypes({ enabled = true }: { enabled?: boolean } = {}) {
  // Every provider, with `installed_count` for how many this store already
  // has: the picker labels them, and an edit form reads an installed
  // provider's schema from the same list. Store-scoped because the count is.
  // Matches the +['payment-methods', 'types']+ shape
  // that +useResourceMutation+ expands to +['payment-methods', storeId, 'types']+.
  return useQuery({
    queryKey: useResourceKey('payment-methods', 'types'),
    queryFn: () => adminClient.paymentMethods.types(),
    staleTime: Infinity,
    enabled,
  })
}

export function usePaymentMethodRuleTypes() {
  return useQuery({
    queryKey: useResourceKey('payment-method-rule-types'),
    queryFn: () => adminClient.paymentMethods.ruleTypes(),
    staleTime: 1000 * 60 * 30,
  })
}

interface UsePaymentMethodsParams {
  page?: number
  limit?: number
  enabled?: boolean
}

export function usePaymentMethods({
  page = 1,
  limit = 100,
  enabled = true,
}: UsePaymentMethodsParams = {}) {
  return useQuery({
    queryKey: useResourceKey('payment-methods', { page, limit }),
    queryFn: () => adminClient.paymentMethods.list({ page, limit }),
    enabled,
  })
}

export function usePaymentMethod(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('payment-methods', id ?? 'noop'),
    queryFn: () => adminClient.paymentMethods.get(id as string),
    enabled: !!id,
  })
}

export function useCreatePaymentMethod() {
  // Invalidate the types registry too, so the picker's installed counts move.
  return useResourceMutation<PaymentMethod, Error, PaymentMethodCreateParams>({
    mutationFn: (params) => adminClient.paymentMethods.create(params),
    // STORE_QUERY_RESOURCE refreshes the setup-task state (Getting Started + nav badge).
    invalidate: [['payment-methods'], ['payment-methods', 'types'], [STORE_QUERY_RESOURCE]],
    successMessage: i18n.t('admin.payment_methods.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdatePaymentMethod(
  id: string,
  { showValidationErrors = false }: { showValidationErrors?: boolean } = {},
) {
  return useResourceMutation<PaymentMethod, Error, PaymentMethodUpdateParams>({
    showValidationErrors,
    mutationFn: (params) => adminClient.paymentMethods.update(id, params),
    invalidate: [['payment-methods'], ['payment-methods', id], [STORE_QUERY_RESOURCE]],
    successMessage: i18n.t('admin.payment_methods.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeletePaymentMethod() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.paymentMethods.delete(id),
    invalidate: [['payment-methods'], ['payment-methods', 'types'], [STORE_QUERY_RESOURCE]],
    successMessage: i18n.t('admin.payment_methods.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('payment-methods', id) })
    },
  })
}

import type {
  PaymentMethod,
  PaymentMethodCreateParams,
  PaymentMethodUpdateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'

export function usePaymentMethodTypes() {
  // Store-scoped because the server filters out providers already installed
  // on the current store. Matches the +['payment-methods', 'types']+ shape
  // that +useResourceMutation+ expands to +['payment-methods', storeId, 'types']+.
  return useQuery({
    queryKey: useResourceKey('payment-methods', 'types'),
    queryFn: () => adminClient.paymentMethods.types(),
    staleTime: Infinity,
  })
}

interface UsePaymentMethodsParams {
  page?: number
  limit?: number
}

export function usePaymentMethods({ page = 1, limit = 100 }: UsePaymentMethodsParams = {}) {
  return useQuery({
    queryKey: useResourceKey('payment-methods', { page, limit }),
    queryFn: () => adminClient.paymentMethods.list({ page, limit }),
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
  // Invalidate the types registry too — the server filters out installed
  // providers, so the picker should drop the just-added one.
  return useResourceMutation<PaymentMethod, Error, PaymentMethodCreateParams>({
    mutationFn: (params) => adminClient.paymentMethods.create(params),
    invalidate: [['payment-methods'], ['payment-methods', 'types']],
    successMessage: 'Payment method created',
    errorMessage: 'Failed to create payment method',
  })
}

export function useUpdatePaymentMethod(id: string) {
  return useResourceMutation<PaymentMethod, Error, PaymentMethodUpdateParams>({
    mutationFn: (params) => adminClient.paymentMethods.update(id, params),
    invalidate: [['payment-methods'], ['payment-methods', id]],
    successMessage: 'Payment method updated',
    errorMessage: 'Failed to update payment method',
  })
}

export function useDeletePaymentMethod() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.paymentMethods.delete(id),
    invalidate: [['payment-methods'], ['payment-methods', 'types']],
    successMessage: 'Payment method deleted',
    errorMessage: 'Failed to delete payment method',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('payment-methods', id) })
    },
  })
}

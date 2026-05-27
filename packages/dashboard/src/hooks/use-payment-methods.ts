import type {
  PaymentMethod,
  PaymentMethodCreateParams,
  PaymentMethodUpdateParams,
} from '@spree/admin-sdk'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '@/client'
import { useResourceMutation } from '@/hooks/use-resource-mutation'

export const paymentMethodTypesQueryKey = ['payment-methods', 'types'] as const

export function usePaymentMethodTypes() {
  return useQuery({
    queryKey: paymentMethodTypesQueryKey,
    queryFn: () => adminClient.paymentMethods.types(),
    staleTime: Infinity,
  })
}

export const paymentMethodsQueryKey = ['payment-methods'] as const

export function paymentMethodQueryKey(id: string) {
  return ['payment-methods', id] as const
}

interface UsePaymentMethodsParams {
  page?: number
  limit?: number
}

export function usePaymentMethods({ page = 1, limit = 100 }: UsePaymentMethodsParams = {}) {
  return useQuery({
    queryKey: [...paymentMethodsQueryKey, { page, limit }],
    queryFn: () => adminClient.paymentMethods.list({ page, limit }),
  })
}

export function usePaymentMethod(id: string | undefined) {
  return useQuery({
    queryKey: id ? paymentMethodQueryKey(id) : ['payment-methods', 'noop'],
    queryFn: () => adminClient.paymentMethods.get(id as string),
    enabled: !!id,
  })
}

export function useCreatePaymentMethod() {
  // Invalidate the types registry too — the server filters out installed
  // providers, so the picker should drop the just-added one.
  return useResourceMutation<PaymentMethod, Error, PaymentMethodCreateParams>({
    mutationFn: (params) => adminClient.paymentMethods.create(params),
    invalidate: [paymentMethodsQueryKey, paymentMethodTypesQueryKey],
    successMessage: 'Payment method created',
    errorMessage: 'Failed to create payment method',
  })
}

export function useUpdatePaymentMethod(id: string) {
  return useResourceMutation<PaymentMethod, Error, PaymentMethodUpdateParams>({
    mutationFn: (params) => adminClient.paymentMethods.update(id, params),
    invalidate: [paymentMethodsQueryKey, paymentMethodQueryKey(id)],
    successMessage: 'Payment method updated',
    errorMessage: 'Failed to update payment method',
  })
}

export function useDeletePaymentMethod() {
  const queryClient = useQueryClient()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.paymentMethods.delete(id),
    invalidate: [paymentMethodsQueryKey, paymentMethodTypesQueryKey],
    successMessage: 'Payment method deleted',
    errorMessage: 'Failed to delete payment method',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: paymentMethodQueryKey(id) })
    },
  })
}

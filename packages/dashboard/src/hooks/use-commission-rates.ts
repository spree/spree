import type {
  CommissionRate,
  CommissionRateCreateParams,
  CommissionRateUpdateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

export function useCommissionRate(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('commission-rates', id ?? 'noop'),
    queryFn: () => adminClient.commissionRates.get(id as string),
    enabled: !!id,
  })
}

/**
 * What a rule may target. Store-independent and effectively static, so it is
 * fetched once and never refetched.
 */
export function useCommissionRuleSubjectTypes() {
  return useQuery({
    queryKey: ['commission-rule-subject-types'],
    queryFn: () => adminClient.commissionRates.ruleSubjectTypes(),
    staleTime: Number.POSITIVE_INFINITY,
  })
}

export function useCreateCommissionRate() {
  return useResourceMutation<CommissionRate, Error, CommissionRateCreateParams>({
    mutationFn: (params) => adminClient.commissionRates.create(params),
    invalidate: [['commission-rates']],
    successMessage: i18n.t('admin.commission_rates.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateCommissionRate(id: string) {
  return useResourceMutation<CommissionRate, Error, CommissionRateUpdateParams>({
    mutationFn: (params) => adminClient.commissionRates.update(id, params),
    invalidate: [['commission-rates'], ['commission-rates', id]],
    successMessage: i18n.t('admin.commission_rates.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteCommissionRate() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.commissionRates.delete(id),
    invalidate: [['commission-rates']],
    successMessage: i18n.t('admin.commission_rates.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('commission-rates', id) })
    },
  })
}

import type {
  Promotion,
  PromotionAction,
  PromotionActionCreateParams,
  PromotionActionUpdateParams,
  PromotionCreateParams,
  PromotionRule,
  PromotionRuleCreateParams,
  PromotionRuleUpdateParams,
  PromotionUpdateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'

interface UsePromotionsParams {
  page?: number
  limit?: number
}

export function usePromotion(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('promotions', id ?? 'noop'),
    queryFn: () => adminClient.promotions.get(id as string),
    enabled: !!id,
  })
}

export function useCreatePromotion() {
  return useResourceMutation<Promotion, Error, PromotionCreateParams>({
    mutationFn: (params) => adminClient.promotions.create(params),
    invalidate: [['promotions']],
    successMessage: 'Promotion created',
    errorMessage: 'Failed to create promotion',
  })
}

export function useUpdatePromotion(id: string) {
  return useResourceMutation<Promotion, Error, PromotionUpdateParams>({
    mutationFn: (params) => adminClient.promotions.update(id, params),
    invalidate: [['promotions'], ['promotions', id]],
    successMessage: 'Promotion updated',
    errorMessage: 'Failed to update promotion',
  })
}

export function useDeletePromotion() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.promotions.delete(id),
    invalidate: [['promotions']],
    successMessage: 'Promotion deleted',
    errorMessage: 'Failed to delete promotion',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('promotions', id) })
    },
  })
}

// ============================================
// Actions
// ============================================

export function usePromotionActions(promotionId: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('promotions', promotionId ?? 'noop', 'actions'),
    queryFn: () => adminClient.promotions.actions.list(promotionId as string, { limit: 100 }),
    enabled: !!promotionId,
  })
}

export function useCreatePromotionAction(promotionId: string) {
  return useResourceMutation<PromotionAction, Error, PromotionActionCreateParams>({
    mutationFn: (params) => adminClient.promotions.actions.create(promotionId, params),
    invalidate: [
      ['promotions', promotionId, 'actions'],
      ['promotions', promotionId],
    ],
    successMessage: 'Action added',
    errorMessage: 'Failed to add action',
  })
}

export function useUpdatePromotionAction(promotionId: string, actionId: string) {
  return useResourceMutation<PromotionAction, Error, PromotionActionUpdateParams>({
    mutationFn: (params) => adminClient.promotions.actions.update(promotionId, actionId, params),
    invalidate: [
      ['promotions', promotionId, 'actions'],
      ['promotions', promotionId],
    ],
    successMessage: 'Action updated',
    errorMessage: 'Failed to update action',
  })
}

export function useDeletePromotionAction(promotionId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (actionId) => adminClient.promotions.actions.delete(promotionId, actionId),
    invalidate: [
      ['promotions', promotionId, 'actions'],
      ['promotions', promotionId],
    ],
    successMessage: 'Action removed',
    errorMessage: 'Failed to remove action',
  })
}

// ============================================
// Rules
// ============================================

export function usePromotionRules(promotionId: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('promotions', promotionId ?? 'noop', 'rules'),
    queryFn: () => adminClient.promotions.rules.list(promotionId as string, { limit: 100 }),
    enabled: !!promotionId,
  })
}

export function useCreatePromotionRule(promotionId: string) {
  return useResourceMutation<PromotionRule, Error, PromotionRuleCreateParams>({
    mutationFn: (params) => adminClient.promotions.rules.create(promotionId, params),
    invalidate: [
      ['promotions', promotionId, 'rules'],
      ['promotions', promotionId],
    ],
    successMessage: 'Rule added',
    errorMessage: 'Failed to add rule',
  })
}

export function useUpdatePromotionRule(promotionId: string, ruleId: string) {
  return useResourceMutation<PromotionRule, Error, PromotionRuleUpdateParams>({
    mutationFn: (params) => adminClient.promotions.rules.update(promotionId, ruleId, params),
    invalidate: [
      ['promotions', promotionId, 'rules'],
      ['promotions', promotionId],
    ],
    successMessage: 'Rule updated',
    errorMessage: 'Failed to update rule',
  })
}

export function useDeletePromotionRule(promotionId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (ruleId) => adminClient.promotions.rules.delete(promotionId, ruleId),
    invalidate: [
      ['promotions', promotionId, 'rules'],
      ['promotions', promotionId],
    ],
    successMessage: 'Rule removed',
    errorMessage: 'Failed to remove rule',
  })
}

// ============================================
// Coupon codes (read-only)
// ============================================

export function usePromotionCouponCodes(
  promotionId: string | undefined,
  params: UsePromotionsParams = {},
) {
  return useQuery({
    queryKey: useResourceKey('promotions', promotionId ?? 'noop', 'coupon-codes', params),
    queryFn: () =>
      adminClient.promotions.couponCodes.list(promotionId as string, {
        page: params.page ?? 1,
        limit: params.limit ?? 50,
      }),
    enabled: !!promotionId,
  })
}

// ============================================
// Type registries (cached forever — registries are static at runtime)
// ============================================

export function usePromotionActionTypes() {
  return useQuery({
    queryKey: ['promotion-actions', 'types'],
    queryFn: () => adminClient.promotionActions.types(),
    staleTime: Infinity,
  })
}

export function usePromotionRuleTypes() {
  return useQuery({
    queryKey: ['promotion-rules', 'types'],
    queryFn: () => adminClient.promotionRules.types(),
    staleTime: Infinity,
  })
}

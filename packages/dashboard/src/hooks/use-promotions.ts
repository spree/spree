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
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '@/client'
import { useResourceMutation } from '@/hooks/use-resource-mutation'

export const promotionsQueryKey = ['promotions'] as const

export function promotionQueryKey(id: string) {
  return ['promotions', id] as const
}

export function promotionActionsQueryKey(promotionId: string) {
  return ['promotions', promotionId, 'actions'] as const
}

export function promotionRulesQueryKey(promotionId: string) {
  return ['promotions', promotionId, 'rules'] as const
}

export function promotionCouponCodesQueryKey(promotionId: string) {
  return ['promotions', promotionId, 'coupon-codes'] as const
}

interface UsePromotionsParams {
  page?: number
  limit?: number
}

export function usePromotion(id: string | undefined) {
  return useQuery({
    queryKey: id ? promotionQueryKey(id) : ['promotions', 'noop'],
    queryFn: () => adminClient.promotions.get(id as string),
    enabled: !!id,
  })
}

export function useCreatePromotion() {
  return useResourceMutation<Promotion, Error, PromotionCreateParams>({
    mutationFn: (params) => adminClient.promotions.create(params),
    invalidate: [promotionsQueryKey],
    successMessage: 'Promotion created',
    errorMessage: 'Failed to create promotion',
  })
}

export function useUpdatePromotion(id: string) {
  return useResourceMutation<Promotion, Error, PromotionUpdateParams>({
    mutationFn: (params) => adminClient.promotions.update(id, params),
    invalidate: [promotionsQueryKey, promotionQueryKey(id)],
    successMessage: 'Promotion updated',
    errorMessage: 'Failed to update promotion',
  })
}

export function useDeletePromotion() {
  const queryClient = useQueryClient()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.promotions.delete(id),
    invalidate: [promotionsQueryKey],
    successMessage: 'Promotion deleted',
    errorMessage: 'Failed to delete promotion',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: promotionQueryKey(id) })
    },
  })
}

// ============================================
// Actions
// ============================================

export function usePromotionActions(promotionId: string | undefined) {
  return useQuery({
    queryKey: promotionId
      ? promotionActionsQueryKey(promotionId)
      : ['promotions', 'noop', 'actions'],
    queryFn: () => adminClient.promotions.actions.list(promotionId as string, { limit: 100 }),
    enabled: !!promotionId,
  })
}

export function useCreatePromotionAction(promotionId: string) {
  return useResourceMutation<PromotionAction, Error, PromotionActionCreateParams>({
    mutationFn: (params) => adminClient.promotions.actions.create(promotionId, params),
    invalidate: [promotionActionsQueryKey(promotionId), promotionQueryKey(promotionId)],
    successMessage: 'Action added',
    errorMessage: 'Failed to add action',
  })
}

export function useUpdatePromotionAction(promotionId: string, actionId: string) {
  return useResourceMutation<PromotionAction, Error, PromotionActionUpdateParams>({
    mutationFn: (params) => adminClient.promotions.actions.update(promotionId, actionId, params),
    invalidate: [promotionActionsQueryKey(promotionId), promotionQueryKey(promotionId)],
    successMessage: 'Action updated',
    errorMessage: 'Failed to update action',
  })
}

export function useDeletePromotionAction(promotionId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (actionId) => adminClient.promotions.actions.delete(promotionId, actionId),
    invalidate: [promotionActionsQueryKey(promotionId), promotionQueryKey(promotionId)],
    successMessage: 'Action removed',
    errorMessage: 'Failed to remove action',
  })
}

// ============================================
// Rules
// ============================================

export function usePromotionRules(promotionId: string | undefined) {
  return useQuery({
    queryKey: promotionId ? promotionRulesQueryKey(promotionId) : ['promotions', 'noop', 'rules'],
    queryFn: () => adminClient.promotions.rules.list(promotionId as string, { limit: 100 }),
    enabled: !!promotionId,
  })
}

export function useCreatePromotionRule(promotionId: string) {
  return useResourceMutation<PromotionRule, Error, PromotionRuleCreateParams>({
    mutationFn: (params) => adminClient.promotions.rules.create(promotionId, params),
    invalidate: [promotionRulesQueryKey(promotionId), promotionQueryKey(promotionId)],
    successMessage: 'Rule added',
    errorMessage: 'Failed to add rule',
  })
}

export function useUpdatePromotionRule(promotionId: string, ruleId: string) {
  return useResourceMutation<PromotionRule, Error, PromotionRuleUpdateParams>({
    mutationFn: (params) => adminClient.promotions.rules.update(promotionId, ruleId, params),
    invalidate: [promotionRulesQueryKey(promotionId), promotionQueryKey(promotionId)],
    successMessage: 'Rule updated',
    errorMessage: 'Failed to update rule',
  })
}

export function useDeletePromotionRule(promotionId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (ruleId) => adminClient.promotions.rules.delete(promotionId, ruleId),
    invalidate: [promotionRulesQueryKey(promotionId), promotionQueryKey(promotionId)],
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
    queryKey: promotionId
      ? [...promotionCouponCodesQueryKey(promotionId), params]
      : ['promotions', 'noop', 'coupon-codes'],
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

export const promotionActionTypesQueryKey = ['promotion-actions', 'types'] as const
export const promotionRuleTypesQueryKey = ['promotion-rules', 'types'] as const

export function usePromotionActionTypes() {
  return useQuery({
    queryKey: promotionActionTypesQueryKey,
    queryFn: () => adminClient.promotionActions.types(),
    staleTime: Infinity,
  })
}

export function usePromotionRuleTypes() {
  return useQuery({
    queryKey: promotionRuleTypesQueryKey,
    queryFn: () => adminClient.promotionRules.types(),
    staleTime: Infinity,
  })
}

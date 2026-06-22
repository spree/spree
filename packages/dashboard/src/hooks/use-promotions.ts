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
import i18n from 'i18next'

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
    successMessage: i18n.t('admin.messages.promotion_created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdatePromotion(id: string) {
  return useResourceMutation<Promotion, Error, PromotionUpdateParams>({
    mutationFn: (params) => adminClient.promotions.update(id, params),
    invalidate: [['promotions'], ['promotions', id]],
    successMessage: i18n.t('admin.messages.promotion_saved'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeletePromotion() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.promotions.delete(id),
    invalidate: [['promotions']],
    successMessage: i18n.t('admin.messages.promotion_deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
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
    successMessage: i18n.t('admin.promotions.messages.action_added'),
    errorMessage: i18n.t('admin.promotions.errors.failed_to_add_action'),
  })
}

export function useUpdatePromotionAction(promotionId: string, actionId: string) {
  return useResourceMutation<PromotionAction, Error, PromotionActionUpdateParams>({
    mutationFn: (params) => adminClient.promotions.actions.update(promotionId, actionId, params),
    invalidate: [
      ['promotions', promotionId, 'actions'],
      ['promotions', promotionId],
    ],
    successMessage: i18n.t('admin.promotions.messages.action_updated'),
    errorMessage: i18n.t('admin.promotions.errors.failed_to_update_action'),
  })
}

export function useDeletePromotionAction(promotionId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (actionId) => adminClient.promotions.actions.delete(promotionId, actionId),
    invalidate: [
      ['promotions', promotionId, 'actions'],
      ['promotions', promotionId],
    ],
    successMessage: i18n.t('admin.promotions.messages.action_removed'),
    errorMessage: i18n.t('admin.promotions.errors.failed_to_remove_action'),
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
    successMessage: i18n.t('admin.promotions.messages.rule_added'),
    errorMessage: i18n.t('admin.promotions.errors.failed_to_add_rule'),
  })
}

export function useUpdatePromotionRule(promotionId: string, ruleId: string) {
  return useResourceMutation<PromotionRule, Error, PromotionRuleUpdateParams>({
    mutationFn: (params) => adminClient.promotions.rules.update(promotionId, ruleId, params),
    invalidate: [
      ['promotions', promotionId, 'rules'],
      ['promotions', promotionId],
    ],
    successMessage: i18n.t('admin.promotions.messages.rule_updated'),
    errorMessage: i18n.t('admin.promotions.errors.failed_to_update_rule'),
  })
}

export function useDeletePromotionRule(promotionId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (ruleId) => adminClient.promotions.rules.delete(promotionId, ruleId),
    invalidate: [
      ['promotions', promotionId, 'rules'],
      ['promotions', promotionId],
    ],
    successMessage: i18n.t('admin.promotions.messages.rule_removed'),
    errorMessage: i18n.t('admin.promotions.errors.failed_to_remove_rule'),
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

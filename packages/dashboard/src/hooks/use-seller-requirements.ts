import type {
  SellerOnboarding,
  SellerRequirement,
  SellerRequirementCreateParams,
  SellerRequirementReviewParams,
  SellerRequirementSubmission,
  SellerRequirementUpdateParams,
  SellerRequirementWaiveParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

/**
 * The requirement kinds an operator can add, with each one's configuration
 * shape. Store-scoped because the response says which single-instance kinds
 * this store already has.
 */
export function useSellerRequirementTypes() {
  return useQuery({
    queryKey: useResourceKey('seller-requirements', 'types'),
    queryFn: () => adminClient.sellerRequirements.types(),
  })
}

export function useSellerRequirements({ page = 1, limit = 100 } = {}) {
  return useQuery({
    queryKey: useResourceKey('seller-requirements', { page, limit }),
    queryFn: () => adminClient.sellerRequirements.list({ page, limit }),
  })
}

export function useCreateSellerRequirement() {
  // The types list carries a `configured` flag per kind, so it goes stale the
  // moment a single-instance kind is added.
  return useResourceMutation<SellerRequirement, Error, SellerRequirementCreateParams>({
    mutationFn: (params) => adminClient.sellerRequirements.create(params),
    invalidate: [['seller-requirements'], ['seller-requirements', 'types']],
    successMessage: i18n.t('admin.seller_requirements.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateSellerRequirement(id: string) {
  return useResourceMutation<SellerRequirement, Error, SellerRequirementUpdateParams>({
    mutationFn: (params) => adminClient.sellerRequirements.update(id, params),
    invalidate: [['seller-requirements'], ['seller-requirements', id]],
    successMessage: i18n.t('admin.seller_requirements.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteSellerRequirement() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.sellerRequirements.delete(id),
    invalidate: [['seller-requirements'], ['seller-requirements', 'types']],
    successMessage: i18n.t('admin.seller_requirements.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('seller-requirements', id) })
    },
  })
}

/** Where one seller stands against the marketplace's checklist. */
export function useSellerOnboarding(sellerId: string | undefined) {
  return useQuery<SellerOnboarding>({
    queryKey: useResourceKey('sellers', sellerId ?? 'noop', 'onboarding'),
    queryFn: () => adminClient.sellers.onboarding(sellerId as string),
    enabled: !!sellerId,
  })
}

export function useAcceptSellerRequirementSubmission(sellerId: string) {
  return useResourceMutation<
    SellerRequirementSubmission,
    Error,
    { id: string; params?: SellerRequirementReviewParams }
  >({
    mutationFn: ({ id, params }) =>
      adminClient.sellers.requirementSubmissions.accept(sellerId, id, params),
    invalidate: [
      ['sellers', sellerId, 'onboarding'],
      ['sellers', sellerId],
    ],
    successMessage: i18n.t('admin.seller_requirements.messages.submission_accepted'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useRejectSellerRequirementSubmission(sellerId: string) {
  return useResourceMutation<
    SellerRequirementSubmission,
    Error,
    { id: string; params?: SellerRequirementReviewParams }
  >({
    mutationFn: ({ id, params }) =>
      adminClient.sellers.requirementSubmissions.reject(sellerId, id, params),
    invalidate: [
      ['sellers', sellerId, 'onboarding'],
      ['sellers', sellerId],
    ],
    successMessage: i18n.t('admin.seller_requirements.messages.submission_rejected'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useWaiveSellerRequirement(sellerId: string) {
  return useResourceMutation<SellerRequirementSubmission, Error, SellerRequirementWaiveParams>({
    mutationFn: (params) => adminClient.sellers.requirementSubmissions.waive(sellerId, params),
    invalidate: [
      ['sellers', sellerId, 'onboarding'],
      ['sellers', sellerId],
    ],
    successMessage: i18n.t('admin.seller_requirements.messages.waived'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

import type {
  ClaimReason,
  OrderCancellationReason,
  ReasonCreateParams,
  ReasonUpdateParams,
  RefundReason,
  ReturnReason,
} from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'
import i18n from 'i18next'

/** Any of the reason lists — they share one shape. */
export type Reason = ReturnReason | ClaimReason | RefundReason | OrderCancellationReason

/** Which list a screen is working with. Doubles as the query key. */
export type ReasonKind =
  | 'return-reasons'
  | 'claim-reasons'
  | 'refund-reasons'
  | 'order-cancellation-reasons'

const CLIENTS = {
  'return-reasons': () => adminClient.returnReasons,
  'claim-reasons': () => adminClient.claimReasons,
  'refund-reasons': () => adminClient.refundReasons,
  'order-cancellation-reasons': () => adminClient.orderCancellationReasons,
} as const

/**
 * Every reason list is short — a handful of rows a merchant reads in one go —
 * so they are fetched unpaginated and cached for the session. Deliberately
 * unfiltered: one cache entry per kind means the pickers in the create
 * dialogs reuse whatever the settings page already loaded, and they narrow to
 * the active rows in memory rather than paying for a second entry.
 */
export function useReasons(kind: ReasonKind) {
  return useQuery({
    queryKey: useResourceKey(kind),
    queryFn: () => CLIENTS[kind]().list({ limit: 100 }),
    staleTime: 1000 * 60 * 5,
  })
}

export function useCreateReason(kind: ReasonKind) {
  return useResourceMutation<Reason, Error, ReasonCreateParams>({
    mutationFn: (params) => CLIENTS[kind]().create(params),
    invalidate: [[kind]],
    successMessage: i18n.t('admin.reasons.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateReason(kind: ReasonKind, id: string) {
  return useResourceMutation<Reason, Error, ReasonUpdateParams>({
    mutationFn: (params) => CLIENTS[kind]().update(id, params),
    invalidate: [[kind]],
    successMessage: i18n.t('admin.reasons.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteReason(kind: ReasonKind) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => CLIENTS[kind]().delete(id),
    invalidate: [[kind]],
    successMessage: i18n.t('admin.reasons.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}

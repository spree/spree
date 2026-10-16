import type {
  ClaimReason,
  OrderCancellationReason,
  ReasonCreateParams,
  ReasonUpdateParams,
  RefundReason,
  ReturnReason,
  TaxExemptionReason,
} from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'
import i18n from 'i18next'
import { useMemo } from 'react'

/** Any of the reason lists. Tax exemption reasons also carry the `code` a tax engine reads. */
export type Reason =
  | ReturnReason
  | ClaimReason
  | RefundReason
  | OrderCancellationReason
  | TaxExemptionReason

/** What a reason form sends; `code` applies to tax exemption reasons only. */
export type ReasonParams = ReasonCreateParams & ReasonUpdateParams & { code?: string }

/** Which list a screen is working with. Doubles as the query key. */
export type ReasonKind =
  | 'return-reasons'
  | 'claim-reasons'
  | 'refund-reasons'
  | 'order-cancellation-reasons'
  | 'tax-exemption-reasons'

const CLIENTS = {
  'return-reasons': () => adminClient.returnReasons,
  'claim-reasons': () => adminClient.claimReasons,
  'refund-reasons': () => adminClient.refundReasons,
  'order-cancellation-reasons': () => adminClient.orderCancellationReasons,
  // Typed as the other lists: its create body is theirs plus `code`, which
  // `ReasonParams` carries.
  'tax-exemption-reasons': () =>
    adminClient.taxExemptionReasons as unknown as typeof adminClient.returnReasons,
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
  return useResourceMutation<Reason, Error, ReasonParams>({
    mutationFn: (params) => CLIENTS[kind]().create(params),
    invalidate: [[kind]],
    successMessage: i18n.t('admin.reasons.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateReason(kind: ReasonKind, id: string) {
  return useResourceMutation<Reason, Error, ReasonParams>({
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

/** The store's tax exemption reasons, typed with the `code` the other lists lack. */
export function useTaxExemptionReasons() {
  const { data } = useReasons('tax-exemption-reasons')
  // The list endpoint is the tax exemption one, whatever the shared client type says.
  return useMemo(() => (data?.data ?? []) as TaxExemptionReason[], [data])
}

/**
 * The store's own name for each tax exemption reason code, so a certificate
 * or an exempt tax line reads as the reason the merchant picked rather than
 * the code it stores.
 */
export function useTaxExemptionReasonNames() {
  const reasons = useTaxExemptionReasons()

  return useMemo(() => new Map(reasons.map((reason) => [reason.code, reason.name])), [reasons])
}

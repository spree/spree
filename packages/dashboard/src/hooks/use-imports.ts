import type { Import, ImportCompleteMappingParams } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceKeyBuilder } from '@spree/dashboard-core'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect } from 'react'
import { toast } from 'sonner'
import { isImportActive } from '../lib/import-types'

export { isImportActive }

const IMPORT_POLL_INTERVAL_MS = 2000
const ROWS_POLL_INTERVAL_MS = 5000

// Caches any import may have written to, plus `imports` itself (history table
// status column). Deliberately not per-type — imports are rare, so a few
// extra refetches beat maintaining a type → resource map (product rows alone
// fan out to option types/values and categories created on the fly).
const IMPORT_TOUCHED_RESOURCES = ['products', 'option-types', 'categories', 'customers', 'imports']

/**
 * Single import, polled every 2s while the pipeline is running. `mapping`
 * (user-driven) and terminal statuses don't poll — a mapping-state refetch
 * would re-read the attached CSV server-side on every tick.
 *
 * A finished import (completed, or failed — earlier rows may still have been
 * written) invalidates every cache imports can touch: the pipeline writes
 * records server-side, outside any tracked mutation, so nothing else ever
 * marks those lists stale and "View products" would keep serving the
 * pre-import cache.
 */
export function useImport(id: string) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  const query = useQuery({
    queryKey: useResourceKey('imports', id),
    queryFn: () => adminClient.imports.get(id),
    enabled: !!id,
    refetchInterval: (query) =>
      isImportActive(query.state.data?.status) ? IMPORT_POLL_INTERVAL_MS : false,
  })

  // Fires when the poll lands on a finished status — including again after
  // each retry pass (`finished` flips false → true anew). Reopening an
  // already-finished import refires it; harmless, invalidation is idempotent.
  const status = query.data?.status
  const finished = status === 'completed' || status === 'failed'
  useEffect(() => {
    if (!finished) return
    for (const resource of IMPORT_TOUCHED_RESOURCES) {
      queryClient.invalidateQueries({ queryKey: buildKey(resource) })
    }
  }, [finished, queryClient, buildKey])

  return query
}

/** Rows of an import (the failure report), optionally polled while processing. */
export function useImportRows(
  importId: string,
  params: Record<string, unknown>,
  options?: { poll?: boolean },
) {
  return useQuery({
    queryKey: useResourceKey('imports', importId, 'rows', params),
    queryFn: () => adminClient.imports.rows.list(importId, params),
    enabled: !!importId,
    refetchInterval: options?.poll ? ROWS_POLL_INTERVAL_MS : false,
    placeholderData: (previous) => previous,
  })
}

export function useCompleteMapping(id: string) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useMutation({
    mutationFn: (params?: ImportCompleteMappingParams) =>
      adminClient.imports.completeMapping(id, params),
    onSuccess: (imp) => {
      queryClient.setQueryData<Import>(buildKey('imports', id), imp)
      // Keep the history table's status column in sync.
      queryClient.invalidateQueries({ queryKey: buildKey('imports') })
    },
  })
}

export function useRetryFailedRows(id: string) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useMutation({
    mutationFn: () => adminClient.imports.retryFailedRows(id),
    onSuccess: (imp) => {
      queryClient.setQueryData<Import>(buildKey('imports', id), imp)
      // `refetchType: 'none'` refreshes the history list on its next mount
      // without refetching the active wizard detail query: the retry response
      // already carried the fresh `processing` status we just cached, and an
      // immediate refetch would race the (fast) background retry job — often
      // returning `completed` before the "Retrying failed rows" state is ever
      // rendered. Marking stale keeps the poll as the single source of the
      // completion transition.
      queryClient.invalidateQueries({ queryKey: buildKey('imports'), refetchType: 'none' })
    },
    onError: (err) => {
      toast.error(err instanceof Error ? err.message : String(err))
    },
  })
}

export function useDeleteImport() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useMutation({
    mutationFn: (id: string) => adminClient.imports.delete(id),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('imports', id) })
      queryClient.invalidateQueries({ queryKey: buildKey('imports') })
    },
    onError: (err) => {
      toast.error(err instanceof Error ? err.message : String(err))
    },
  })
}

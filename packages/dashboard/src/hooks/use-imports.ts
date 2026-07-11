import type { Import, ImportCompleteMappingParams } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceKeyBuilder } from '@spree/dashboard-core'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { isImportActive } from '@/lib/import-types'

export { isImportActive }

const IMPORT_POLL_INTERVAL_MS = 2000
const ROWS_POLL_INTERVAL_MS = 5000

/**
 * Single import, polled every 2s while the pipeline is running. `mapping`
 * (user-driven) and terminal statuses don't poll — a mapping-state refetch
 * would re-read the attached CSV server-side on every tick.
 */
export function useImport(id: string) {
  return useQuery({
    queryKey: useResourceKey('imports', id),
    queryFn: () => adminClient.imports.get(id),
    enabled: !!id,
    refetchInterval: (query) =>
      isImportActive(query.state.data?.status) ? IMPORT_POLL_INTERVAL_MS : false,
  })
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
      queryClient.invalidateQueries({ queryKey: buildKey('imports') })
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

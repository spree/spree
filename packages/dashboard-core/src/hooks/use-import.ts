import { toastManager } from '@spree/dashboard-ui'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect } from 'react'
import {
  getApiClient,
  type PanelImport,
  type PanelImportCompleteMappingParams,
  type PanelImportDelimiter,
} from '../api-client'
import { downloadFromApi } from '../lib/download'
import { useResourceKey, useResourceKeyBuilder } from '../lib/query-keys'
import { useTenantId } from '../providers/tenant-provider'
import { useAuth } from './use-auth'

/** Statuses the wizard polls through — row creation and processing. */
const ACTIVE_STATUSES = new Set(['completed_mapping', 'processing'])

const IMPORT_POLL_INTERVAL_MS = 2000
const ROWS_POLL_INTERVAL_MS = 5000

// Caches any import may have written to, plus `imports` itself (history table
// status column). Deliberately not per-type — imports are rare, so a few
// extra refetches beat maintaining a type → resource map (product rows alone
// fan out to option types/values and categories created on the fly).
//
// These are the operator dashboard's key names; a panel that names its lists
// differently adds its own through the client's `invalidateKeys`.
const IMPORT_TOUCHED_RESOURCES = ['products', 'option-types', 'categories', 'customers', 'imports']

/** Whether the import's pipeline is still running (the poll's continue predicate). */
export function isImportActive(status: string | undefined): boolean {
  return !!status && ACTIVE_STATUSES.has(status)
}

/**
 * The panel's import resource.
 *
 * Throws rather than returning undefined: every hook here is reached from UI
 * that only renders when the panel registered one, so a miss is a boot
 * misconfiguration and should say so where it happens.
 */
function imports() {
  const resource = getApiClient().imports
  if (!resource) {
    throw new Error(
      '@spree/dashboard-core: this panel registered no `imports` client. ' +
        'Add one in setApiClient(...) before rendering import UI.',
    )
  }

  return resource
}

export interface CreateImportInput {
  type: string
  /** Signed blob id of the already direct-uploaded CSV (see `FileUploadField`). */
  signedId: string
  preferredDelimiter?: PanelImportDelimiter
  /**
   * Where the import-done email should link back to. Defaults to this panel's
   * own imports view under the current tenant.
   */
  resultsPath?: string
}

/**
 * Creates the import from a direct-uploaded CSV; the response is in the
 * `mapping` state and carries the mapping payload.
 */
export function useCreateImport() {
  const tenantId = useTenantId()

  return useMutation({
    mutationFn: ({
      type,
      signedId,
      preferredDelimiter,
      resultsPath,
    }: CreateImportInput): Promise<PanelImport> =>
      imports().create({
        type,
        attachment: signedId,
        preferred_delimiter: preferredDelimiter,
        // The import-done email deep-links back to the wizard (`?import=<id>`
        // appended server-side). Only honored when this origin is on the
        // store's allowed-origins list.
        results_url: `${window.location.origin}${resultsPath ?? `/${tenantId}/settings/imports`}`,
      }),
  })
}

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
    queryFn: () => imports().get(id),
    enabled: !!id,
    refetchInterval: (query) =>
      isImportActive(query.state.data?.status) ? IMPORT_POLL_INTERVAL_MS : false,
  })

  // Fires when the poll lands on a finished status — including again after
  // each retry pass (`finished` flips false → true anew). Reopening an
  // already-finished import refires it; harmless, invalidation is idempotent.
  const status = query.data?.status
  const finished = status === 'completed' || status === 'failed'
  const extraKeys = getApiClient().imports?.invalidateKeys
  useEffect(() => {
    if (!finished) return
    for (const resource of new Set([...IMPORT_TOUCHED_RESOURCES, ...(extraKeys ?? [])])) {
      queryClient.invalidateQueries({ queryKey: buildKey(resource) })
    }
  }, [finished, queryClient, buildKey, extraKeys])

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
    queryFn: () => imports().rows.list(importId, params),
    enabled: !!importId,
    refetchInterval: options?.poll ? ROWS_POLL_INTERVAL_MS : false,
    placeholderData: (previous) => previous,
  })
}

export function useCompleteMapping(id: string) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useMutation({
    mutationFn: (params?: PanelImportCompleteMappingParams) =>
      imports().completeMapping(id, params),
    onSuccess: (imp) => {
      queryClient.setQueryData<PanelImport>(buildKey('imports', id), imp)
      // Keep the history table's status column in sync.
      queryClient.invalidateQueries({ queryKey: buildKey('imports') })
    },
  })
}

export function useRetryFailedRows(id: string) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useMutation({
    mutationFn: () => imports().retryFailedRows(id),
    onSuccess: (imp) => {
      queryClient.setQueryData<PanelImport>(buildKey('imports', id), imp)
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
      toastManager.add({ type: 'error', title: err instanceof Error ? err.message : String(err) })
    },
  })
}

export function useDeleteImport() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useMutation({
    mutationFn: (id: string) => imports().delete(id),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('imports', id) })
      queryClient.invalidateQueries({ queryKey: buildKey('imports') })
    },
    onError: (err) => {
      toastManager.add({ type: 'error', title: err instanceof Error ? err.message : String(err) })
    },
  })
}

/** Downloads the CSV template for an import type. */
export function useDownloadImportTemplate() {
  const { token } = useAuth()

  return useMutation({
    mutationFn: (type: string) =>
      downloadFromApi(
        token,
        imports().templateUrl(type),
        'import_template.csv',
        getApiClient().downloadHeaders?.() ?? {},
      ),
  })
}

/**
 * Downloads the populated example CSV for an import type.
 *
 * Goes through the API rather than linking the file directly: the URL is pinned
 * to the installed Spree version so a released install never links to a newer,
 * incompatible schema — and that version is deliberately not exposed over the
 * API, since it would fingerprint the deployment. Returns 404 for a type that
 * ships no example file.
 */
export function useDownloadImportExample() {
  const { token } = useAuth()

  return useMutation({
    mutationFn: (type: string) =>
      downloadFromApi(
        token,
        imports().exampleUrl(type),
        `${type}.csv`,
        getApiClient().downloadHeaders?.() ?? {},
      ),
  })
}

/** Downloads the originally uploaded CSV of an import — the audit trail. */
export function useDownloadImportOriginal() {
  const { token } = useAuth()

  return useMutation({
    mutationFn: (imp: PanelImport) =>
      downloadFromApi(
        token,
        imp.original_file_url ?? imports().downloadUrl(imp.id),
        imp.original_filename ?? 'import.csv',
        getApiClient().downloadHeaders?.() ?? {},
      ),
  })
}

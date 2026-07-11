import type { Import, ImportCreateParams, ImportType } from '@spree/admin-sdk'
import { useMutation } from '@tanstack/react-query'
import { adminClient } from '../client'
import { useStore } from '../providers/store-provider'
import { useAuth } from './use-auth'

const API_BASE_URL = import.meta.env.VITE_SPREE_API_URL || ''

export interface CreateImportInput {
  type: ImportType
  /** Signed blob id of the already direct-uploaded CSV (see `FileUploadField`). */
  signedId: string
  preferredDelimiter?: ImportCreateParams['preferred_delimiter']
}

/**
 * Creates the import from a direct-uploaded CSV; the response is in the
 * `mapping` state and carries the mapping payload.
 */
export function useCreateImport() {
  const { storeId } = useStore()

  return useMutation({
    mutationFn: ({ type, signedId, preferredDelimiter }: CreateImportInput): Promise<Import> =>
      adminClient.imports.create({
        type,
        attachment: signedId,
        preferred_delimiter: preferredDelimiter,
        // The import-done email deep-links back to the wizard (`?import=<id>`
        // appended server-side). Only honored when this origin is on the
        // store's allowed-origins list.
        results_url: `${window.location.origin}/${storeId}/settings/imports`,
      }),
  })
}

/**
 * Authed fetch → Blob URL download. The endpoints are JWT-protected, so a
 * top-level navigation (which cannot carry the in-memory token) does not work.
 */
async function downloadFromApi(token: string | null, path: string, fallbackName: string) {
  const headers: Record<string, string> = {}
  if (token) headers.Authorization = `Bearer ${token}`

  const response = await fetch(`${API_BASE_URL}${path}`, { headers, credentials: 'include' })
  if (!response.ok) throw new Error(`Download failed: ${response.status}`)

  const disposition = response.headers.get('Content-Disposition')
  const filename = disposition?.match(/filename="?([^";]+)"?/)?.[1] ?? fallbackName

  const blob = await response.blob()
  const objectUrl = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = objectUrl
  anchor.download = filename
  document.body.appendChild(anchor)
  anchor.click()
  anchor.remove()
  URL.revokeObjectURL(objectUrl)
}

/** Downloads the CSV template for an import type. */
export function useDownloadImportTemplate() {
  const { token } = useAuth()

  return useMutation({
    mutationFn: (type: ImportType) =>
      downloadFromApi(
        token,
        `/api/v3/admin/imports/template?type=${encodeURIComponent(type)}`,
        'import_template.csv',
      ),
  })
}

/** Downloads the originally uploaded CSV of an import — the audit trail. */
export function useDownloadImportOriginal() {
  const { token } = useAuth()

  return useMutation({
    mutationFn: (imp: Import) =>
      downloadFromApi(
        token,
        imp.original_file_url ?? `/api/v3/admin/imports/${imp.id}/download`,
        imp.original_filename ?? 'import.csv',
      ),
  })
}

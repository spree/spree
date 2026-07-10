import type { Import, ImportCreateParams, ImportType } from '@spree/admin-sdk'
import { useMutation } from '@tanstack/react-query'
import { adminClient } from '../client'
import { useAuth } from './use-auth'
import { useDirectUpload } from './use-direct-upload'

const API_BASE_URL = import.meta.env.VITE_SPREE_API_URL || ''

export interface CreateImportInput {
  type: ImportType
  file: File
  preferredDelimiter?: ImportCreateParams['preferred_delimiter']
}

/**
 * Direct-uploads the CSV, then creates the import (returned in the `mapping`
 * state). The file is re-wrapped with an explicit `text/csv` content type —
 * Windows browsers report `.csv` files as `application/vnd.ms-excel`, which
 * the server's content-type validation rejects.
 */
export function useCreateImport() {
  const directUpload = useDirectUpload()

  return useMutation({
    mutationFn: async ({ type, file, preferredDelimiter }: CreateImportInput): Promise<Import> => {
      const csvFile = new File([file], file.name, { type: 'text/csv' })
      const { signedId } = await directUpload.mutateAsync(csvFile)

      return adminClient.imports.create({
        type,
        attachment: signedId,
        preferred_delimiter: preferredDelimiter,
      })
    },
  })
}

/**
 * Fetches the CSV template for an import type and drives a browser download
 * via a Blob URL — the endpoint is JWT-protected, so a top-level navigation
 * (which cannot carry the in-memory token) does not work.
 */
export function useDownloadImportTemplate() {
  const { token } = useAuth()

  return useMutation({
    mutationFn: async (type: ImportType): Promise<void> => {
      const url = `${API_BASE_URL}/api/v3/admin/imports/template?type=${encodeURIComponent(type)}`
      const headers: Record<string, string> = {}
      if (token) headers.Authorization = `Bearer ${token}`

      const response = await fetch(url, { headers, credentials: 'include' })
      if (!response.ok) throw new Error(`Template download failed: ${response.status}`)

      const disposition = response.headers.get('Content-Disposition')
      const filename = disposition?.match(/filename="?([^";]+)"?/)?.[1] ?? 'import_template.csv'

      const blob = await response.blob()
      const objectUrl = URL.createObjectURL(blob)
      const anchor = document.createElement('a')
      anchor.href = objectUrl
      anchor.download = filename
      document.body.appendChild(anchor)
      anchor.click()
      anchor.remove()
      URL.revokeObjectURL(objectUrl)
    },
  })
}

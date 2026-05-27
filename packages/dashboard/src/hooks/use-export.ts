import type { Export, ExportCreateParams } from '@spree/admin-sdk'
import { useMutation } from '@tanstack/react-query'
import { toast } from 'sonner'
import { adminClient } from '@/client'
import { useAuth } from '@/hooks/use-auth'

const POLL_INTERVAL_MS = 2000
const POLL_TIMEOUT_MS = 5 * 60 * 1000
const API_BASE_URL = import.meta.env.VITE_SPREE_API_URL || ''
const API_ORIGIN = API_BASE_URL ? new URL(API_BASE_URL).origin : window.location.origin

class ExportTimeoutError extends Error {
  constructor() {
    super('Export timed out')
    this.name = 'ExportTimeoutError'
  }
}

/**
 * Resolve `download_url` (a path or absolute URL) against the API base.
 * Returns both the resolved URL and whether it points at the trusted API
 * origin — only same-origin requests get the `Authorization` header so we
 * can't accidentally leak a JWT to a third-party host.
 */
function resolveDownload(downloadUrl: string): { url: string; sameOrigin: boolean } {
  const url = /^https?:\/\//.test(downloadUrl) ? downloadUrl : `${API_BASE_URL}${downloadUrl}`
  const sameOrigin = new URL(url, window.location.origin).origin === API_ORIGIN
  return { url, sameOrigin }
}

async function pollUntilDone(id: string): Promise<Export> {
  const deadline = Date.now() + POLL_TIMEOUT_MS

  while (Date.now() < deadline) {
    const exp = await adminClient.exports.get(id)
    if (exp.done) return exp
    await new Promise<void>((resolve) => setTimeout(resolve, POLL_INTERVAL_MS))
  }

  throw new ExportTimeoutError()
}

// `window.location` won't carry the in-memory JWT, so we fetch the file
// ourselves and drive the download via a Blob URL.
async function downloadExportFile(exp: Export, token: string | null): Promise<void> {
  if (!exp.download_url) throw new Error('Export has no download_url')

  const { url, sameOrigin } = resolveDownload(exp.download_url)
  const headers: Record<string, string> = {}
  if (sameOrigin && token) headers.Authorization = `Bearer ${token}`

  const response = await fetch(url, {
    headers,
    credentials: sameOrigin ? 'include' : 'omit',
  })

  if (!response.ok) throw new Error(`Download failed: ${response.status}`)

  const blob = await response.blob()
  const objectUrl = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = objectUrl
  anchor.download = exp.filename ?? 'export.csv'
  document.body.appendChild(anchor)
  anchor.click()
  anchor.remove()
  URL.revokeObjectURL(objectUrl)
}

/**
 * Queue a CSV export and drive it to completion: create → poll → download.
 * On poll timeout, falls back to the email-link path —
 * `Spree::ExportMailer.export_done` already covers that server-side.
 */
export function useExport() {
  const { token } = useAuth()

  return useMutation({
    mutationFn: async (params: ExportCreateParams) => {
      // Per-invocation id so concurrent exports don't collide on a single
      // sticky toast.
      const toastId = `export-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`
      toast.loading('Preparing export…', { id: toastId })

      try {
        const created = await adminClient.exports.create(params)
        const finished = await pollUntilDone(created.id)
        await downloadExportFile(finished, token)
        toast.success('Export downloaded', { id: toastId })
        return finished
      } catch (err) {
        if (err instanceof ExportTimeoutError) {
          toast.info("Still processing — we'll email you a link when it's ready.", {
            id: toastId,
          })
        } else {
          toast.error(`Export failed: ${(err as Error).message}`, { id: toastId })
        }
        throw err
      }
    },
  })
}

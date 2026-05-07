import type { Export, ExportCreateParams } from '@spree/admin-sdk'
import { useMutation } from '@tanstack/react-query'
import { toast } from 'sonner'
import { adminClient } from '@/client'
import { useAuth } from '@/hooks/use-auth'

const POLL_INTERVAL_MS = 2000
const POLL_TIMEOUT_MS = 5 * 60 * 1000 // 5 minutes — falls back to email-link.

const baseUrl = import.meta.env.VITE_SPREE_API_URL || ''

/**
 * Resolve `download_url` (a server path like `/api/v3/admin/exports/exp_xxx/download`)
 * to an absolute URL that includes the API base, matching how the SDK builds
 * its own request URLs. Cross-origin (`VITE_SPREE_API_URL` set) and
 * same-origin (default) topologies both work.
 */
function resolveDownloadUrl(path: string): string {
  if (/^https?:\/\//.test(path)) return path
  return `${baseUrl}${path}`
}

/**
 * Fetch the CSV through the API (sending JWT), then drive the browser
 * download via a Blob + synthetic anchor click. We can't just point
 * `window.location` at `download_url` because the JWT lives in memory and
 * isn't sent on a top-level navigation.
 */
async function downloadExportFile(exp: Export, token: string | null): Promise<void> {
  if (!exp.download_url) throw new Error('Export has no download_url')

  const url = resolveDownloadUrl(exp.download_url)
  const response = await fetch(url, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    credentials: 'include',
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

async function pollUntilDone(id: string, signal: AbortSignal): Promise<Export> {
  const deadline = Date.now() + POLL_TIMEOUT_MS

  while (Date.now() < deadline) {
    if (signal.aborted) throw new DOMException('Aborted', 'AbortError')

    const exp = await adminClient.exports.get(id)
    if (exp.done) return exp

    await new Promise<void>((resolve, reject) => {
      const timer = setTimeout(resolve, POLL_INTERVAL_MS)
      signal.addEventListener(
        'abort',
        () => {
          clearTimeout(timer)
          reject(new DOMException('Aborted', 'AbortError'))
        },
        { once: true },
      )
    })
  }

  throw new Error('TIMEOUT')
}

/**
 * Queue a CSV export and drive it to completion: create → poll → download.
 *
 *   const exportProducts = useExport()
 *   exportProducts.mutate({ type: 'Spree::Exports::Products', search_params })
 *
 * Polls every 2s for up to 5 minutes. On success, fetches the file with the
 * caller's JWT and triggers a browser download. If polling times out we
 * surface a toast pointing at the email link (`Spree::ExportMailer.export_done`
 * already covers that path server-side, so there's no work to recover here).
 */
export function useExport() {
  const { token } = useAuth()

  return useMutation({
    mutationFn: async (params: ExportCreateParams) => {
      toast.loading('Preparing export…', { id: 'export-progress' })

      const created = await adminClient.exports.create(params)
      const controller = new AbortController()
      const finished = await pollUntilDone(created.id, controller.signal)
      await downloadExportFile(finished, token)
      return finished
    },
    onSuccess: () => {
      toast.success('Export downloaded', { id: 'export-progress' })
    },
    onError: (err: Error) => {
      if (err.message === 'TIMEOUT') {
        toast.info("Still processing — we'll email you a link when it's ready.", {
          id: 'export-progress',
        })
      } else {
        toast.error(`Export failed: ${err.message}`, { id: 'export-progress' })
      }
    },
  })
}

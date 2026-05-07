import type { Export, ExportCreateParams } from '@spree/admin-sdk'
import { useMutation } from '@tanstack/react-query'
import { toast } from 'sonner'
import { adminClient } from '@/client'
import { useAuth } from '@/hooks/use-auth'

const POLL_INTERVAL_MS = 2000
const POLL_TIMEOUT_MS = 5 * 60 * 1000
const TOAST_ID = 'export-progress'
const API_BASE_URL = import.meta.env.VITE_SPREE_API_URL || ''

class ExportTimeoutError extends Error {
  constructor() {
    super('Export timed out')
    this.name = 'ExportTimeoutError'
  }
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

  const url = /^https?:\/\//.test(exp.download_url)
    ? exp.download_url
    : `${API_BASE_URL}${exp.download_url}`

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

/**
 * Queue a CSV export and drive it to completion: create → poll → download.
 * On poll timeout, falls back to the email-link path —
 * `Spree::ExportMailer.export_done` already covers that server-side.
 */
export function useExport() {
  const { token } = useAuth()

  return useMutation({
    mutationFn: async (params: ExportCreateParams) => {
      toast.loading('Preparing export…', { id: TOAST_ID })

      const created = await adminClient.exports.create(params)
      const finished = await pollUntilDone(created.id)
      await downloadExportFile(finished, token)
      return finished
    },
    onSuccess: () => {
      toast.success('Export downloaded', { id: TOAST_ID })
    },
    onError: (err: Error) => {
      if (err instanceof ExportTimeoutError) {
        toast.info("Still processing — we'll email you a link when it's ready.", {
          id: TOAST_ID,
        })
      } else {
        toast.error(`Export failed: ${err.message}`, { id: TOAST_ID })
      }
    },
  })
}

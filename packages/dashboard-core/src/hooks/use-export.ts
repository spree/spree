import type { Export, ExportCreateParams } from '@spree/admin-sdk'
import { toastManager } from '@spree/dashboard-ui'
import { useMutation } from '@tanstack/react-query'
import { adminClient } from '../client'
import { downloadFromApi } from '../lib/download'
import { i18n } from '../lib/i18n'
import { useAuth } from './use-auth'

const POLL_INTERVAL_MS = 2000
const POLL_TIMEOUT_MS = 5 * 60 * 1000

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

async function downloadExportFile(exp: Export, token: string | null): Promise<void> {
  if (!exp.download_url) throw new Error('Export has no download_url')

  await downloadFromApi(token, exp.download_url, exp.filename ?? 'export.csv')
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
      toastManager.add({
        type: 'loading',
        title: i18n.t('admin.components.export_button.preparing'),
        id: toastId,
      })

      try {
        const created = await adminClient.exports.create(params)
        const finished = await pollUntilDone(created.id)
        await downloadExportFile(finished, token)
        toastManager.add({
          type: 'success',
          title: i18n.t('admin.components.export_button.downloaded'),
          id: toastId,
        })
        return finished
      } catch (err) {
        if (err instanceof ExportTimeoutError) {
          toastManager.add({
            type: 'info',
            title: i18n.t('admin.components.export_button.email_fallback'),
            id: toastId,
          })
        } else {
          toastManager.add({
            type: 'error',
            title: i18n.t('admin.components.export_button.failed', {
              message: err instanceof Error ? err.message : String(err),
            }),
            id: toastId,
          })
        }
        throw err
      }
    },
  })
}

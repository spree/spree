import { toastManager } from '@spree/dashboard-ui'
import { useMutation } from '@tanstack/react-query'
import { getApiClient, type PanelExport, type PanelExportCreateParams } from '../api-client'
import { downloadFromApi } from '../lib/download'
import { i18n } from '../lib/i18n'
import { useAuth } from './use-auth'

/**
 * The registered client's export methods.
 *
 * Throws rather than returning undefined: reaching here means a panel rendered
 * the export dialog without registering the methods behind it, and every call
 * would otherwise fail further away with a less useful message.
 */
function exportsApi() {
  const api = getApiClient().exports

  if (!api) {
    throw new Error(
      '@spree/dashboard-core: this panel registered no `exports` on its API client, so it ' +
        'cannot queue an export. Register one, or do not render <ExportButton>.',
    )
  }

  return api
}

const POLL_INTERVAL_MS = 2000
const POLL_TIMEOUT_MS = 5 * 60 * 1000

class ExportTimeoutError extends Error {
  constructor() {
    super('Export timed out')
    this.name = 'ExportTimeoutError'
  }
}

async function pollUntilDone(id: string): Promise<PanelExport> {
  const deadline = Date.now() + POLL_TIMEOUT_MS

  while (Date.now() < deadline) {
    const exp = await exportsApi().get(id)
    if (exp.done) return exp
    await new Promise<void>((resolve) => setTimeout(resolve, POLL_INTERVAL_MS))
  }

  throw new ExportTimeoutError()
}

async function downloadExportFile(exp: PanelExport, token: string | null): Promise<void> {
  if (!exp.download_url) throw new Error('Export has no download_url')

  await downloadFromApi(
    token,
    exp.download_url,
    exp.filename ?? 'export.csv',
    getApiClient().downloadHeaders?.() ?? {},
  )
}

/**
 * Queue a CSV export and drive it to completion: create → poll → download.
 * On poll timeout, falls back to the email-link path —
 * `Spree::ExportMailer.export_done` already covers that server-side.
 */
export function useExport() {
  const { token } = useAuth()

  return useMutation({
    mutationFn: async (params: PanelExportCreateParams) => {
      // Per-invocation id so concurrent exports don't collide on a single
      // sticky toast.
      const toastId = `export-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`
      toastManager.add({
        type: 'loading',
        title: i18n.t('admin.components.export_button.preparing'),
        id: toastId,
      })

      try {
        const created = await exportsApi().create(params)
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

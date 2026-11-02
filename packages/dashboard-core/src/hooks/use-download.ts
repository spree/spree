import { toastManager } from '@spree/dashboard-ui'
import { getApiClient } from '../api-client'
import { downloadFromApi } from '../lib/download'
import { i18n } from '../lib/i18n'
import { useAuth } from './use-auth'

/**
 * Downloads a private file the API streams — an invoice, an order document —
 * with the signed-in user's credentials and the panel's tenant headers.
 */
export function useDownload() {
  const { token } = useAuth()

  return (url: string | null | undefined, filename: string | null | undefined) => {
    if (!url) return
    downloadFromApi(
      token,
      url,
      filename ?? 'document',
      getApiClient().downloadHeaders?.() ?? {},
    ).catch(() =>
      toastManager.add({ type: 'error', title: i18n.t('admin.errors.download_failed') }),
    )
  }
}

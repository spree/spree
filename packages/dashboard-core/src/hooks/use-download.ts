import { getApiClient } from '../api-client'
import { downloadFromApi } from '../lib/download'
import { useAuth } from './use-auth'

/**
 * Downloads a private file the API streams — an invoice, an order document —
 * with the signed-in user's credentials and the panel's tenant headers.
 */
export function useDownload() {
  const { token } = useAuth()

  return (url: string | null | undefined, filename: string | null | undefined) => {
    if (!url) return
    void downloadFromApi(
      token,
      url,
      filename ?? 'document',
      getApiClient().downloadHeaders?.() ?? {},
    )
  }
}

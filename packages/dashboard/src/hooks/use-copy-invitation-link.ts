import { toastManager, useCopyToClipboard } from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'

/**
 * Copies an invitation's acceptance link and says how it went. `fetchLink`
 * reads the link on demand, so listings never carry the token.
 */
export function useCopyInvitationLink(
  fetchLink: (id: string) => Promise<{ acceptance_url: string }>,
) {
  const { t } = useTranslation()
  const { copy } = useCopyToClipboard()

  return async function copyInvitationLink(id: string) {
    try {
      const { acceptance_url } = await fetchLink(id)
      // Path-only when no app origin is configured; resolve against the SPA's origin.
      const url = acceptance_url.startsWith('/')
        ? `${window.location.origin}${acceptance_url}`
        : acceptance_url
      if (!(await copy(url))) {
        toastManager.add({ type: 'error', title: t('admin.staff.errors.failed_to_copy_link') })
        return
      }
      toastManager.add({ type: 'success', title: t('admin.staff.actions.invitation_link_copied') })
    } catch (err) {
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('admin.staff.errors.failed_to_copy_link'),
      })
    }
  }
}

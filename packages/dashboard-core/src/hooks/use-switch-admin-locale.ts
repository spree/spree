import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { adminClient } from '../client'
import { i18n, switchLocale } from '../lib/i18n'
import { useAuth } from './use-auth'

/**
 * Returns a function that switches the admin UI language and makes it stick.
 *
 * Switching the UI language is a three-step operation that every entry point
 * (top-bar switcher, profile form, store settings) must perform identically:
 *
 *  1. Persist `selected_locale` to the ACCOUNT (`PATCH /me`) — not just
 *     localStorage. The auth provider treats the account's `selected_locale`
 *     as the cross-device source of truth and reverts a localStorage-only
 *     switch on the next session bootstrap.
 *  2. Mirror the change into the auth context so the in-memory user (top-bar,
 *     etc.) reflects it immediately instead of waiting for the next refresh.
 *  3. `switchLocale` persists the choice and reloads so every module-load
 *     `i18n.t(...)` label re-resolves in the new language.
 *
 * A failed PATCH leaves localStorage and the page untouched (no desync) and
 * surfaces an error toast. A no-op when the language is already active.
 *
 * @returns an async `switchAdminLocale(code)` performing the full sequence
 */
export function useSwitchAdminLocale() {
  const { t } = useTranslation()
  const { updateUser } = useAuth()

  return async (code: string): Promise<void> => {
    if (code === i18n.language) return
    try {
      const { user } = await adminClient.me.update({ selected_locale: code })
      updateUser(user)
      switchLocale(code)
    } catch {
      toast.error(t('admin.account.language.update_failed'))
    }
  }
}

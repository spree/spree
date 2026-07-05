import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { adminClient } from '../client'
import { i18n, markGenuineLocaleChoice, switchLocale } from '../lib/i18n'
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
 * surfaces an error toast. Fully a no-op only when the account ALREADY records
 * `code` and the UI is already displaying it — otherwise the account is brought
 * in sync even if the UI happens to match (e.g. the language was applied via the
 * store-default fallback, which writes localStorage but leaves the account
 * `selected_locale` null), and the page reloads only when the displayed language
 * actually changes.
 *
 * @returns an async `switchAdminLocale(code)` performing the full sequence
 */
export function useSwitchAdminLocale() {
  const { t } = useTranslation()
  const { user, updateUser } = useAuth()

  return async (code: string): Promise<void> => {
    // Already adopted on the account AND on screen — nothing to do.
    if (code === user?.selected_locale && code === i18n.language) return
    try {
      const { user: updated } = await adminClient.me.update({ selected_locale: code })
      updateUser(updated)
      if (code !== i18n.language) {
        // Displayed language changes — persist the genuine choice + reload.
        switchLocale(code)
      } else {
        // Already on screen: no reload, but still record it as a GENUINE choice
        // (clearing any store-default auto-marker) so a later store switch can't
        // override what the admin explicitly picked.
        markGenuineLocaleChoice(code)
      }
    } catch {
      toast.error(t('admin.account.language.update_failed'))
    }
  }
}

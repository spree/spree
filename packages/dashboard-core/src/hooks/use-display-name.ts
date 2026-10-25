import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'

export { intlDisplayName } from '@spree/core'

/**
 * Hook returning a memoized `code -> name` resolver for one `Intl.DisplayNames`
 * type (`currency`, `language`, `region`, …), localized to the **admin UI
 * language** (`i18n.language`) — NOT the store's content locale — so names
 * match the rest of the dashboard chrome. Returns `undefined` on a miss; the
 * caller supplies the fallback (e.g. `?? code`).
 */
export function useDisplayName(type: Intl.DisplayNamesType) {
  const { i18n: instance } = useTranslation()
  const locale = instance.language
  return useMemo(() => {
    let formatter: Intl.DisplayNames | undefined
    try {
      formatter = new Intl.DisplayNames([locale, 'en'], { type })
    } catch {
      formatter = undefined
    }
    // `of` throws a RangeError for a malformed code (a legacy `english`), so
    // such a code reads as unnamed rather than breaking the page.
    return (code: string) => {
      try {
        return formatter?.of(code)
      } catch {
        return undefined
      }
    }
  }, [locale, type])
}

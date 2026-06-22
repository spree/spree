import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * Resolves a code to its display name via `Intl.DisplayNames`, localized to a
 * given UI language. Returns `undefined` when the runtime lacks coverage so
 * callers can apply their own fallback (the API name, the raw code, etc.).
 *
 * Standalone (non-hook) variant for module-level use outside React.
 */
export function intlDisplayName(
  type: Intl.DisplayNamesType,
  locale: string,
  code: string,
): string | undefined {
  try {
    return new Intl.DisplayNames([locale, 'en'], { type }).of(code)
  } catch {
    return undefined
  }
}

/**
 * Hook returning a memoized `code -> name` resolver for one `Intl.DisplayNames`
 * type (`currency`, `language`, `region`, …), localized to the **admin UI
 * language** (`i18n.language`) — NOT the store's content locale — so names
 * match the rest of the dashboard chrome. Returns `undefined` on a miss; the
 * caller supplies the fallback (e.g. `?? code`, `?? country.name`).
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
    return (code: string) => formatter?.of(code)
  }, [locale, type])
}

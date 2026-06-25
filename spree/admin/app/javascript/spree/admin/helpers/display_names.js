/** Mirrors the React dashboard's `CODE — Localized Name` format. */
export function formatCodeName(code, name) {
  const upper = code.toUpperCase()
  if (!name || name.toUpperCase() === upper) return upper
  return `${upper} — ${name}`
}

/** Resolve a code via Intl.DisplayNames in the admin UI language. */
export function intlDisplayName(type, code, locale) {
  if (!code) return undefined

  try {
    return new Intl.DisplayNames([locale, 'en'], { type }).of(code)
  } catch {
    return undefined
  }
}

export function adminUiLocale() {
  return document.documentElement.lang || 'en'
}

/** Rewrite <option> labels using Intl.DisplayNames before Tom Select init. */
export function localizeSelectOptions(select, type, locale = adminUiLocale()) {
  for (const option of select.options) {
    if (!option.value) continue

    const name = intlDisplayName(type, option.value, locale)
    if (name) option.textContent = formatCodeName(option.value, name)
  }
}

/** Mirrors the React dashboard's `CODE — Localized Name` format. */
export function formatCodeName(code, name) {
  const upper = code.toUpperCase()
  if (!name || name.toUpperCase() === upper) return upper
  return `${upper} — ${name}`
}

// Intl.DisplayNames construction is the expensive part (locale resolution +
// table setup); .of() is cheap. Cache one formatter per (type, locale) so
// localizing a large select doesn't rebuild it for every option.
const formatterCache = new Map()

function displayNameFormatter(type, locale) {
  const key = `${type}:${locale}`
  if (formatterCache.has(key)) return formatterCache.get(key)

  let formatter
  try {
    formatter = new Intl.DisplayNames([locale, 'en'], { type })
  } catch {
    formatter = null
  }
  formatterCache.set(key, formatter)
  return formatter
}

/** Resolve a code via Intl.DisplayNames in the admin UI language. */
export function intlDisplayName(type, code, locale) {
  if (!code) return undefined

  const formatter = displayNameFormatter(type, locale)
  if (!formatter) return undefined

  try {
    return formatter.of(code)
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

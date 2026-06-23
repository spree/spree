import * as dateFnsLocales from 'date-fns/locale'
import i18n from 'i18next'
import type { Locale } from 'react-day-picker'

// date-fns ships ~96 locales; we resolve one by the active i18n language code
// instead of maintaining a hand-kept map (which silently drifted to English
// whenever a new UI bundle shipped without a matching entry here). The whole
// locale set is imported, so any language a translation bundle adds is covered
// with no edit to this file.
const LOCALES = dateFnsLocales as unknown as Record<string, Locale>

// i18next codes are BCP-47-ish (`en`, `pt-BR`, `zh-CN`); date-fns export names
// are camelCase (`enUS`, `ptBR`, `zhCN`). Convert `-x` → `X` to match.
function dateFnsKey(code: string): string {
  return code.replace(/-(\w)/g, (_, c: string) => c.toUpperCase())
}

// Resolve a date-fns Locale for an i18n language code. Tries the exact code,
// then the base language (`pt-BR` → `pt`), and finally falls back to `enUS`.
// `en` has no bare date-fns export, so it resolves through the fallback.
function resolveDateLocale(code: string): Locale {
  const base = code.split('-')[0]
  return LOCALES[dateFnsKey(code)] ?? LOCALES[base] ?? LOCALES.enUS
}

/** date-fns locale for the active admin UI language (falls back to English). */
export function activeDateLocale(): Locale {
  return resolveDateLocale(i18n.language ?? 'en')
}

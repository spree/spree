import { de, enUS, fr, pl } from 'date-fns/locale'
import i18n from 'i18next'
import type { Locale } from 'react-day-picker'

// Maps the admin UI language (i18next) to a date-fns locale so calendars and
// date formatting render month/weekday names in the chosen language. Falls
// back to English. Extend this map whenever a new UI locale bundle ships.
const DATE_LOCALES: Record<string, Locale> = {
  en: enUS,
  de,
  fr,
  pl,
}

/** date-fns locale for the active admin UI language (falls back to English). */
export function activeDateLocale(): Locale {
  const lang = i18n.language ?? 'en'
  return DATE_LOCALES[lang] ?? DATE_LOCALES[lang.split('-')[0]] ?? enUS
}

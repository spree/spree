import type { TFunction } from 'i18next'

/** The merchant-facing name of a template, from its key. */
export function emailTemplateName(t: TFunction, key: string): string {
  const [folder, file] = key.split('/').slice(-2)
  const fallback = file.replace(/_/g, ' ').replace(/^\w/, (letter) => letter.toUpperCase())
  return t(`admin.email_templates.names.${folder}_${file}`, { defaultValue: fallback })
}

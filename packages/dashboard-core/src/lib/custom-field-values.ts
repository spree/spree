import i18n from 'i18next'
import { formatStoreDate, formatStoreDateTime } from './formatters'

/** No value to store: the API removes the field rather than saving it. */
export function isBlankCustomFieldValue(value: unknown) {
  return (
    value == null ||
    (typeof value === 'string' && value.trim() === '') ||
    (Array.isArray(value) && value.length === 0)
  )
}

/**
 * A stored custom field value as read-only text, in the store's time zone.
 * `choiceLabel` names a chosen value; without the field's definition at hand,
 * the value shows as stored.
 */
export function formatCustomFieldValue(
  value: unknown,
  fieldType: string,
  timezone: string,
  choiceLabel: (choice: unknown) => string = String,
): string {
  const empty = i18n.t('admin.common.empty_value')
  if (isBlankCustomFieldValue(value)) return empty

  switch (fieldType) {
    case 'boolean':
      return i18n.t(value ? 'admin.common.yes' : 'admin.common.no')
    case 'rich_text': {
      // Plain-text preview of HTML. DOMParser handles nested/malformed tags
      // correctly — a single-pass regex strip can leak tags via patterns like
      // `<scr<script>ipt>` (CodeQL js/incomplete-multi-character-sanitization).
      const text = new DOMParser().parseFromString(String(value), 'text/html').body.textContent
      return text?.trim() || empty
    }
    case 'json':
      return typeof value === 'string' ? value : JSON.stringify(value)
    case 'date':
      // A calendar day: format it as written, never shifted into a zone.
      return formatStoreDate(`${value}T00:00:00Z`, 'UTC')
    case 'date_time':
      return formatStoreDateTime(String(value), timezone)
    case 'choice':
      return (Array.isArray(value) ? value : [value]).map(choiceLabel).join(', ')
    default:
      return String(value)
  }
}

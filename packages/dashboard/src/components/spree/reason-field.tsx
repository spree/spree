import {
  Field,
  FieldLabel,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'
import { type ReasonKind, useReasons } from '../../hooks/use-reasons'

/**
 * Reason dropdown, shared by every surface that records why something
 * happened. Optional by design — the API accepts a record without a reason,
 * and a merchant mid-return should not be blocked because nobody has curated
 * the list yet. Inactive reasons are excluded so retired vocabulary stops
 * appearing on new records.
 *
 * With no `emptyOptionLabel` the field hides itself when the vocabulary is
 * empty, which suits a form that has other fields to fall back on. Passing one
 * keeps the field visible with an explicit "none" choice at the top, for a
 * surface where the reason is the point and its absence has to be sayable.
 */
export function ReasonField({
  kind,
  value,
  onChange,
  label,
  emptyOptionLabel,
}: {
  kind: ReasonKind
  value: string
  onChange: (value: string) => void
  label?: string
  emptyOptionLabel?: string
}) {
  const { t } = useTranslation()
  const { data } = useReasons(kind)

  // Filtered in memory rather than through the query so this shares the
  // settings page's cache entry — the lists are a handful of rows.
  const reasons = (data?.data ?? []).filter((reason) => reason.active)
  if (reasons.length === 0 && emptyOptionLabel === undefined) return null

  // Base UI's <Select> needs `items` to resolve the trigger label; without it
  // the closed trigger renders the raw id (see CLAUDE.md).
  const options = [
    ...(emptyOptionLabel === undefined ? [] : [{ value: '', label: emptyOptionLabel }]),
    ...reasons.map((reason) => ({ value: reason.id, label: reason.name })),
  ]

  return (
    <Field>
      <FieldLabel htmlFor={`reason-${kind}`}>
        {label ?? t('admin.pages.orders.detail.returns.reason')}
      </FieldLabel>
      <Select items={options} value={value} onValueChange={(next) => onChange(next ?? '')}>
        <SelectTrigger id={`reason-${kind}`}>
          {/* An explicit empty choice IS the label for "none", so it must show
              rather than fall through to the placeholder Base UI renders for
              an unset value. */}
          <SelectValue placeholder={emptyOptionLabel ?? t('admin.common.select_placeholder')} />
        </SelectTrigger>
        <SelectContent>
          {options.map((option) => (
            <SelectItem key={option.value} value={option.value}>
              {option.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </Field>
  )
}

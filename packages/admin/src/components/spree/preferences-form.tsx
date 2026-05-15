import type { PreferenceField as PreferenceFieldDef } from '@spree/admin-sdk'
import { PlusIcon, TrashIcon } from 'lucide-react'
import { useId, useMemo, useState } from 'react'
import { CurrencySelect } from '@/components/spree/currency-select'
import { SecretInput } from '@/components/spree/secret-input'
import { Button } from '@/components/ui/button'
import { Field, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { Switch } from '@/components/ui/switch'
import { Textarea } from '@/components/ui/textarea'

/**
 * Hydrates a `preferences` hash with each field's default. Used to seed
 * create-mode forms when the user picks a provider/calculator so the
 * `<PreferencesForm>` shows sensible starting values instead of blanks.
 *
 * `:password` fields are always skipped — the server returns their
 * defaults as `null`, and even when it doesn't, autofilling a password
 * field is hostile UX.
 */
export function defaultPreferences(schema: PreferenceFieldDef[]): Record<string, unknown> {
  const out: Record<string, unknown> = {}
  for (const field of schema) {
    if (field.type === 'password') continue
    if (field.default !== null && field.default !== undefined) out[field.key] = field.default
  }
  return out
}

interface PreferencesFormProps {
  schema: PreferenceFieldDef[]
  values: Record<string, unknown>
  onChange: (next: Record<string, unknown>) => void
  /** When true, replaces sensitive `password`-typed fields with a stub label. */
  redactPasswords?: boolean
  /** Optional human-readable name overrides keyed by preference key. */
  labelOverrides?: Record<string, string>
}

/**
 * Renders a generic configuration form from a `preference_schema` payload.
 * Used by the Payment Methods edit sheet and the Promotion editor's action
 * and rule cards — anywhere we let admins tune a STI subclass's settings
 * without hard-coding a per-subclass form.
 *
 * The schema itself is the source of truth; this component intentionally
 * stays "dumb" — server-side validation surfaces errors back via the
 * mutation hook's error handling. Booleans are switches, strings are
 * inputs, integers/decimals get number inputs, and unknown types fall
 * back to a plain text input.
 */
export function PreferencesForm({
  schema,
  values,
  onChange,
  redactPasswords = false,
  labelOverrides,
}: PreferencesFormProps) {
  if (!schema?.length) return null

  function setValue(key: string, value: unknown) {
    if (Object.is(values[key], value)) return
    onChange({ ...values, [key]: value })
  }

  return (
    <FieldGroup>
      {schema.map((field) => (
        <PreferenceField
          key={field.key}
          field={field}
          value={values[field.key] ?? field.default}
          label={labelOverrides?.[field.key]}
          onChange={(v) => setValue(field.key, v)}
          redactPasswords={redactPasswords}
        />
      ))}
    </FieldGroup>
  )
}

interface PreferenceFieldProps {
  field: PreferenceFieldDef
  value: unknown
  label?: string
  onChange: (value: unknown) => void
  redactPasswords?: boolean
}

export function PreferenceField({
  field,
  value,
  label,
  onChange,
  redactPasswords,
}: PreferenceFieldProps) {
  const id = `preference-${field.key}`
  const displayLabel = label ?? humanizeKey(field.key)

  // Currency-typed preferences (`currency`, `default_currency`,
  // `display_currency`, …) get the store's CurrencySelect — same
  // localized `CODE — Full Name` rendering as the rest of admin.
  if (isCurrencyKey(field.key)) {
    return (
      <Field>
        <FieldLabel htmlFor={id}>{displayLabel}</FieldLabel>
        <CurrencySelect id={id} value={(value as string) || undefined} onChange={onChange} />
      </Field>
    )
  }

  // `tiers` preference (Spree::Calculator::TieredPercent /
  // TieredFlatRate) — a Hash<threshold, value> that the default
  // hash-as-text input would render as `[object Object]`. Render a row
  // editor so the merchant can add tier breakpoints directly.
  if (field.key === 'tiers') {
    return <TiersEditor value={value} onChange={onChange} />
  }

  switch (field.type) {
    case 'boolean':
      return (
        <Field>
          <div className="flex items-start justify-between gap-4">
            <FieldLabel htmlFor={id} className="cursor-pointer">
              {displayLabel}
            </FieldLabel>
            <Switch id={id} checked={!!value} onCheckedChange={(checked) => onChange(checked)} />
          </div>
        </Field>
      )

    case 'text':
      return (
        <Field>
          <FieldLabel htmlFor={id}>{displayLabel}</FieldLabel>
          <Textarea
            id={id}
            rows={4}
            value={(value as string) ?? ''}
            onChange={(e) => onChange(e.target.value)}
          />
        </Field>
      )

    case 'integer':
    case 'decimal':
      return (
        <Field>
          <FieldLabel htmlFor={id}>{displayLabel}</FieldLabel>
          <Input
            id={id}
            type="number"
            step={field.type === 'integer' ? 1 : 'any'}
            value={value === null || value === undefined ? '' : String(value)}
            onChange={(e) => {
              const raw = e.target.value
              if (raw === '') return onChange(null)
              const parsed = field.type === 'integer' ? parseInt(raw, 10) : parseFloat(raw)
              onChange(Number.isNaN(parsed) ? null : parsed)
            }}
          />
        </Field>
      )

    case 'array':
      // A generic "comma-separated list" works for the common case where
      // arrays hold IDs or short tokens. Subclasses with structured
      // arrays (option values, eligible products) ship with custom
      // editors and don't reach here.
      return (
        <Field>
          <FieldLabel htmlFor={id}>{displayLabel}</FieldLabel>
          <Input
            id={id}
            value={Array.isArray(value) ? value.join(', ') : ((value as string) ?? '')}
            placeholder="comma-separated"
            onChange={(e) =>
              onChange(
                e.target.value
                  .split(',')
                  .map((s) => s.trim())
                  .filter(Boolean),
              )
            }
          />
          <span className="text-xs text-muted-foreground">Separate values with commas.</span>
        </Field>
      )

    case 'password':
      return (
        <SecretInput
          id={id}
          label={displayLabel}
          value={value}
          onChange={onChange}
          redactWhenMasked={!!redactPasswords}
        />
      )

    default:
      return (
        <Field>
          <FieldLabel htmlFor={id}>{displayLabel}</FieldLabel>
          <Input
            id={id}
            value={(value as string) ?? ''}
            onChange={(e) => onChange(e.target.value)}
          />
        </Field>
      )
  }
}

function humanizeKey(key: string): string {
  return key
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ')
}

function isCurrencyKey(key: string): boolean {
  return key === 'currency' || key.endsWith('_currency')
}

interface TierRowState {
  /** Stable across edits — used for React keys so input focus survives reorder. */
  uid: string
  threshold: string
  value: string
}

/**
 * Editor for `Spree::Calculator::TieredPercent` / `TieredFlatRate`
 * preferences. The underlying shape is `Hash<threshold, value>` — orders
 * at or above `threshold` get `value` (% or $ depending on the
 * calculator).
 *
 * Owns its row list locally so the user can add an empty row and fill
 * it in afterwards — projecting to the hash on every change would drop
 * empty-threshold rows the moment they're added. Empty rows are
 * filtered when projecting to the parent's hash value.
 */
function TiersEditor({
  value,
  onChange,
}: {
  value: unknown
  onChange: (next: Record<string, number>) => void
}) {
  const idPrefix = useId()
  // Seed once from the initial value. Subsequent rerenders driven by
  // parent state (e.g. another preference field changes) keep our row
  // list intact so the user doesn't lose their in-progress empty rows.
  // biome-ignore lint/correctness/useExhaustiveDependencies: intentional one-time seed
  const initialRows = useMemo(() => parseTiers(value, idPrefix), [])
  const [rows, setRows] = useState<TierRowState[]>(initialRows)

  function commit(next: TierRowState[]) {
    setRows(next)
    const out: Record<string, number> = {}
    for (const row of next) {
      const t = row.threshold.trim()
      if (!t) continue
      const parsed = Number(row.value)
      out[t] = Number.isFinite(parsed) ? parsed : 0
    }
    onChange(out)
  }

  function updateRow(uid: string, patch: Partial<Pick<TierRowState, 'threshold' | 'value'>>) {
    commit(rows.map((row) => (row.uid === uid ? { ...row, ...patch } : row)))
  }

  function addRow() {
    commit([
      ...rows,
      { uid: `${idPrefix}-${rows.length + 1}-${Date.now()}`, threshold: '', value: '' },
    ])
  }

  function removeRow(uid: string) {
    commit(rows.filter((row) => row.uid !== uid))
  }

  return (
    <Field>
      <FieldLabel>Tiers</FieldLabel>
      <div className="space-y-2">
        {rows.length === 0 ? (
          <p className="text-xs text-muted-foreground">
            No tiers yet. The base rate applies until you add a tier.
          </p>
        ) : (
          <div className="grid grid-cols-[1fr_1fr_auto] gap-2">
            <span className="text-xs font-medium text-muted-foreground">Order total ≥</span>
            <span className="text-xs font-medium text-muted-foreground">Discount</span>
            <span />
            {rows.map((row) => (
              <TierRow
                key={row.uid}
                row={row}
                onChange={(patch) => updateRow(row.uid, patch)}
                onRemove={() => removeRow(row.uid)}
              />
            ))}
          </div>
        )}
        <Button type="button" variant="outline" size="sm" onClick={addRow}>
          <PlusIcon className="size-4" />
          Add tier
        </Button>
      </div>
    </Field>
  )
}

function TierRow({
  row,
  onChange,
  onRemove,
}: {
  row: TierRowState
  onChange: (patch: Partial<Pick<TierRowState, 'threshold' | 'value'>>) => void
  onRemove: () => void
}) {
  return (
    <>
      <Input
        type="number"
        step="any"
        min={0}
        value={row.threshold}
        placeholder="100"
        onChange={(e) => onChange({ threshold: e.target.value })}
      />
      <Input
        type="number"
        step="any"
        min={0}
        value={row.value}
        placeholder="10"
        onChange={(e) => onChange({ value: e.target.value })}
      />
      <Button
        type="button"
        size="icon-sm"
        variant="ghost"
        onClick={onRemove}
        aria-label="Remove tier"
        className="text-destructive hover:bg-destructive/10 hover:text-destructive"
      >
        <TrashIcon className="size-4" />
      </Button>
    </>
  )
}

/**
 * Normalize whatever shape the server sent — typically `Hash<number,
 * number>` but JSON serialization stringifies the keys, so we may
 * receive `{ "100": 10 }` or `{ 100: 10 }`. Either form converts to
 * `TierRowState[]` for editor state.
 */
function parseTiers(value: unknown, idPrefix: string): TierRowState[] {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return []
  return Object.entries(value as Record<string, unknown>)
    .map(([threshold, v], i) => ({
      uid: `${idPrefix}-seed-${i}`,
      threshold: String(threshold),
      value: v === null || v === undefined ? '' : String(v),
    }))
    .sort((a, b) => Number(a.threshold) - Number(b.threshold))
}

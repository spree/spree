import {
  compareMoney,
  isDecimalString,
  type PreferencePropertySchema,
  type PreferenceSchema,
} from '@spree/admin-sdk'
import {
  Button,
  Field,
  FieldDescription,
  FieldGroup,
  FieldLabel,
  Input,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  InputGroupText,
  SecretInput,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Switch,
  Textarea,
} from '@spree/dashboard-ui'
import { PlusIcon, TrashIcon } from '@spree/dashboard-ui/icons'
import { useId, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useMoneyLocale } from '../hooks/use-money-locale'
import { currencyParts } from '../lib/currency-parts'
import { CountryCombobox, CountryMultiCombobox } from './country-combobox'
import { CurrencySelect } from './currency-select'
import { StoreDatePicker } from './store-date-picker'

/**
 * One setting of a {@link PreferenceSchema}, flattened into what a form
 * needs to pick its widget.
 */
export interface PreferenceFieldDef {
  key: string
  /** `string`, `text`, `password`, `boolean`, `integer`, `decimal`, `date`, `datetime`, `array`, `hash` or `object`. */
  type: string
  /** The schema's `format` (`money`, `currency`, `iso-country`, …), on the value or, for a list, on its items. */
  format?: string
  default: unknown
  choices?: string[]
  /** Whether the setting may be left empty (it reads back as null). */
  nullable: boolean
  /** The property's own JSON Schema, for widgets that need more (list items, object properties). */
  schema: PreferencePropertySchema
}

const DECIMAL_PATTERN = '^-?\\d+(\\.\\d+)?$'

function fieldType(property: PreferencePropertySchema): string {
  if (property['x-spree-secret']) return 'password'
  const type = (Array.isArray(property.type) ? property.type : [property.type]).find(
    (t) => t && t !== 'null',
  )
  if (type === 'string') {
    if (property.format === 'date') return 'date'
    if (property.format === 'date-time') return 'datetime'
    if (property.format === 'money') return 'money'
    if (property.pattern === DECIMAL_PATTERN) return 'decimal'
    if (property['x-spree-widget'] === 'textarea') return 'text'
    return 'string'
  }
  if (type === 'object') return property.properties ? 'object' : 'hash'
  return type ?? 'string'
}

/**
 * Flattens a preference schema into the fields a form renders, in the order
 * the type declares them.
 */
export function preferenceFields(
  schema: PreferenceSchema | null | undefined,
): PreferenceFieldDef[] {
  return Object.entries(schema?.properties ?? {}).map(([key, property]) => ({
    key,
    type: fieldType(property),
    format: property.format ?? property.items?.format,
    default: property.default ?? null,
    choices: property.enum?.filter((choice): choice is string => typeof choice === 'string'),
    nullable: Array.isArray(property.type) && property.type.includes('null'),
    schema: property,
  }))
}

/**
 * Hydrates a `preferences` hash with each field's default. Used to seed
 * create-mode forms when the user picks a provider/calculator so the
 * `<PreferencesForm>` shows sensible starting values instead of blanks.
 *
 * Secrets are always skipped — the schema never carries their defaults, and
 * autofilling a password field is hostile UX. `contextDefaults` fills keys
 * whose own default is absent — used by callers that know about runtime
 * context the schema can't express (e.g. the store's default currency).
 */
export function defaultPreferences(
  schema: PreferenceSchema | null | undefined,
  contextDefaults: Record<string, unknown> = {},
): Record<string, unknown> {
  const out: Record<string, unknown> = {}
  for (const field of preferenceFields(schema)) {
    if (field.type === 'password') continue
    if (field.default !== null && field.default !== undefined) {
      // A decimal default declared as a Ruby integer arrives as a JSON number,
      // and the API refuses money sent back that way.
      out[field.key] =
        (field.type === 'decimal' || field.type === 'money') && typeof field.default === 'number'
          ? String(field.default)
          : field.default
      continue
    }
    const ctx = contextDefaults[field.key]
    if (ctx !== undefined && ctx !== null && ctx !== '') out[field.key] = ctx
  }
  return out
}

interface PreferencesFormProps {
  schema: PreferenceSchema | null | undefined
  values: Record<string, unknown>
  onChange: (next: Record<string, unknown>) => void
  /** When true, replaces sensitive `password`-typed fields with a stub label. */
  redactPasswords?: boolean
  /** Optional human-readable name overrides keyed by preference key. */
  labelOverrides?: Record<string, string>
  /**
   * Currencies a currency-typed preference may be set to. Defaults to the
   * store's when a `StoreProvider` is mounted. Panels without one (the
   * marketplace seller panel) pass their own list — an unconstrained picker
   * would let a currency the store does not trade in be saved, and a
   * calculator set to one quotes no rate at all.
   */
  currencyOptions?: string[]
  /**
   * Render date/datetime pickers inline instead of in a Popover portal.
   * Set this when the form is inside a `<Sheet>` — Base UI's Popover fails
   * to mount in deeply nested portal trees, so the calendar never appears.
   */
  inlineDatePickers?: boolean
}

/**
 * Renders a generic configuration form from a type's preference schema.
 * Used by the Payment Methods edit sheet and the Promotion editor's action
 * and rule cards — anywhere we let admins tune a STI subclass's settings
 * without hard-coding a per-subclass form.
 *
 * The schema itself is the source of truth; this component intentionally
 * stays "dumb" — server-side validation surfaces errors back via the
 * mutation hook's error handling. The widget follows the schema: booleans
 * are switches, currencies and countries pickers, amounts number inputs
 * that send the exact decimal string, and anything else a text input.
 */
export function PreferencesForm({
  schema,
  values,
  onChange,
  redactPasswords = false,
  labelOverrides,
  currencyOptions,
  inlineDatePickers,
}: PreferencesFormProps) {
  const fields = useMemo(() => preferenceFields(schema), [schema])
  if (!fields.length) return null

  function setValue(key: string, value: unknown) {
    if (Object.is(values[key], value)) return
    onChange({ ...values, [key]: value })
  }

  return (
    <FieldGroup>
      {fields.map((field) => (
        <PreferenceField
          key={field.key}
          field={field}
          value={values[field.key] ?? field.default}
          label={labelOverrides?.[field.key]}
          onChange={(v) => setValue(field.key, v)}
          redactPasswords={redactPasswords}
          currencyOptions={currencyOptions}
          inlineDatePickers={inlineDatePickers}
          currency={typeof values.currency === 'string' ? values.currency : undefined}
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
  currencyOptions?: string[]
  inlineDatePickers?: boolean
  /** The currency a money preference is in, when the record names one. */
  currency?: string
}

export function PreferenceField({
  field,
  value,
  label,
  onChange,
  redactPasswords,
  currencyOptions,
  inlineDatePickers,
  currency,
}: PreferenceFieldProps) {
  const { t, i18n } = useTranslation()
  const moneyLocale = useMoneyLocale()
  const id = `preference-${field.key}`
  // Localize the field label from the preference key when no explicit
  // override is given, falling back to a humanized key for custom/extension
  // preferences that ship no translation.
  const preferenceKey = `admin.preferences.${field.key}`
  const displayLabel =
    label ?? (i18n.exists(preferenceKey) ? t(preferenceKey) : humanizeKey(field.key))
  // Optional one-line help, under the same key convention as the label. Most
  // preferences say what they are in their name; the ones that do not — a
  // customs signer, an incoterm — are unguessable without it.
  const descriptionKey = `${preferenceKey}_description`
  const description = i18n.exists(descriptionKey) ? t(descriptionKey) : undefined

  // Currencies get the store's CurrencySelect — same localized
  // `CODE — Full Name` rendering as the rest of admin.
  if (field.type === 'string' && field.format === 'currency') {
    return (
      <Field>
        <FieldLabel htmlFor={id}>{displayLabel}</FieldLabel>
        <CurrencySelect
          id={id}
          value={(value as string) ?? ''}
          onChange={onChange}
          options={currencyOptions}
        />
      </Field>
    )
  }

  if (field.type === 'string' && field.format === 'iso-country') {
    return (
      <Field>
        <FieldLabel htmlFor={id}>{displayLabel}</FieldLabel>
        <CountryCombobox id={id} value={(value as string) ?? null} onValueChange={onChange} />
      </Field>
    )
  }

  if (field.type === 'array' && field.format === 'iso-country') {
    return (
      <Field>
        <FieldLabel>{displayLabel}</FieldLabel>
        <CountryMultiCombobox
          value={Array.isArray(value) ? (value as string[]) : []}
          onValueChange={onChange}
        />
      </Field>
    )
  }

  // A tier ladder (the tiered calculators) — a list of
  // `{ threshold, value }` objects that the default array input would render
  // as `[object Object]`. Render a row editor so the merchant can add tier
  // breakpoints directly.
  const itemProperties = field.schema.items?.properties
  if (field.type === 'array' && itemProperties?.threshold && itemProperties?.value) {
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

    // A date is a picker, never a text box: an operator typing "1 Jan 2026"
    // into a field the server parses as ISO-8601 gets a validation error with
    // no hint of the format wanted. `<StoreDatePicker>` also reads the store's
    // timezone, so a date means the same day for every admin.
    case 'date':
    case 'datetime':
      return (
        <Field>
          <FieldLabel htmlFor={id}>{displayLabel}</FieldLabel>
          <StoreDatePicker
            id={id}
            value={(value as string) ?? null}
            onChange={(next) => onChange(next)}
            includeTime={field.type === 'datetime'}
            inline={inlineDatePickers}
          />
          {description && <FieldDescription>{description}</FieldDescription>}
        </Field>
      )

    case 'money':
      return (
        <Field>
          <FieldLabel htmlFor={id}>{displayLabel}</FieldLabel>
          <InputGroup>
            {currency && (
              <InputGroupAddon>
                <InputGroupText>{currencyParts(currency, moneyLocale).symbol}</InputGroupText>
              </InputGroupAddon>
            )}
            <InputGroupInput
              id={id}
              type="number"
              step="any"
              placeholder={
                field.nullable ? t('admin.components.preferences_form.unlimited') : undefined
              }
              value={value === null || value === undefined ? '' : String(value)}
              onChange={(e) => {
                const raw = e.target.value
                if (raw === '') return onChange(null)
                // The API refuses money sent as a JSON number.
                onChange(isDecimalString(raw) ? raw : null)
              }}
            />
          </InputGroup>
          {description && <FieldDescription>{description}</FieldDescription>}
        </Field>
      )

    case 'integer':
    case 'decimal':
      return (
        <Field>
          <FieldLabel htmlFor={id}>{displayLabel}</FieldLabel>
          <NumberPreferenceInput
            id={id}
            integer={field.type === 'integer'}
            nullable={!!field.nullable}
            // An empty optional field means "no limit" — surface that
            // rather than leaving it looking like a required blank.
            placeholder={
              field.nullable ? t('admin.components.preferences_form.unlimited') : undefined
            }
            value={value}
            onChange={onChange}
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
            placeholder={t('admin.components.preferences_form.comma_separated_hint')}
            onChange={(e) =>
              onChange(
                e.target.value
                  .split(',')
                  .map((s) => s.trim())
                  .filter(Boolean),
              )
            }
          />
          <span className="text-xs text-muted-foreground">
            {t('admin.components.preferences_form.comma_separated_hint')}
          </span>
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
      // A preference that declares a fixed set is a picker, not a text box:
      // the set is what the server validates against, so typing anything
      // else can only fail on save.
      if (field.choices?.length) {
        const options = field.choices.map((choice) => ({
          value: choice,
          label: i18n.exists(`${preferenceKey}_options.${choice}`)
            ? t(`${preferenceKey}_options.${choice}`)
            : humanizeKey(choice),
        }))

        return (
          <Field>
            <FieldLabel htmlFor={id}>{displayLabel}</FieldLabel>
            <Select
              items={options}
              value={(value as string) ?? ''}
              onValueChange={(next) => onChange(next ?? '')}
            >
              <SelectTrigger id={id}>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {options.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            {description && <FieldDescription>{description}</FieldDescription>}
          </Field>
        )
      }

      return (
        <Field>
          <FieldLabel htmlFor={id}>{displayLabel}</FieldLabel>
          <Input
            id={id}
            value={(value as string) ?? ''}
            onChange={(e) => onChange(e.target.value)}
          />
          {description && <FieldDescription>{description}</FieldDescription>}
        </Field>
      )
  }
}

/**
 * A number setting. Keeps what is typed locally and passes on only values the
 * server accepts: decimals as exact strings (`.5` becomes `0.5`), integers as
 * numbers, and an empty field as `null` only when the setting may be unset —
 * a required one keeps its last value until a number is typed.
 */
function NumberPreferenceInput({
  id,
  integer,
  nullable,
  placeholder,
  value,
  onChange,
}: {
  id: string
  integer: boolean
  nullable: boolean
  placeholder?: string
  value: unknown
  onChange: (value: unknown) => void
}) {
  const external = value === null || value === undefined ? '' : String(value)
  const [text, setText] = useState(external)
  const [lastExternal, setLastExternal] = useState(external)
  if (external !== lastExternal) {
    setLastExternal(external)
    setText(external)
  }

  function commit(raw: string) {
    setText(raw)
    const trimmed = raw.trim()
    if (trimmed === '') {
      if (nullable) onChange(null)
      return
    }
    const number = Number(trimmed)
    if (!Number.isFinite(number)) return
    if (integer) {
      if (Number.isInteger(number)) onChange(number)
      return
    }
    onChange(new RegExp(DECIMAL_PATTERN).test(trimmed) ? trimmed : String(number))
  }

  return (
    <Input
      id={id}
      type="number"
      step={integer ? 1 : 'any'}
      placeholder={placeholder}
      value={text}
      onChange={(e) => commit(e.target.value)}
    />
  )
}

function humanizeKey(key: string): string {
  return key
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ')
}

interface TierValue {
  threshold: string
  value: string
}

interface TierRowState {
  /** Stable across edits — used for React keys so input focus survives reorder. */
  uid: string
  threshold: string
  value: string
}

/**
 * Editor for `Spree::Calculator::TieredPercent` / `TieredFlatRate`
 * preferences. The underlying shape is a list of `{ threshold, value }`
 * objects — orders at or above `threshold` get `value` (% or $ depending
 * on the calculator).
 *
 * Owns its row list locally so the user can add an empty row and fill
 * it in afterwards — projecting to the list on every change would drop
 * empty-threshold rows the moment they're added. Empty rows are
 * filtered when projecting to the parent's value.
 */
function TiersEditor({
  value,
  onChange,
}: {
  value: unknown
  onChange: (next: TierValue[]) => void
}) {
  const { t } = useTranslation()
  const idPrefix = useId()
  // Seed once from the initial value. Subsequent rerenders driven by
  // parent state (e.g. another preference field changes) keep our row
  // list intact so the user doesn't lose their in-progress empty rows.
  // biome-ignore lint/correctness/useExhaustiveDependencies: intentional one-time seed
  const initialRows = useMemo(() => parseTiers(value, idPrefix), [])
  const [rows, setRows] = useState<TierRowState[]>(initialRows)

  function commit(next: TierRowState[]) {
    setRows(next)
    // Sent as the strings typed, so the server stores the exact decimal.
    onChange(
      next
        .filter((row) => row.threshold.trim())
        .map((row) => ({ threshold: row.threshold.trim(), value: row.value.trim() || '0' })),
    )
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
      <FieldLabel>{t('admin.components.preferences_form.tiers.label')}</FieldLabel>
      <div className="space-y-2">
        {rows.length === 0 ? (
          <p className="text-xs text-muted-foreground">
            {t('admin.components.preferences_form.tiers.empty')}
          </p>
        ) : (
          <div className="grid grid-cols-[1fr_1fr_auto] gap-2">
            <span className="text-xs font-medium text-muted-foreground">
              {t('admin.components.preferences_form.tiers.header_threshold')}
            </span>
            <span className="text-xs font-medium text-muted-foreground">
              {t('admin.components.preferences_form.tiers.header_value')}
            </span>
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
          {t('admin.components.preferences_form.tiers.add_tier')}
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
  const { t } = useTranslation()
  return (
    <>
      <Input
        type="number"
        step="any"
        min={0}
        value={row.threshold}
        placeholder="100"
        aria-label={t('admin.components.preferences_form.tiers.header_threshold')}
        onChange={(e) => onChange({ threshold: e.target.value })}
      />
      <Input
        type="number"
        step="any"
        min={0}
        value={row.value}
        placeholder="10"
        aria-label={t('admin.components.preferences_form.tiers.header_value')}
        onChange={(e) => onChange({ value: e.target.value })}
      />
      <Button
        type="button"
        size="icon-sm"
        variant="destructive-ghost"
        onClick={onRemove}
        aria-label={t('admin.components.preferences_form.tiers.remove_tier')}
      >
        <TrashIcon className="size-4" />
      </Button>
    </>
  )
}

/**
 * Converts the server's list of `{ threshold, value }` objects into
 * editor rows. A calculator saved before Spree 6.0 that the upgrade has
 * not converted yet still sends a hash keyed by threshold, so that shape
 * is read too.
 */
function parseTiers(value: unknown, idPrefix: string): TierRowState[] {
  if (!value || typeof value !== 'object') return []
  const pairs: [unknown, unknown][] = Array.isArray(value)
    ? value.map((tier) => [tier?.threshold, tier?.value])
    : Object.entries(value as Record<string, unknown>)
  return pairs
    .map(([threshold, v], i) => ({
      uid: `${idPrefix}-seed-${i}`,
      threshold: threshold === null || threshold === undefined ? '' : String(threshold),
      value: v === null || v === undefined ? '' : String(v),
    }))
    .sort((a, b) =>
      isDecimalString(a.threshold) && isDecimalString(b.threshold)
        ? compareMoney(a.threshold, b.threshold)
        : 0,
    )
}

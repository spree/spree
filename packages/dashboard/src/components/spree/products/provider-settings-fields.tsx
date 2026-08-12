import type { DigitalAssetProviderSettingField } from '@spree/admin-sdk'
import {
  Field,
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Switch,
} from '@spree/dashboard-ui'

interface Props {
  schema: DigitalAssetProviderSettingField[]
  values: Record<string, unknown>
  onChange: (values: Record<string, unknown>) => void
}

/**
 * Renders one input per provider-declared setting. The provider owns the field
 * list (its `settings_schema`), so this stays generic: a provider ships no
 * dashboard code, it just names its fields and types. Labels come straight from
 * the field key — a provider names a setting for the merchant, not for i18n.
 */
export function ProviderSettingsFields({ schema, values, onChange }: Props) {
  if (schema.length === 0) return null

  function set(key: string, value: unknown) {
    onChange({ ...values, [key]: value })
  }

  return (
    <>
      {schema.map((field) => {
        const value = values[field.key]
        const id = `provider-setting-${field.key}`

        if (field.type === 'boolean') {
          return (
            <Field key={field.key} className="flex-row items-center justify-between">
              <FieldLabel htmlFor={id}>{field.key}</FieldLabel>
              <Switch
                id={id}
                checked={Boolean(value)}
                onCheckedChange={(checked) => set(field.key, checked)}
              />
            </Field>
          )
        }

        if (field.type === 'select') {
          return (
            <Field key={field.key}>
              <FieldLabel htmlFor={id}>{field.key}</FieldLabel>
              <Select
                value={value == null ? '' : String(value)}
                onValueChange={(v) => set(field.key, v)}
              >
                <SelectTrigger id={id}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {(field.in ?? []).map((option) => (
                    <SelectItem key={option} value={option}>
                      {option}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>
          )
        }

        return (
          <Field key={field.key}>
            <FieldLabel htmlFor={id}>{field.key}</FieldLabel>
            <Input
              id={id}
              type={field.type === 'number' ? 'number' : 'text'}
              value={value == null ? '' : String(value)}
              onChange={(e) =>
                set(field.key, field.type === 'number' ? e.target.valueAsNumber : e.target.value)
              }
            />
          </Field>
        )
      })}
    </>
  )
}

/** Seed field values from a provider's schema defaults (create flow). */
export function defaultProviderSettings(
  schema: DigitalAssetProviderSettingField[],
): Record<string, unknown> {
  const values: Record<string, unknown> = {}
  for (const field of schema) {
    if (field.default !== undefined) values[field.key] = field.default
  }
  return values
}

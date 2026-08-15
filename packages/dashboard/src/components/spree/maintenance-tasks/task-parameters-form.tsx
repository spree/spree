import type { MaintenanceTaskParameter } from '@spree/admin-sdk'
import { StoreDatePicker } from '@spree/dashboard-core'
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  SecretInput,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Switch,
} from '@spree/dashboard-ui'
import { useId } from 'react'
import { useTranslation } from 'react-i18next'

interface TaskParametersFormProps {
  parameters: MaintenanceTaskParameter[]
  values: Record<string, unknown>
  onChange: (next: Record<string, unknown>) => void
  /** Parameter names the user left blank, highlighted after a failed submit. */
  missing?: string[]
}

/**
 * Builds a task's run form from the parameter schema the server published, so
 * a task that ships in an extension needs no dashboard code to become runnable.
 *
 * The task's own validators decide the shape: a presence validator makes a
 * parameter required, an inclusion validator turns it into a select, and the
 * declared type picks the input. Values stay as the inputs produce them —
 * the server casts through the task's attribute types, which keeps parsing in
 * one place rather than duplicated here.
 */
export function TaskParametersForm({
  parameters,
  values,
  onChange,
  missing = [],
}: TaskParametersFormProps) {
  const { t } = useTranslation()
  const fieldPrefix = useId()

  if (parameters.length === 0) return null

  function setValue(name: string, value: unknown) {
    onChange({ ...values, [name]: value })
  }

  return (
    <FieldGroup>
      {parameters.map((parameter) => {
        const fieldId = `${fieldPrefix}-${parameter.name}`
        const isMissing = missing.includes(parameter.name)
        const value = values[parameter.name]

        return (
          <Field key={parameter.name}>
            <FieldLabel htmlFor={fieldId}>
              {humanize(parameter.name)}
              {parameter.required && <span className="ml-1 text-destructive">*</span>}
            </FieldLabel>

            {renderInput({ parameter, fieldId, value, isMissing, setValue })}

            {isMissing && (
              <FieldError errors={[{ message: t('admin.maintenance_tasks.run.required_field') }]} />
            )}
          </Field>
        )
      })}
    </FieldGroup>
  )
}

function renderInput({
  parameter,
  fieldId,
  value,
  isMissing,
  setValue,
}: {
  parameter: MaintenanceTaskParameter
  fieldId: string
  value: unknown
  isMissing: boolean
  setValue: (name: string, value: unknown) => void
}) {
  const invalid = isMissing || undefined

  // An inclusion validator on the task means the value set is closed, so the
  // form offers exactly those values rather than free text.
  if (parameter.options && parameter.options.length > 0) {
    const items = parameter.options.map((option) => ({ value: option, label: option }))

    return (
      <Select
        items={items}
        value={typeof value === 'string' ? value : ''}
        onValueChange={(next) => setValue(parameter.name, next)}
      >
        <SelectTrigger id={fieldId} aria-invalid={invalid}>
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {items.map((item) => (
            <SelectItem key={item.value} value={item.value}>
              {item.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    )
  }

  switch (parameter.type) {
    case 'boolean':
      return (
        <Switch
          id={fieldId}
          checked={value === true}
          onCheckedChange={(checked) => setValue(parameter.name, checked)}
        />
      )

    case 'integer':
    case 'decimal':
      return (
        <Input
          id={fieldId}
          type="number"
          step={parameter.type === 'integer' ? 1 : 'any'}
          aria-invalid={invalid}
          value={value === null || value === undefined ? '' : String(value)}
          onChange={(event) => setValue(parameter.name, event.target.value)}
        />
      )

    case 'date':
    case 'datetime':
      return (
        <StoreDatePicker
          value={typeof value === 'string' ? value : ''}
          onChange={(next: string | null) => setValue(parameter.name, next ?? '')}
          includeTime={parameter.type === 'datetime'}
          inline
        />
      )

    default:
      // A masked parameter is one the server will never read back, so the
      // input hides it the same way it hides a credential.
      if (parameter.masked) {
        return (
          <SecretInput
            id={fieldId}
            label={humanize(parameter.name)}
            value={typeof value === 'string' ? value : ''}
            onChange={(next) => setValue(parameter.name, next)}
          />
        )
      }

      return (
        <Input
          id={fieldId}
          aria-invalid={invalid}
          value={typeof value === 'string' ? value : ''}
          onChange={(event) => setValue(parameter.name, event.target.value)}
        />
      )
  }
}

/** `batch_size` reads better as "Batch size" above an input. */
function humanize(name: string): string {
  return name.replace(/_/g, ' ').replace(/^./, (character) => character.toUpperCase())
}

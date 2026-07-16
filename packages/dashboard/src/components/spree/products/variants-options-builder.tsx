import type { OptionType } from '@spree/admin-sdk'
import {
  Badge,
  Button,
  Field,
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@spree/dashboard-ui'
import { CheckIcon, PencilIcon, PlusIcon, XIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import {
  useCreateOptionType,
  useOptionTypes,
  useUpdateOptionType,
} from '../../../hooks/use-option-types'
import type { SelectedOptionType } from './variants-matrix'

interface Props {
  selected: SelectedOptionType[]
  onChange: (next: SelectedOptionType[]) => void
}

// The options builder lets the merchant choose option types + values that
// drive the variants matrix. It DOES NOT mutate the product itself — it
// only updates the local `selected` state. The matrix component owns the
// reconcile step that turns this state into RHF variant rows.
export function VariantsOptionsBuilder({ selected, onChange }: Props) {
  const { t } = useTranslation()
  const { data: optionTypesData } = useOptionTypes({ limit: 100 })
  const allOptionTypes = optionTypesData?.data ?? []

  const [editingIndex, setEditingIndex] = useState<number | null>(null)
  const [isAdding, setIsAdding] = useState(false)

  const selectedIds = new Set(selected.map((s) => s.id))
  const availableTypes = allOptionTypes.filter((ot) => !selectedIds.has(ot.id))

  const removeAt = (index: number) => {
    onChange(selected.filter((_, i) => i !== index))
  }

  const upsertAt = (index: number | null, next: SelectedOptionType) => {
    if (index == null) {
      onChange([...selected, { ...next, position: selected.length }])
    } else {
      onChange(selected.map((s, i) => (i === index ? next : s)))
    }
    setEditingIndex(null)
    setIsAdding(false)
  }

  return (
    <div className="flex flex-col gap-3">
      {selected.length > 0 && (
        <ul className="flex flex-col gap-2">
          {selected.map((ot, i) => {
            const optionType = allOptionTypes.find((t) => t.id === ot.id)
            const isEditing = editingIndex === i
            if (isEditing && optionType) {
              return (
                <li key={ot.id} className="rounded-lg border border-border p-3">
                  <OptionPicker
                    optionType={optionType}
                    initialValues={ot.values}
                    onCancel={() => setEditingIndex(null)}
                    onSave={(values) =>
                      upsertAt(i, {
                        id: optionType.id,
                        name: optionType.name,
                        label: optionType.label,
                        position: ot.position,
                        values,
                      })
                    }
                  />
                </li>
              )
            }
            return (
              <li
                key={ot.id}
                className="flex items-center gap-3 rounded-lg border border-border px-3 py-2"
              >
                <div className="min-w-0 flex-1">
                  <div className="text-sm font-medium">{ot.label}</div>
                  <div className="mt-1 flex flex-wrap gap-1">
                    {ot.values.map((v) => (
                      <Badge key={v.name} variant="secondary">
                        {v.label ?? v.name}
                      </Badge>
                    ))}
                  </div>
                </div>
                <Button
                  type="button"
                  variant="ghost"
                  size="icon-sm"
                  aria-label={t('admin.actions.edit')}
                  onClick={() => setEditingIndex(i)}
                >
                  <PencilIcon />
                </Button>
                <Button
                  type="button"
                  variant="ghost"
                  size="icon-sm"
                  aria-label={t('admin.actions.remove')}
                  onClick={() => removeAt(i)}
                >
                  <XIcon />
                </Button>
              </li>
            )
          })}
        </ul>
      )}

      {isAdding ? (
        <div className="rounded-lg border border-border p-3">
          <AddOptionForm
            availableTypes={availableTypes}
            allOptionTypes={allOptionTypes}
            onCancel={() => setIsAdding(false)}
            onSave={(payload) => upsertAt(null, payload)}
          />
        </div>
      ) : (
        <div>
          <Button type="button" variant="outline" size="sm" onClick={() => setIsAdding(true)}>
            <PlusIcon />
            {t('admin.products.variants.add_option')}
          </Button>
        </div>
      )}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Add-option form: picks an option type (or creates a new one), then values
// ---------------------------------------------------------------------------

interface AddOptionFormProps {
  availableTypes: OptionType[]
  allOptionTypes: OptionType[]
  onSave: (payload: SelectedOptionType) => void
  onCancel: () => void
}

function AddOptionForm({ availableTypes, allOptionTypes, onSave, onCancel }: AddOptionFormProps) {
  const { t } = useTranslation()
  const [pickedTypeId, setPickedTypeId] = useState<string>('')
  const [creatingType, setCreatingType] = useState(false)
  const createOptionType = useCreateOptionType()

  const picked =
    allOptionTypes.find((ot) => ot.id === pickedTypeId) ??
    availableTypes.find((ot) => ot.id === pickedTypeId)

  if (creatingType) {
    return (
      <CreateOptionTypeInline
        onCancel={() => setCreatingType(false)}
        onCreated={(created) => {
          setPickedTypeId(created.id)
          setCreatingType(false)
        }}
        isPending={createOptionType.isPending}
        createMutation={createOptionType.mutateAsync}
      />
    )
  }

  if (!picked) {
    return (
      <div className="flex flex-col gap-3">
        <Field>
          <FieldLabel>{t('admin.products.variants.option_type_label')}</FieldLabel>
          <Select value={pickedTypeId} onValueChange={setPickedTypeId}>
            <SelectTrigger className="w-full">
              <SelectValue placeholder={t('admin.products.variants.option_type_placeholder')}>
                {(v) =>
                  availableTypes.find((ot) => ot.id === v)?.label ??
                  t('admin.products.variants.option_type_placeholder')
                }
              </SelectValue>
            </SelectTrigger>
            <SelectContent>
              {availableTypes.map((ot) => (
                <SelectItem key={ot.id} value={ot.id}>
                  {ot.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </Field>
        <div className="flex items-center justify-between gap-2">
          <Button type="button" variant="ghost" size="sm" onClick={() => setCreatingType(true)}>
            <PlusIcon />
            {t('admin.products.variants.create_option_type')}
          </Button>
          <Button type="button" variant="ghost" size="sm" onClick={onCancel}>
            {t('admin.actions.cancel')}
          </Button>
        </div>
      </div>
    )
  }

  return (
    <OptionPicker
      optionType={picked}
      initialValues={[]}
      onCancel={onCancel}
      onSave={(values) =>
        onSave({
          id: picked.id,
          name: picked.name,
          label: picked.label,
          position: 0, // overridden by parent on append
          values,
        })
      }
    />
  )
}

// ---------------------------------------------------------------------------
// Option-type picker + values multi-select with inline value creation
// ---------------------------------------------------------------------------

interface OptionPickerProps {
  optionType: OptionType
  initialValues: { name: string; label?: string }[]
  onSave: (values: { name: string; label?: string }[]) => void
  onCancel: () => void
}

function OptionPicker({ optionType, initialValues, onSave, onCancel }: OptionPickerProps) {
  const { t } = useTranslation()
  const updateOptionType = useUpdateOptionType(optionType.id)
  const [pickedNames, setPickedNames] = useState<Set<string>>(
    () => new Set(initialValues.map((v) => v.name)),
  )
  const [creatingValue, setCreatingValue] = useState(false)

  const available = optionType.option_values ?? []

  const toggle = (name: string) => {
    setPickedNames((prev) => {
      const next = new Set(prev)
      if (next.has(name)) next.delete(name)
      else next.add(name)
      return next
    })
  }

  const handleSave = () => {
    const ordered = available.filter((v) => pickedNames.has(v.name))
    onSave(ordered.map((v) => ({ name: v.name, label: v.label })))
  }

  const handleCreateValue = async (name: string, label: string) => {
    const newValue = { name, label }
    // OptionTypeUpdateParams.option_values replaces the full set — preserve
    // existing values and append the new one.
    const nextValues = [
      ...available.map((v) => ({
        id: v.id,
        name: v.name,
        label: v.label,
        position: v.position,
        color_code: v.color_code,
      })),
      newValue,
    ]
    try {
      await updateOptionType.mutateAsync({ option_values: nextValues })
      setPickedNames((prev) => new Set(prev).add(name))
      setCreatingValue(false)
    } catch (err) {
      const message =
        err instanceof Error
          ? err.message
          : t('admin.products.variants.errors.failed_to_create_value')
      toast.error(message)
    }
  }

  if (creatingValue) {
    return (
      <CreateOptionValueInline
        onCancel={() => setCreatingValue(false)}
        onCreate={handleCreateValue}
        isPending={updateOptionType.isPending}
      />
    )
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <div className="text-sm font-medium">{optionType.label}</div>
      </div>
      <div className="flex flex-wrap gap-2">
        {available.map((v) => {
          const isPicked = pickedNames.has(v.name)
          return (
            <button
              key={v.id}
              type="button"
              onClick={() => toggle(v.name)}
              aria-pressed={isPicked}
              className={`inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs transition-colors ${
                isPicked
                  ? 'border-primary bg-primary text-primary-foreground'
                  : 'border-border bg-background hover:bg-muted'
              }`}
            >
              {isPicked && <CheckIcon className="size-3" />}
              {v.label || v.name}
            </button>
          )
        })}
        <button
          type="button"
          onClick={() => setCreatingValue(true)}
          className="inline-flex items-center gap-1.5 rounded-full border border-dashed border-border bg-background px-3 py-1 text-xs hover:bg-muted"
        >
          <PlusIcon className="size-3" />
          {t('admin.products.variants.create_value')}
        </button>
      </div>
      <div className="flex items-center justify-end gap-2">
        <Button type="button" variant="ghost" size="sm" onClick={onCancel}>
          {t('admin.actions.cancel')}
        </Button>
        <Button type="button" size="sm" onClick={handleSave} disabled={pickedNames.size === 0}>
          {t('admin.actions.done')}
        </Button>
      </div>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Inline: create a new option type
// ---------------------------------------------------------------------------

interface CreateOptionTypeInlineProps {
  onCancel: () => void
  onCreated: (optionType: OptionType) => void
  isPending: boolean
  createMutation: (params: { name: string; label: string; kind: string }) => Promise<OptionType>
}

function CreateOptionTypeInline({
  onCancel,
  onCreated,
  isPending,
  createMutation,
}: CreateOptionTypeInlineProps) {
  const { t } = useTranslation()
  const [label, setLabel] = useState('')
  const [name, setName] = useState('')
  const [touchedName, setTouchedName] = useState(false)

  const submit = async () => {
    const finalName = (name || label).trim().toLowerCase().replace(/\s+/g, '_')
    if (!label.trim() || !finalName) return
    try {
      const created = await createMutation({
        name: finalName,
        label: label.trim(),
        kind: 'dropdown',
      })
      onCreated(created)
    } catch (err) {
      const message =
        err instanceof Error
          ? err.message
          : t('admin.products.variants.errors.failed_to_create_option_type')
      toast.error(message)
    }
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="text-sm font-medium">
        {t('admin.products.variants.create_option_type_title')}
      </div>
      <Field>
        <FieldLabel htmlFor="new-option-type-label">
          {t('admin.fields.option_type.label.label')}
        </FieldLabel>
        <Input
          id="new-option-type-label"
          value={label}
          onChange={(e) => {
            setLabel(e.target.value)
            if (!touchedName) {
              setName(e.target.value.trim().toLowerCase().replace(/\s+/g, '_'))
            }
          }}
          placeholder={t('admin.fields.option_type.label.placeholder')}
        />
      </Field>
      <Field>
        <FieldLabel htmlFor="new-option-type-name">
          {t('admin.fields.option_type.name.label')}
        </FieldLabel>
        <Input
          id="new-option-type-name"
          value={name}
          onChange={(e) => {
            setTouchedName(true)
            setName(e.target.value)
          }}
          placeholder={t('admin.fields.option_type.name.placeholder')}
        />
      </Field>
      <div className="flex items-center justify-end gap-2">
        <Button type="button" variant="ghost" size="sm" onClick={onCancel} disabled={isPending}>
          {t('admin.actions.cancel')}
        </Button>
        <Button type="button" size="sm" onClick={submit} disabled={isPending || !label.trim()}>
          {isPending ? t('admin.actions.creating') : t('admin.actions.create')}
        </Button>
      </div>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Inline: create a new option value on the picked option type
// ---------------------------------------------------------------------------

interface CreateOptionValueInlineProps {
  onCancel: () => void
  onCreate: (name: string, label: string) => Promise<void>
  isPending: boolean
}

function CreateOptionValueInline({ onCancel, onCreate, isPending }: CreateOptionValueInlineProps) {
  const { t } = useTranslation()
  const [label, setLabel] = useState('')
  const [name, setName] = useState('')
  const [touchedName, setTouchedName] = useState(false)

  const submit = async () => {
    const finalName = (name || label).trim().toLowerCase().replace(/\s+/g, '_')
    if (!label.trim() || !finalName) return
    await onCreate(finalName, label.trim())
  }

  return (
    <div className="flex flex-col gap-3">
      <div className="text-sm font-medium">{t('admin.products.variants.create_value_title')}</div>
      <Field>
        <FieldLabel htmlFor="new-option-value-label">
          {t('admin.fields.option_value.label.label')}
        </FieldLabel>
        <Input
          id="new-option-value-label"
          value={label}
          onChange={(e) => {
            setLabel(e.target.value)
            if (!touchedName) {
              setName(e.target.value.trim().toLowerCase().replace(/\s+/g, '_'))
            }
          }}
          placeholder={t('admin.fields.option_value.label.placeholder')}
        />
      </Field>
      <Field>
        <FieldLabel htmlFor="new-option-value-name">
          {t('admin.fields.option_value.name.label')}
        </FieldLabel>
        <Input
          id="new-option-value-name"
          value={name}
          onChange={(e) => {
            setTouchedName(true)
            setName(e.target.value)
          }}
          placeholder={t('admin.fields.option_value.name.placeholder')}
        />
      </Field>
      <div className="flex items-center justify-end gap-2">
        <Button type="button" variant="ghost" size="sm" onClick={onCancel} disabled={isPending}>
          {t('admin.actions.cancel')}
        </Button>
        <Button type="button" size="sm" onClick={submit} disabled={isPending || !label.trim()}>
          {isPending ? t('admin.actions.creating') : t('admin.actions.create')}
        </Button>
      </div>
    </div>
  )
}

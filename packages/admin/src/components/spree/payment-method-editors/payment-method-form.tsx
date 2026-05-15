import type { PaymentMethod, PreferenceField } from '@spree/admin-sdk'
import { Controller, type UseFormReturn } from 'react-hook-form'
import { PreferencesForm } from '@/components/spree/preferences-form'
import { Slot } from '@/components/spree/slot'
import { StorefrontVisibleSwitch } from '@/components/spree/storefront-visible-switch'
import { Field, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Switch } from '@/components/ui/switch'
import { Textarea } from '@/components/ui/textarea'
import { useSlotEntries } from '@/lib/slot-registry'
import {
  type PaymentMethodEditorContext,
  type PaymentMethodFormMode,
  type PaymentMethodFormValues,
  paymentMethodActionsSlot,
  paymentMethodFormSlot,
  paymentMethodGuideSlot,
} from './types'

interface ProviderOption {
  type: string
  label: string
  preference_schema: PreferenceField[]
}

interface PaymentMethodFormProps {
  mode: PaymentMethodFormMode
  form: UseFormReturn<PaymentMethodFormValues>
  /** Available provider types — only consulted in `create` mode for the dropdown. */
  providerTypes?: ProviderOption[]
  loadingTypes?: boolean
  /**
   * The provider's preference schema. In create mode, look it up from
   * `providerTypes` against the selected `type` (the parent does this so
   * it can also seed `preferences` with defaults on type change).
   */
  preferenceSchema: PreferenceField[]
  /** Current provider's STI shorthand — drives slot lookups. */
  providerType: string
  /** Loaded server record in edit mode; null while creating. */
  paymentMethod: PaymentMethod | null
  preferences: Record<string, unknown>
  onPreferencesChange: (next: Record<string, unknown>) => void
  /** Called when the user picks a different provider in the create dropdown. */
  onProviderTypeChange?: (next: string) => void
}

export function PaymentMethodForm({
  mode,
  form,
  providerTypes = [],
  loadingTypes,
  preferenceSchema,
  providerType,
  paymentMethod,
  preferences,
  onPreferencesChange,
  onProviderTypeChange,
}: PaymentMethodFormProps) {
  // Per-provider slot lookups. If a plugin has registered a `form` slot
  // for this provider (e.g. Stripe OAuth Connect), we render that
  // instead of the generic `<PreferencesForm>`. Guide/actions slots are
  // always additive.
  const formSlotEntries = useSlotEntries(paymentMethodFormSlot(providerType))
  const customFormRegistered = formSlotEntries.length > 0

  const slotContext: PaymentMethodEditorContext = {
    mode,
    type: providerType,
    paymentMethod,
    preferenceSchema,
    preferences,
    onPreferencesChange,
    form,
  }

  return (
    <div className="flex flex-1 flex-col gap-4">
      {mode === 'create' && (
        <Field>
          <FieldLabel htmlFor="type">Provider</FieldLabel>
          <Controller
            name="type"
            control={form.control}
            render={({ field }) => (
              <Select
                value={field.value ?? ''}
                onValueChange={(next) => {
                  field.onChange(next)
                  onProviderTypeChange?.(next)
                  // Prefill the Name field with the provider's label —
                  // but only if the admin hasn't typed something
                  // themselves yet.
                  const label = providerTypes.find((t) => t.type === next)?.label
                  if (label && !form.formState.dirtyFields.name) {
                    form.setValue('name', label, { shouldDirty: false })
                  }
                }}
              >
                <SelectTrigger id="type" aria-invalid={!!form.formState.errors.type}>
                  <SelectValue placeholder={loadingTypes ? 'Loading…' : 'Select a provider'}>
                    {(value) =>
                      providerTypes.find((t) => t.type === value)?.label ?? (value as string)
                    }
                  </SelectValue>
                </SelectTrigger>
                <SelectContent>
                  {providerTypes.map((t) => (
                    <SelectItem key={t.type} value={t.type}>
                      {t.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
          {form.formState.errors.type && (
            <p className="text-sm text-destructive">{form.formState.errors.type.message}</p>
          )}
        </Field>
      )}

      <PaymentMethodTopFields form={form} />

      {providerType && <Slot name={paymentMethodGuideSlot(providerType)} context={slotContext} />}

      {providerType && (customFormRegistered || preferenceSchema.length > 0) ? (
        <div className="rounded-md border bg-muted/30 p-3">
          <h3 className="mb-2 text-sm font-medium">Provider configuration</h3>
          {customFormRegistered ? (
            // A plugin has taken over — render the registered editor
            // instead of the generic preferences form. Plugin owns its
            // own dirty state and submission inside `onPreferencesChange`.
            <Slot name={paymentMethodFormSlot(providerType)} context={slotContext} />
          ) : (
            <PreferencesForm
              schema={preferenceSchema}
              values={preferences}
              onChange={onPreferencesChange}
              redactPasswords={mode === 'edit'}
            />
          )}
        </div>
      ) : null}

      {providerType && <Slot name={paymentMethodActionsSlot(providerType)} context={slotContext} />}
    </div>
  )
}

function PaymentMethodTopFields({ form }: { form: UseFormReturn<PaymentMethodFormValues> }) {
  return (
    <FieldGroup>
      <Field>
        <FieldLabel htmlFor="name">Name</FieldLabel>
        <Input
          id="name"
          placeholder="e.g. Credit card (Stripe)"
          {...form.register('name')}
          aria-invalid={!!form.formState.errors.name}
        />
        {form.formState.errors.name && (
          <p className="text-sm text-destructive">{form.formState.errors.name.message}</p>
        )}
      </Field>

      <Field>
        <FieldLabel htmlFor="description">Description</FieldLabel>
        <Textarea
          id="description"
          rows={2}
          placeholder="Customer-facing description shown at checkout"
          {...form.register('description')}
        />
      </Field>

      <StorefrontVisibleSwitch control={form.control} name="storefront_visible" />

      <Field>
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col">
            <FieldLabel htmlFor="active" className="cursor-pointer">
              Active
            </FieldLabel>
            <span className="text-xs text-muted-foreground">
              Inactive methods are hidden from checkout.
            </span>
          </div>
          <Controller
            name="active"
            control={form.control}
            render={({ field }) => (
              <Switch id="active" checked={!!field.value} onCheckedChange={field.onChange} />
            )}
          />
        </div>
      </Field>

      <Field>
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col">
            <FieldLabel htmlFor="auto_capture" className="cursor-pointer">
              Auto-capture
            </FieldLabel>
            <span className="text-xs text-muted-foreground">
              Capture funds automatically on authorization. When off, you must capture manually.
            </span>
          </div>
          <Controller
            name="auto_capture"
            control={form.control}
            render={({ field }) => (
              <Switch id="auto_capture" checked={!!field.value} onCheckedChange={field.onChange} />
            )}
          />
        </div>
      </Field>
    </FieldGroup>
  )
}

import {
  Field,
  FieldError,
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Switch,
} from '@spree/dashboard-ui'
import type { FieldValues, UseFormReturn } from 'react-hook-form'
import { Controller, type Path } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { CountryCombobox } from '../components/country-combobox'
import { StoreDatePicker } from '../components/store-date-picker'
import { normalizeCustomsDescription, normalizeHsCode } from './normalize-customs'
import { PURCHASE_UNITS } from './normalize-quantity'

const WEIGHT_UNITS = ['g', 'kg', 'lb', 'oz'] as const
const DIMENSION_UNITS = ['mm', 'cm', 'in'] as const

/**
 * The variant fields both dashboards edit, in one definition.
 *
 * The operator's product form renders these inside the variant sheet, bound
 * to `variants.0`, `variants.1` and so on; the seller panel's offer page
 * renders the same sections at the root of its own form. So every field is
 * addressed through a prefix rather than a hardcoded path, and the component
 * is generic over the form's shape — which is what stops the two surfaces
 * drifting apart (docs/plans/6.0-seller-master-catalog-listings.md).
 *
 * Packing deliberately stays in the operator's sheet: carton geometry and
 * pallet counts describe how the marketplace warehouses an item, which is not
 * a seller's to state when listing an offer against someone else's product.
 *
 * Headless: no SDK import, no provider import. Whatever a section needs that
 * it cannot derive — tax categories, the store's timezone — arrives by prop
 * or through a component that already takes its own.
 */
export interface VariantFieldsProps<TFieldValues extends FieldValues> {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: UseFormReturn<TFieldValues, any, any>
  /**
   * What to put in front of every field name. `variants.0` on the operator's
   * product form; empty on a form whose root IS the variant.
   */
  prefix?: string
  /**
   * Per-field errors for this variant, narrowed by the caller.
   *
   * Loosely typed on purpose: react-hook-form describes a nested subtree as
   * `Merge<FieldError, FieldErrorsImpl<…>>`, whose own `message` key makes it
   * unassignable to a plain record of field errors. Every consumer reads one
   * field at a time and hands it straight to `<FieldError>`, which accepts
   * whatever it is given.
   */
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  errors?: any
}

/** Builds a field path, tolerating an empty prefix. */
function path<TFieldValues extends FieldValues>(prefix: string, name: string): Path<TFieldValues> {
  return (prefix ? `${prefix}.${name}` : name) as Path<TFieldValues>
}

/** A field id, unique per prefix so two sections never collide. */
function fieldId(prefix: string, name: string): string {
  return `${prefix ? prefix.replace(/\./g, '-') : 'variant'}-${name}`
}

export function VariantIdentityFields<TFieldValues extends FieldValues>({
  form,
  prefix = '',
  errors,
}: VariantFieldsProps<TFieldValues>) {
  const { t } = useTranslation()

  return (
    <>
      <Field>
      <FieldLabel htmlFor={fieldId(prefix, 'sku')}>
      {t('admin.fields.variant.sku.label')}
      </FieldLabel>
      {/*
      Use Controller instead of register here: the matrix row in
      VariantsSection also registers `variants.${i}.sku`, and two
      `register` calls on the same field path share a single ref
      slot — the second mount wins, so typing in one input never
      updates the other's display. A Controller subscribes to the
      field via useController and renders a controlled input, so
      both surfaces stay in sync whichever one the merchant edits.
      */}
      <Controller
      name={path<TFieldValues>(prefix, 'sku')}
      control={form.control}
      render={({ field }) => (
      <Input
      id={fieldId(prefix, 'sku')}
      placeholder={t('admin.fields.variant.sku.placeholder')}
      value={field.value ?? ''}
      onChange={(e) => field.onChange(e.target.value)}
      onBlur={field.onBlur}
      />
      )}
      />
      <FieldError errors={[errors?.sku]} />
      </Field>
      <Field>
      <FieldLabel htmlFor={fieldId(prefix, 'barcode')}>
      {t('admin.fields.variant.barcode.label')}
      </FieldLabel>
      <Input
      id={fieldId(prefix, 'barcode')}
      {...form.register(path<TFieldValues>(prefix, 'barcode'))}
      />
      <FieldError errors={[errors?.barcode]} />
      </Field>
    </>
  )
}

export function VariantShippingFields<TFieldValues extends FieldValues>({
  form,
  prefix = '',
  errors,
}: VariantFieldsProps<TFieldValues>) {
  const { t } = useTranslation()

  return (
    <>
      <div className="grid grid-cols-[1fr_120px] gap-3">
      <Field>
      <FieldLabel htmlFor={fieldId(prefix, 'weight')}>
      {t('admin.fields.variant.weight.label')}
      </FieldLabel>
      <Input
      id={fieldId(prefix, 'weight')}
      type="number"
      step="0.01"
      min="0"
      {...form.register(path<TFieldValues>(prefix, 'weight'))}
      />
      </Field>
      <Field>
      <FieldLabel htmlFor={fieldId(prefix, 'weight-unit')}>
      {t('admin.fields.variant.weight_unit.label')}
      </FieldLabel>
      <Controller
      name={path<TFieldValues>(prefix, 'weight_unit')}
      control={form.control}
      render={({ field }) => (
      <Select
      value={field.value ?? ''}
      onValueChange={(v) => field.onChange(v || null)}
      >
      <SelectTrigger id={fieldId(prefix, 'weight-unit')} className="w-full">
      <SelectValue>{(v) => (v as string) || '—'}</SelectValue>
      </SelectTrigger>
      <SelectContent>
      {WEIGHT_UNITS.map((u) => (
      <SelectItem key={u} value={u}>
      {u}
      </SelectItem>
      ))}
      </SelectContent>
      </Select>
      )}
      />
      </Field>
      </div>

      <div className="grid grid-cols-[1fr_1fr_1fr_120px] gap-3">
      <Field>
      <FieldLabel htmlFor={fieldId(prefix, 'height')}>
      {t('admin.fields.variant.height.label')}
      </FieldLabel>
      <Input
      id={fieldId(prefix, 'height')}
      type="number"
      step="0.01"
      min="0"
      {...form.register(path<TFieldValues>(prefix, 'height'))}
      />
      </Field>
      <Field>
      <FieldLabel htmlFor={fieldId(prefix, 'width')}>
      {t('admin.fields.variant.width.label')}
      </FieldLabel>
      <Input
      id={fieldId(prefix, 'width')}
      type="number"
      step="0.01"
      min="0"
      {...form.register(path<TFieldValues>(prefix, 'width'))}
      />
      </Field>
      <Field>
      <FieldLabel htmlFor={fieldId(prefix, 'depth')}>
      {t('admin.fields.variant.depth.label')}
      </FieldLabel>
      <Input
      id={fieldId(prefix, 'depth')}
      type="number"
      step="0.01"
      min="0"
      {...form.register(path<TFieldValues>(prefix, 'depth'))}
      />
      </Field>
      <Field>
      <FieldLabel htmlFor={fieldId(prefix, 'dim-unit')}>
      {t('admin.fields.variant.dimensions_unit.label')}
      </FieldLabel>
      <Controller
      name={path<TFieldValues>(prefix, 'dimensions_unit')}
      control={form.control}
      render={({ field }) => (
      <Select
      value={field.value ?? ''}
      onValueChange={(v) => field.onChange(v || null)}
      >
      <SelectTrigger id={fieldId(prefix, 'dim-unit')} className="w-full">
      <SelectValue>{(v) => (v as string) || '—'}</SelectValue>
      </SelectTrigger>
      <SelectContent>
      {DIMENSION_UNITS.map((u) => (
      <SelectItem key={u} value={u}>
      {u}
      </SelectItem>
      ))}
      </SelectContent>
      </Select>
      )}
      />
      </Field>
      </div>
    </>
  )
}

export function VariantCustomsFields<TFieldValues extends FieldValues>({
  form,
  prefix = '',
  errors,
}: VariantFieldsProps<TFieldValues>) {
  const { t } = useTranslation()

  return (
    <>
      <p className="text-sm text-muted-foreground">
      {t('admin.products.variants.sheet.customs_help')}
      </p>
      <div className="grid grid-cols-2 gap-3">
      <Field>
      <FieldLabel htmlFor={fieldId(prefix, 'hs-code')}>
      {t('admin.fields.variant.hs_code.label')}
      </FieldLabel>
      <Input
      id={fieldId(prefix, 'hs-code')}
      inputMode="numeric"
      placeholder={t('admin.fields.variant.hs_code.placeholder')}
      {...form.register(path<TFieldValues>(prefix, 'hs_code'), {
      setValueAs: normalizeHsCode,
      })}
      />
      <FieldError errors={[errors?.hs_code]} />
      </Field>
      <Field>
      <FieldLabel htmlFor={fieldId(prefix, 'country-of-origin')}>
      {t('admin.fields.variant.country_of_origin.label')}
      </FieldLabel>
      <Controller
      name={path<TFieldValues>(prefix, 'country_of_origin')}
      control={form.control}
      render={({ field }) => (
      <CountryCombobox
      id={fieldId(prefix, 'country-of-origin')}
      value={field.value ?? null}
      onValueChange={(iso) => field.onChange(iso || null)}
      />
      )}
      />
      <FieldError
      errors={[errors?.country_of_origin]}
      />
      </Field>
      </div>
      <Field>
      <FieldLabel htmlFor={fieldId(prefix, 'customs-description')}>
      {t('admin.fields.variant.customs_description.label')}
      </FieldLabel>
      <Input
      id={fieldId(prefix, 'customs-description')}
      placeholder={t('admin.fields.variant.customs_description.placeholder')}
      {...form.register(path<TFieldValues>(prefix, 'customs_description'), {
      setValueAs: normalizeCustomsDescription,
      })}
      />
      <FieldError
      errors={[errors?.customs_description]}
      />
      </Field>
    </>
  )
}

export function VariantOrderingFields<TFieldValues extends FieldValues>({
  form,
  prefix = '',
  errors,
}: VariantFieldsProps<TFieldValues>) {
  const { t } = useTranslation()

  return (
    <>
      <p className="text-sm text-muted-foreground">
      {t('admin.products.variants.sheet.ordering_help')}
      </p>
      <div className="grid grid-cols-2 gap-3">
      <Field>
      <FieldLabel htmlFor={fieldId(prefix, 'moq')}>
      {t('admin.fields.variant.minimum_order_quantity.label')}
      </FieldLabel>
      <Input
      id={fieldId(prefix, 'moq')}
      type="number"
      min="1"
      step="1"
      placeholder={t('admin.fields.variant.minimum_order_quantity.placeholder')}
      {...form.register(path<TFieldValues>(prefix, 'minimum_order_quantity'))}
      />
      <FieldError
      errors={[errors?.minimum_order_quantity]}
      />
      </Field>
      <Field>
      <FieldLabel htmlFor={fieldId(prefix, 'order-multiple')}>
      {t('admin.fields.variant.order_multiple.label')}
      </FieldLabel>
      <Input
      id={fieldId(prefix, 'order-multiple')}
      type="number"
      min="1"
      step="1"
      placeholder={t('admin.fields.variant.order_multiple.placeholder')}
      {...form.register(path<TFieldValues>(prefix, 'order_multiple'))}
      />
      <FieldError
      errors={[errors?.order_multiple]}
      />
      </Field>
      <Field>
      <FieldLabel htmlFor={fieldId(prefix, 'purchase-unit')}>
      {t('admin.fields.variant.purchase_unit.label')}
      </FieldLabel>
      <Controller
      name={path<TFieldValues>(prefix, 'purchase_unit')}
      control={form.control}
      render={({ field }) => (
      <Select
      value={field.value ?? ''}
      onValueChange={(v) => field.onChange(v || null)}
      >
      <SelectTrigger
      id={fieldId(prefix, 'purchase-unit')}
      className="w-full"
      >
      <SelectValue>
      {(v) =>
      v
      ? t(`admin.fields.variant.purchase_unit.options.${v as string}`)
      : t('admin.fields.variant.purchase_unit.options.unit')
      }
      </SelectValue>
      </SelectTrigger>
      <SelectContent>
      {PURCHASE_UNITS.map((unit) => (
      <SelectItem key={unit} value={unit}>
      {t(`admin.fields.variant.purchase_unit.options.${unit}`)}
      </SelectItem>
      ))}
      </SelectContent>
      </Select>
      )}
      />
      </Field>
      <Field>
      <FieldLabel htmlFor={fieldId(prefix, 'units-per-carton')}>
      {t('admin.fields.variant.units_per_carton.label')}
      </FieldLabel>
      <Input
      id={fieldId(prefix, 'units-per-carton')}
      type="number"
      min="1"
      step="1"
      {...form.register(path<TFieldValues>(prefix, 'units_per_carton'))}
      />
      <FieldError
      errors={[errors?.units_per_carton]}
      />
      </Field>
      </div>
    </>
  )
}

export function VariantAvailabilityFields<TFieldValues extends FieldValues>({
  form,
  prefix = '',
  errors,
}: VariantFieldsProps<TFieldValues>) {
  const { t } = useTranslation()
  const preorderable = form.watch(path<TFieldValues>(prefix, 'preorderable'))

  return (
    <>
      <Field>
      <div className="flex items-start justify-between gap-4">
      <div className="flex flex-col">
      <FieldLabel
      htmlFor={fieldId(prefix, 'preorderable')}
      className="cursor-pointer"
      >
      {t('admin.fields.variant.preorderable.label')}
      </FieldLabel>
      <span className="text-xs text-muted-foreground">
      {t('admin.fields.variant.preorderable.help')}
      </span>
      </div>
      <Controller
      name={path<TFieldValues>(prefix, 'preorderable')}
      control={form.control}
      render={({ field }) => (
      <Switch
      id={fieldId(prefix, 'preorderable')}
      checked={!!field.value}
      onCheckedChange={field.onChange}
      />
      )}
      />
      </div>
      </Field>

      {preorderable && (
      <Field>
      <FieldLabel>{t('admin.fields.variant.preorder_ships_at.label')}</FieldLabel>
      <Controller
      control={form.control}
      name={path<TFieldValues>(prefix, 'preorder_ships_at')}
      render={({ field }) => (
      <StoreDatePicker
      value={field.value ?? null}
      onChange={(next) => field.onChange(next ?? null)}
      placeholder={t('admin.fields.variant.preorder_ships_at.placeholder')}
      includeTime
      inline
      />
      )}
      />
      <span className="text-xs text-muted-foreground">
      {t('admin.fields.variant.preorder_ships_at.help')}
      </span>
      </Field>
      )}

      <Field>
      <FieldLabel htmlFor={fieldId(prefix, 'backorder-limit')}>
      {t('admin.fields.variant.backorder_limit.label')}
      </FieldLabel>
      <Controller
      control={form.control}
      name={path<TFieldValues>(prefix, 'backorder_limit')}
      render={({ field }) => (
      <Input
      id={fieldId(prefix, 'backorder-limit')}
      type="number"
      min="0"
      step="1"
      placeholder={t('admin.fields.variant.backorder_limit.placeholder')}
      value={field.value ?? ''}
      onChange={(event) => {
      const parsed = Number(event.target.value)
      field.onChange(
      event.target.value === '' || Number.isNaN(parsed)
      ? null
      : Math.max(0, Math.trunc(parsed)),
      )
      }}
      />
      )}
      />
      <span className="text-xs text-muted-foreground">
      {t('admin.fields.variant.backorder_limit.help')}
      </span>
      <FieldError
      errors={[errors?.backorder_limit]}
      />
      </Field>
    </>
  )
}

/** A titled group, so both surfaces space their sections identically. */
export function VariantFieldSection({
  title,
  children,
}: {
  title: string
  children: React.ReactNode
}) {
  return (
    <section className="flex flex-col gap-3">
      <h3 className="font-medium text-sm">{title}</h3>
      {children}
    </section>
  )
}

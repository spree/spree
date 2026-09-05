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
 * Headless: no SDK import, no provider import. Whatever a section needs that
 * it cannot derive — tax categories, the store's timezone — arrives by prop
 * or through a component that already takes its own.
 */
export interface VariantFieldsProps<TFieldValues extends FieldValues> {
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
          Controller rather than register: on the operator's product form the
          matrix row registers the same path, and two `register` calls share a
          single ref slot — the second mount wins, so typing in one input never
          updates the other. A controlled input keeps both in sync.
        */}
        <Controller
          name={path<TFieldValues>(prefix, 'sku')}
          control={form.control}
          render={({ field }) => (
            <Input
              id={fieldId(prefix, 'sku')}
              placeholder={t('admin.fields.variant.sku.placeholder')}
              value={(field.value as string) ?? ''}
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
          <FieldError errors={[errors?.weight]} />
        </Field>
        <Field>
          <FieldLabel htmlFor={fieldId(prefix, 'weight_unit')}>
            {t('admin.fields.variant.weight_unit.label')}
          </FieldLabel>
          <Controller
            name={path<TFieldValues>(prefix, 'weight_unit')}
            control={form.control}
            render={({ field }) => (
              <Select
                items={WEIGHT_UNITS.map((unit) => ({ value: unit, label: unit }))}
                value={(field.value as string) ?? ''}
                onValueChange={field.onChange}
              >
                <SelectTrigger id={fieldId(prefix, 'weight_unit')}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {WEIGHT_UNITS.map((unit) => (
                    <SelectItem key={unit} value={unit}>
                      {unit}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
        </Field>
      </div>

      <div className="grid grid-cols-[1fr_1fr_1fr_120px] gap-3">
        {(['height', 'width', 'depth'] as const).map((dimension) => (
          <Field key={dimension}>
            <FieldLabel htmlFor={fieldId(prefix, dimension)}>
              {t(`admin.fields.variant.${dimension}.label`)}
            </FieldLabel>
            <Input
              id={fieldId(prefix, dimension)}
              type="number"
              step="0.01"
              min="0"
              {...form.register(path<TFieldValues>(prefix, dimension))}
            />
            <FieldError errors={[errors?.[dimension]]} />
          </Field>
        ))}
        <Field>
          <FieldLabel htmlFor={fieldId(prefix, 'dimensions_unit')}>
            {t('admin.fields.variant.dimensions_unit.label')}
          </FieldLabel>
          <Controller
            name={path<TFieldValues>(prefix, 'dimensions_unit')}
            control={form.control}
            render={({ field }) => (
              <Select
                items={DIMENSION_UNITS.map((unit) => ({ value: unit, label: unit }))}
                value={(field.value as string) ?? ''}
                onValueChange={field.onChange}
              >
                <SelectTrigger id={fieldId(prefix, 'dimensions_unit')}>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {DIMENSION_UNITS.map((unit) => (
                    <SelectItem key={unit} value={unit}>
                      {unit}
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
      <p className="text-muted-foreground text-sm">
        {t('admin.products.variants.sheet.customs_help')}
      </p>
      <div className="grid grid-cols-2 gap-3">
        <Field>
          <FieldLabel htmlFor={fieldId(prefix, 'hs_code')}>
            {t('admin.fields.variant.hs_code.label')}
          </FieldLabel>
          <Controller
            name={path<TFieldValues>(prefix, 'hs_code')}
            control={form.control}
            render={({ field }) => (
              <Input
                id={fieldId(prefix, 'hs_code')}
                placeholder={t('admin.fields.variant.hs_code.placeholder')}
                value={(field.value as string) ?? ''}
                onChange={(e) => field.onChange(normalizeHsCode(e.target.value))}
                onBlur={field.onBlur}
              />
            )}
          />
          <FieldError errors={[errors?.hs_code]} />
        </Field>
        <Field>
          <FieldLabel htmlFor={fieldId(prefix, 'country_of_origin')}>
            {t('admin.fields.variant.country_of_origin.label')}
          </FieldLabel>
          <Controller
            name={path<TFieldValues>(prefix, 'country_of_origin')}
            control={form.control}
            render={({ field }) => (
              <CountryCombobox
                id={fieldId(prefix, 'country_of_origin')}
                value={(field.value as string) ?? null}
                onValueChange={(iso) => field.onChange(iso || null)}
              />
            )}
          />
          <FieldError errors={[errors?.country_of_origin]} />
        </Field>
      </div>
      <Field>
        <FieldLabel htmlFor={fieldId(prefix, 'customs_description')}>
          {t('admin.fields.variant.customs_description.label')}
        </FieldLabel>
        <Controller
          name={path<TFieldValues>(prefix, 'customs_description')}
          control={form.control}
          render={({ field }) => (
            <Input
              id={fieldId(prefix, 'customs_description')}
              value={(field.value as string) ?? ''}
              onChange={(e) => field.onChange(normalizeCustomsDescription(e.target.value))}
              onBlur={field.onBlur}
            />
          )}
        />
        <FieldError errors={[errors?.customs_description]} />
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
      <div className="grid grid-cols-2 gap-3">
        <Field>
          <FieldLabel htmlFor={fieldId(prefix, 'minimum_order_quantity')}>
            {t('admin.fields.variant.minimum_order_quantity.label')}
          </FieldLabel>
          <Input
            id={fieldId(prefix, 'minimum_order_quantity')}
            type="number"
            min="1"
            {...form.register(path<TFieldValues>(prefix, 'minimum_order_quantity'))}
          />
          <FieldError errors={[errors?.minimum_order_quantity]} />
        </Field>
        <Field>
          <FieldLabel htmlFor={fieldId(prefix, 'order_multiple')}>
            {t('admin.fields.variant.order_multiple.label')}
          </FieldLabel>
          <Input
            id={fieldId(prefix, 'order_multiple')}
            type="number"
            min="1"
            {...form.register(path<TFieldValues>(prefix, 'order_multiple'))}
          />
          <FieldError errors={[errors?.order_multiple]} />
        </Field>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <Field>
          <FieldLabel htmlFor={fieldId(prefix, 'purchase_unit')}>
            {t('admin.fields.variant.purchase_unit.label')}
          </FieldLabel>
          <Controller
            name={path<TFieldValues>(prefix, 'purchase_unit')}
            control={form.control}
            render={({ field }) => (
              <Select
                items={PURCHASE_UNITS.map((unit) => ({
                  value: unit,
                  label: t(`admin.fields.variant.purchase_unit.options.${unit}`),
                }))}
                value={(field.value as string) ?? ''}
                onValueChange={field.onChange}
              >
                <SelectTrigger id={fieldId(prefix, 'purchase_unit')}>
                  <SelectValue />
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
          <FieldLabel htmlFor={fieldId(prefix, 'units_per_carton')}>
            {t('admin.fields.variant.units_per_carton.label')}
          </FieldLabel>
          <Input
            id={fieldId(prefix, 'units_per_carton')}
            type="number"
            min="1"
            {...form.register(path<TFieldValues>(prefix, 'units_per_carton'))}
          />
          <FieldError errors={[errors?.units_per_carton]} />
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

  return (
    <>
      <Field orientation="horizontal">
        <FieldLabel htmlFor={fieldId(prefix, 'track_inventory')}>
          {t('admin.fields.variant.track_inventory.label')}
        </FieldLabel>
        <Controller
          name={path<TFieldValues>(prefix, 'track_inventory')}
          control={form.control}
          render={({ field }) => (
            <Switch
              id={fieldId(prefix, 'track_inventory')}
              checked={!!field.value}
              onCheckedChange={field.onChange}
            />
          )}
        />
      </Field>

      <Field orientation="horizontal">
        <FieldLabel htmlFor={fieldId(prefix, 'preorderable')}>
          {t('admin.fields.variant.preorderable.label')}
        </FieldLabel>
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
      </Field>

      <Field>
        <FieldLabel htmlFor={fieldId(prefix, 'preorder_ships_at')}>
          {t('admin.fields.variant.preorder_ships_at.label')}
        </FieldLabel>
        <Controller
          name={path<TFieldValues>(prefix, 'preorder_ships_at')}
          control={form.control}
          render={({ field }) => (
            <StoreDatePicker
              inline
              includeTime
              value={(field.value as string) ?? null}
              onChange={(next) => field.onChange(next ?? null)}
              placeholder={t('admin.fields.variant.preorder_ships_at.placeholder')}
            />
          )}
        />
        <FieldError errors={[errors?.preorder_ships_at]} />
      </Field>

      <Field>
        <FieldLabel htmlFor={fieldId(prefix, 'backorder_limit')}>
          {t('admin.fields.variant.backorder_limit.label')}
        </FieldLabel>
        <Input
          id={fieldId(prefix, 'backorder_limit')}
          type="number"
          min="0"
          {...form.register(path<TFieldValues>(prefix, 'backorder_limit'))}
        />
        <FieldError errors={[errors?.backorder_limit]} />
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

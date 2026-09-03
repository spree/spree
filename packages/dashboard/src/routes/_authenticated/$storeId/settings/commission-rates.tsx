import { zodResolver } from '@hookform/resolvers/zod'
import type {
  CommissionRate,
  CommissionRateCreateParams,
  CommissionRuleType,
} from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  mapSpreeErrorsToForm,
  PreferencesForm,
  ResourceMultiAutocomplete,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
  useStore,
} from '@spree/dashboard-core'
import {
  Alert,
  AlertDescription,
  Button,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  InputGroupText,
  RowActions,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Switch,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { PlusIcon, Trash2Icon, TriangleAlertIcon } from '@spree/dashboard-ui/icons'
import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useEffect } from 'react'
import { Controller, type UseFormReturn, useFieldArray, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { commissionRuleSubjectPicker } from '../../../../components/spree/commission-rule-subjects'
import {
  useCommissionRate,
  useCommissionRuleTypes,
  useCreateCommissionRate,
  useDeleteCommissionRate,
  useUpdateCommissionRate,
} from '../../../../hooks/use-commission-rates'
import { slugify } from '../../../../lib/slugify'
import {
  COMMISSION_RATE_DEFAULTS,
  COMMISSION_RATE_KINDS,
  type CommissionRateFormValues,
  commissionRateFormSchema,
  commissionRateToFormValues,
  commissionRateValuesToParams,
} from '../../../../schemas/commission-rate'
import '../../../../tables/commission-rates'

const commissionRatesSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/commission-rates')({
  validateSearch: commissionRatesSearchSchema,
  component: CommissionRatesPage,
})

function CommissionRatesPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof commissionRatesSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteCommissionRate()
  const { permissions } = usePermissions()
  const queryClient = useQueryClient()

  const canUpdate = permissions.can('update', Subject.CommissionRate)
  // A deep link to ?edit= would otherwise open the sheet for someone who may
  // only read. The server refuses the write either way; this stops the form
  // being offered at all.
  const editId = canUpdate ? search.edit : undefined
  const isCreating = !!search.new

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { edit: _e, new: _n, ...rest } = prev
        return rest as never
      },
    })

  const openCreate = () =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })

  const openEdit = (id: string) =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, edit: id }) as never })

  useRowClickBridge('data-commission-rate-id', canUpdate ? openEdit : () => {})

  async function handleDelete(rate: CommissionRate) {
    const ok = await confirm({
      title: t('admin.commission_rates.delete_confirm.title'),
      message: t('admin.commission_rates.delete_confirm.message', { name: rate.name ?? '' }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(rate.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<CommissionRate>
        tableKey="commission-rates"
        queryKey="commission-rates"
        queryFn={(params) => adminClient.commissionRates.list(params)}
        searchParams={search}
        reorder={
          canUpdate
            ? {
                onReorder: async (id, position) => {
                  await adminClient.commissionRates.update(id, { position })
                  queryClient.invalidateQueries({ queryKey: ['commission-rates'] })
                },
              }
            : undefined
        }
        rowActions={(rate) => (
          <RowActions
            actions={[
              { key: 'edit', visible: canUpdate, onSelect: () => openEdit(rate.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.CommissionRate),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(rate),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.CommissionRate}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.commission_rates.add_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateCommissionRateSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && (
        <EditCommissionRateSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />
      )}
    </>
  )
}

function CreateCommissionRateSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateCommissionRate()
  const form = useForm<CommissionRateFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(commissionRateFormSchema) as any,
    defaultValues: COMMISSION_RATE_DEFAULTS,
  })

  async function onSubmit(values: CommissionRateFormValues) {
    try {
      await createMutation.mutateAsync(
        commissionRateValuesToParams(values) as CommissionRateCreateParams,
      )
      form.reset(COMMISSION_RATE_DEFAULTS)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(COMMISSION_RATE_DEFAULTS)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.settings.commission_rates.add_sheet_title')}</SheetTitle>
          <SheetDescription>
            {t('admin.commission_rates.create_description')}{' '}
            {t('admin.commission_rates.order_hint')}
          </SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <CommissionRateFormFields form={form} />
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting
                ? t('admin.actions.creating')
                : t('admin.commission_rates.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditCommissionRateSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: rate, isLoading } = useCommissionRate(id)
  const updateMutation = useUpdateCommissionRate(id)

  const form = useForm<CommissionRateFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(commissionRateFormSchema) as any,
    defaultValues: COMMISSION_RATE_DEFAULTS,
  })

  useEffect(() => {
    if (rate) form.reset(commissionRateToFormValues(rate))
  }, [rate, form])

  async function onSubmit(values: CommissionRateFormValues) {
    try {
      await updateMutation.mutateAsync(commissionRateValuesToParams(values))
      form.reset(values)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>
            {rate?.name ?? t('admin.pages.settings.commission_rates.edit_sheet_title')}
          </SheetTitle>
          <SheetDescription>{t('admin.commission_rates.edit_description')}</SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              <CommissionRateFormFields form={form} />
            </div>
            <SheetFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => onOpenChange(false)}
                disabled={form.formState.isSubmitting}
              >
                {t('admin.actions.cancel')}
              </Button>
              <Button
                type="submit"
                disabled={form.formState.isSubmitting || !form.formState.isDirty}
              >
                {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
              </Button>
            </SheetFooter>
          </form>
        )}
      </SheetContent>
    </Sheet>
  )
}

function CommissionRateFormFields({ form }: { form: UseFormReturn<CommissionRateFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const kind = form.watch('kind')
  const name = form.watch('name')
  // "Base Commission" becomes "base-commission" while the operator types, and
  // stops the moment they write a code of their own — matching how a channel's
  // code is derived.
  useEffect(() => {
    if (form.getFieldState('code').isDirty) return

    form.setValue('code', slugify(name ?? ''))
  }, [name, form])

  const kindOptions = COMMISSION_RATE_KINDS.map((value) => ({
    value,
    label: t(`admin.fields.commission_rate.kind.options.${value}`),
  }))

  return (
    <FieldGroup>
      {errors.root?.message && (
        <p className="text-sm text-destructive" role="alert">
          {errors.root.message}
        </p>
      )}

      <Field>
        <FieldLabel htmlFor="name">{t('admin.fields.name.label')}</FieldLabel>
        <Input
          id="name"
          autoFocus
          placeholder={t('admin.fields.commission_rate.name.placeholder')}
          aria-invalid={!!errors.name || undefined}
          {...form.register('name')}
        />
        <FieldError errors={[errors.name]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="code">{t('admin.fields.commission_rate.code.label')}</FieldLabel>
        <Input
          id="code"
          placeholder={t('admin.fields.commission_rate.code.placeholder')}
          aria-invalid={!!errors.code || undefined}
          {...form.register('code')}
        />
        <span className="text-xs text-muted-foreground">
          {t('admin.fields.commission_rate.code.help')}
        </span>
        <FieldError errors={[errors.code]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="kind">{t('admin.fields.commission_rate.kind.label')}</FieldLabel>
        <Controller
          name="kind"
          control={form.control}
          render={({ field }) => (
            <Select items={kindOptions} value={field.value} onValueChange={field.onChange}>
              <SelectTrigger id="kind">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {kindOptions.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
        />
      </Field>

      {kind === 'percentage' ? (
        <Field>
          <FieldLabel htmlFor="value">{t('admin.fields.commission_rate.value.label')}</FieldLabel>
          <InputGroup>
            <InputGroupInput
              id="value"
              type="number"
              step="0.01"
              min="0"
              max="100"
              aria-invalid={!!errors.value || undefined}
              {...form.register('value')}
            />
            <InputGroupAddon align="inline-end">
              <InputGroupText>%</InputGroupText>
            </InputGroupAddon>
          </InputGroup>
          <span className="text-xs text-muted-foreground">
            {t('admin.fields.commission_rate.value.help_percentage')}
          </span>
          <FieldError errors={[errors.value]} />
        </Field>
      ) : (
        <>
          <FlatFeeAmountsField form={form} />
          <FlatFeeCapField form={form} />
        </>
      )}

      <CommissionRulesField form={form} />

      {kind === 'percentage' && <PercentageBoundsField form={form} />}

      <Field>
        <FieldLabel htmlFor="commission_tax_rate">
          {t('admin.fields.commission_rate.commission_tax_rate.label')}
        </FieldLabel>
        <InputGroup>
          <InputGroupInput
            id="commission_tax_rate"
            type="number"
            step="0.01"
            min="0"
            placeholder={t('admin.fields.commission_rate.commission_tax_rate.placeholder')}
            {...form.register('commission_tax_rate')}
          />
          <InputGroupAddon align="inline-end">
            <InputGroupText>%</InputGroupText>
          </InputGroupAddon>
        </InputGroup>
        <span className="text-xs text-muted-foreground">
          {t('admin.fields.commission_rate.commission_tax_rate.help')}
        </span>
        <FieldError errors={[errors.commission_tax_rate]} />
      </Field>

      {/* A parcel is part of the sale a flat fee already charges for, so the
          same amount again would bill one sale twice. A marketplace wanting a
          flat charge on delivery states it as its own rate. */}
      {kind === 'percentage' && (
        <ToggleField
          form={form}
          name="include_shipping"
          label={t('admin.fields.commission_rate.include_shipping.label')}
          help={t('admin.fields.commission_rate.include_shipping.help')}
        />
      )}

      <ToggleField
        form={form}
        name="tax_inclusive"
        label={t('admin.fields.commission_rate.tax_inclusive.label')}
        help={t('admin.fields.commission_rate.tax_inclusive.help')}
      />

      <ToggleField
        form={form}
        name="enabled"
        label={t('admin.fields.enabled.label')}
        help={t('admin.fields.commission_rate.enabled.help')}
      />
    </FieldGroup>
  )
}

function ToggleField({
  form,
  name,
  label,
  help,
}: {
  form: UseFormReturn<CommissionRateFormValues>
  name: 'enabled' | 'tax_inclusive' | 'include_shipping'
  label: string
  help: string
}) {
  return (
    <Field>
      <div className="flex items-start justify-between gap-4">
        <div className="flex flex-col">
          <FieldLabel htmlFor={name} className="cursor-pointer">
            {label}
          </FieldLabel>
          <span className="text-xs text-muted-foreground">{help}</span>
        </div>
        <Controller
          name={name}
          control={form.control}
          render={({ field }) => (
            <Switch id={name} checked={!!field.value} onCheckedChange={field.onChange} />
          )}
        />
      </div>
    </Field>
  )
}

/**
 * What a flat fee charges, one field per currency the store sells in.
 *
 * No currency picker: a flat fee cannot travel the way a percentage can, and
 * a marketplace selling in three currencies needs an amount in each rather
 * than one figure and a conversion nobody asked for. A currency left empty is
 * one this rate does not charge — that sale falls through to the next rate.
 */
function FlatFeeAmountsField({ form }: { form: UseFormReturn<CommissionRateFormValues> }) {
  const { t } = useTranslation()
  const { currencies } = useStore()
  const amounts = form.watch('amounts')
  const hasAmount = Object.values(amounts ?? {}).some(
    (amount) => String(amount ?? '').trim() !== '',
  )

  return (
    <Field>
      <FieldLabel>{t('admin.fields.commission_rate.amounts.label')}</FieldLabel>
      <span className="text-xs text-muted-foreground">
        {t('admin.fields.commission_rate.amounts.help')}
      </span>
      {hasAmount && (
        <Alert variant="warning" className="mt-2">
          <TriangleAlertIcon />
          <AlertDescription>
            {t('admin.commission_rates.flat_fee_exceeds_sale_warning')}
          </AlertDescription>
        </Alert>
      )}
      <div className="flex flex-col gap-2 pt-1">
        {currencies.map((currency) => (
          <div key={currency} className="flex items-center gap-2">
            <span className="w-12 shrink-0 text-sm text-muted-foreground">{currency}</span>
            <Controller
              control={form.control}
              name="amounts"
              render={({ field }) => (
                <Input
                  type="number"
                  step="0.01"
                  min="0"
                  aria-label={currency}
                  value={(field.value?.[currency] as string) ?? ''}
                  onChange={(event) =>
                    field.onChange({ ...field.value, [currency]: event.target.value })
                  }
                />
              )}
            />
          </div>
        ))}
      </div>
    </Field>
  )
}

/**
 * Optional cap on a flat fee per sale line. The engine already clamps the
 * computed fee to this ceiling — surfacing it here is what makes a minimum
 * fee larger than a cheap item's price a deliberate choice rather than a
 * silent overcharge.
 */
function FlatFeeCapField({ form }: { form: UseFormReturn<CommissionRateFormValues> }) {
  const { t } = useTranslation()
  const { currencies } = useStore()

  return (
    <Field>
      <FieldLabel>{t('admin.fields.commission_rate.flat_fee_cap.label')}</FieldLabel>
      <span className="text-xs text-muted-foreground">
        {t('admin.fields.commission_rate.flat_fee_cap.help')}
      </span>
      <div className="flex flex-col gap-2 pt-1">
        {currencies.map((currency) => (
          <div key={currency} className="flex items-center gap-2">
            <span className="w-12 shrink-0 text-sm text-muted-foreground">{currency}</span>
            <Controller
              control={form.control}
              name="bounds"
              render={({ field }) => {
                const bound = field.value?.[currency] ?? { min_amount: '', max_amount: '' }

                return (
                  <Input
                    type="number"
                    step="0.01"
                    min="0"
                    aria-label={`${currency} ${t('admin.fields.commission_rate.max_amount.label')}`}
                    placeholder={t('admin.fields.commission_rate.max_amount.label')}
                    value={bound.max_amount}
                    onChange={(event) =>
                      field.onChange({
                        ...field.value,
                        [currency]: { ...bound, max_amount: event.target.value },
                      })
                    }
                  />
                )
              }}
            />
          </div>
        ))}
      </div>
    </Field>
  )
}

/**
 * Optional bounds on a percentage: never charge less than this, never more
 * than that. Amounts, so they carry a currency of their own — which is what
 * stops "at least 5" meaning five of whatever the buyer happened to pay in.
 */
/**
 * A floor and a cap per currency, on the same one-row-per-currency footing as
 * the flat fee. Each bound holds only in its own currency — a sale in a
 * currency left blank is charged unbounded rather than against a converted
 * figure the merchant never agreed to.
 */
function PercentageBoundsField({ form }: { form: UseFormReturn<CommissionRateFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const { currencies } = useStore()

  return (
    <Field>
      <FieldLabel>{t('admin.fields.commission_rate.bounds.label')}</FieldLabel>
      <span className="text-xs text-muted-foreground">
        {t('admin.fields.commission_rate.bounds.help')}
      </span>
      <div className="flex flex-col gap-2 pt-1">
        {currencies.map((currency) => (
          <div key={currency} className="flex items-center gap-2">
            <span className="w-12 shrink-0 text-sm text-muted-foreground">{currency}</span>
            <Controller
              control={form.control}
              name="bounds"
              render={({ field }) => {
                const bound = field.value?.[currency] ?? { min_amount: '', max_amount: '' }
                const write = (key: 'min_amount' | 'max_amount', amount: string) =>
                  field.onChange({ ...field.value, [currency]: { ...bound, [key]: amount } })

                return (
                  <>
                    <Input
                      type="number"
                      step="0.01"
                      min="0"
                      aria-label={`${currency} ${t('admin.fields.commission_rate.min_amount.label')}`}
                      placeholder={t('admin.fields.commission_rate.min_amount.label')}
                      value={bound.min_amount}
                      onChange={(event) => write('min_amount', event.target.value)}
                    />
                    <span className="text-sm text-muted-foreground">–</span>
                    <Input
                      type="number"
                      step="0.01"
                      min="0"
                      aria-label={`${currency} ${t('admin.fields.commission_rate.max_amount.label')}`}
                      placeholder={t('admin.fields.commission_rate.max_amount.label')}
                      value={bound.max_amount}
                      onChange={(event) => write('max_amount', event.target.value)}
                    />
                  </>
                )
              }}
            />
          </div>
        ))}
      </div>
      <FieldError errors={[errors.bounds]} />
    </Field>
  )
}

/**
 * The rate's conditions.
 *
 * Every condition has to hold for the rate to apply, and a condition naming
 * several records means any of them — so "cameras or audio, from that seller"
 * is two conditions. A rate with none charges every sale, which the empty
 * state says outright.
 *
 * Built from the rule kinds the marketplace reports rather than a list baked
 * in here, so a kind added by an extension appears without a change to this
 * file. Kinds already used drop out of the picker: a second condition of the
 * same kind would repeat the first or contradict it.
 */
function CommissionRulesField({ form }: { form: UseFormReturn<CommissionRateFormValues> }) {
  const { t } = useTranslation()
  const { data: ruleTypes } = useCommissionRuleTypes()
  const rulesArray = useFieldArray<CommissionRateFormValues, 'rules', '_key'>({
    control: form.control,
    name: 'rules',
    keyName: '_key',
  })

  const usedTypes = new Set(rulesArray.fields.map((rule) => rule.type))
  const availableTypes = (ruleTypes?.data ?? []).filter((type) => !usedTypes.has(type.type))

  return (
    <Field>
      <div className="flex items-center justify-between">
        <FieldLabel>{t('admin.fields.commission_rate.rules.label')}</FieldLabel>
        {availableTypes.length > 0 && (
          <DropdownMenu>
            <DropdownMenuTrigger
              render={
                <Button type="button" variant="outline" size="sm">
                  <PlusIcon className="size-4" />
                  {t('admin.commission_rates.conditions.add')}
                </Button>
              }
            />
            <DropdownMenuContent align="end">
              {availableTypes.map((type) => (
                <DropdownMenuItem
                  key={type.type}
                  onClick={() =>
                    rulesArray.append({ type: type.type, preferences: {}, product_ids: [] })
                  }
                >
                  {type.name}
                </DropdownMenuItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
        )}
      </div>
      <span className="text-xs text-muted-foreground">
        {t('admin.fields.commission_rate.rules.help')}
      </span>

      <div className="flex flex-col gap-3 pt-1">
        {rulesArray.fields.length === 0 && (
          <span className="text-xs text-muted-foreground">
            {t('admin.commission_rates.applies_to_everything')}
          </span>
        )}

        {rulesArray.fields.map((field, index) => (
          <CommissionRuleRow
            key={field._key}
            form={form}
            index={index}
            ruleType={(ruleTypes?.data ?? []).find((candidate) => candidate.type === field.type)}
            fallbackLabel={field.type}
            onRemove={() => rulesArray.remove(index)}
          />
        ))}
      </div>
    </Field>
  )
}

/**
 * One condition. What it renders is decided by what the server said about the
 * kind: a condition naming records gets that resource's picker, and anything
 * else renders its own preference schema — so a value band needs no code here.
 */
function CommissionRuleRow({
  form,
  index,
  ruleType,
  fallbackLabel,
  onRemove,
}: {
  form: UseFormReturn<CommissionRateFormValues>
  index: number
  ruleType?: CommissionRuleType
  fallbackLabel: string
  onRemove: () => void
}) {
  const { t } = useTranslation()
  const schema = ruleType?.preference_schema ?? []
  // Catalog-scale references arrive as their own field; everything else names
  // records through an id list in preferences. Either way the picker comes
  // from the registry, keyed by rule kind.
  const picker = ruleType ? commissionRuleSubjectPicker(ruleType.type) : undefined
  const associationField = ruleType?.association_fields?.[0]
  const preferenceIdKey = schema.find((preference) => preference.key.endsWith('_ids'))?.key

  return (
    <div className="flex flex-col gap-2 rounded-md border p-3">
      <div className="flex items-center justify-between">
        <div className="flex flex-col">
          <span className="text-sm">{ruleType?.name ?? fallbackLabel}</span>
          {ruleType?.description && (
            <span className="text-xs text-muted-foreground">{ruleType.description}</span>
          )}
        </div>
        <Button
          type="button"
          variant="ghost"
          size="icon-sm"
          onClick={onRemove}
          aria-label={t('admin.actions.delete')}
        >
          <Trash2Icon className="size-4" />
        </Button>
      </div>

      {picker && associationField ? (
        <Controller
          control={form.control}
          name={`rules.${index}.product_ids`}
          render={({ field }) => (
            <ResourceMultiAutocomplete
              {...picker(`commission-rule-${ruleType?.type}`)}
              value={field.value ?? []}
              onChange={field.onChange}
            />
          )}
        />
      ) : picker && preferenceIdKey ? (
        <Controller
          control={form.control}
          name={`rules.${index}.preferences`}
          render={({ field }) => (
            <ResourceMultiAutocomplete
              {...picker(`commission-rule-${ruleType?.type}`)}
              value={(field.value?.[preferenceIdKey] ?? []) as string[]}
              onChange={(ids: string[]) =>
                field.onChange({ ...field.value, [preferenceIdKey]: ids })
              }
            />
          )}
        />
      ) : (
        <Controller
          control={form.control}
          name={`rules.${index}.preferences`}
          render={({ field }) => (
            <PreferencesForm schema={schema} values={field.value} onChange={field.onChange} />
          )}
        />
      )}
    </div>
  )
}

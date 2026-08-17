import { zodResolver } from '@hookform/resolvers/zod'
import type { CommissionRate, CommissionRateCreateParams } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  mapSpreeErrorsToForm,
  ResourceMultiAutocomplete,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
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
import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useEffect } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { commissionRuleSubjectPicker } from '../../../../components/spree/commission-rule-subjects'
import {
  useCommissionRate,
  useCommissionRuleSubjectTypes,
  useCreateCommissionRate,
  useDeleteCommissionRate,
  useUpdateCommissionRate,
} from '../../../../hooks/use-commission-rates'
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
              size="sm"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
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
                size="sm"
                onClick={() => onOpenChange(false)}
                disabled={form.formState.isSubmitting}
              >
                {t('admin.actions.cancel')}
              </Button>
              <Button
                type="submit"
                size="sm"
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

      <Field>
        <FieldLabel htmlFor="value">{t('admin.fields.commission_rate.value.label')}</FieldLabel>
        <Input
          id="value"
          type="number"
          step="0.01"
          min="0"
          aria-invalid={!!errors.value || undefined}
          {...form.register('value')}
        />
        <span className="text-xs text-muted-foreground">
          {t(`admin.fields.commission_rate.value.help_${kind}`)}
        </span>
        <FieldError errors={[errors.value]} />
      </Field>

      {/* A percentage travels across currencies; only a flat fee needs one. */}
      {kind === 'fixed' && (
        <Field>
          <FieldLabel htmlFor="currency">{t('admin.fields.currency.label')}</FieldLabel>
          <Input
            id="currency"
            placeholder="USD"
            aria-invalid={!!errors.currency || undefined}
            {...form.register('currency')}
          />
          <FieldError errors={[errors.currency]} />
        </Field>
      )}

      <CommissionRulesField form={form} />

      <div className="grid grid-cols-2 gap-4">
        <Field>
          <FieldLabel htmlFor="min_amount">
            {t('admin.fields.commission_rate.min_amount.label')}
          </FieldLabel>
          <Input
            id="min_amount"
            type="number"
            step="0.01"
            min="0"
            {...form.register('min_amount')}
          />
          <FieldError errors={[errors.min_amount]} />
        </Field>
        <Field>
          <FieldLabel htmlFor="max_amount">
            {t('admin.fields.commission_rate.max_amount.label')}
          </FieldLabel>
          <Input
            id="max_amount"
            type="number"
            step="0.01"
            min="0"
            {...form.register('max_amount')}
          />
          <FieldError errors={[errors.max_amount]} />
        </Field>
      </div>

      <Field>
        <FieldLabel htmlFor="commission_tax_rate">
          {t('admin.fields.commission_rate.commission_tax_rate.label')}
        </FieldLabel>
        <Input
          id="commission_tax_rate"
          type="number"
          step="0.01"
          min="0"
          placeholder={t('admin.fields.commission_rate.commission_tax_rate.placeholder')}
          {...form.register('commission_tax_rate')}
        />
        <span className="text-xs text-muted-foreground">
          {t('admin.fields.commission_rate.commission_tax_rate.help')}
        </span>
        <FieldError errors={[errors.commission_tax_rate]} />
      </Field>

      <ToggleField
        form={form}
        name="include_shipping"
        label={t('admin.fields.commission_rate.include_shipping.label')}
        help={t('admin.fields.commission_rate.include_shipping.help')}
      />

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
 * The rate's targeting, one picker per dimension.
 *
 * Grouping the pickers by subject type is what makes the matching rule
 * legible: everything picked inside one box is an alternative, and every box
 * that holds something has to match. A rate with all three empty applies to
 * every sale, which the empty state says outright.
 */
function CommissionRulesField({ form }: { form: UseFormReturn<CommissionRateFormValues> }) {
  const { t } = useTranslation()
  const { data: subjectTypes } = useCommissionRuleSubjectTypes()
  const rules = form.watch('rules') ?? []

  function idsFor(subjectType: string) {
    return rules.filter((rule) => rule.subject_type === subjectType).map((rule) => rule.subject_id)
  }

  function setIdsFor(subjectType: string, ids: string[]) {
    const others = rules.filter((rule) => rule.subject_type !== subjectType)
    form.setValue(
      'rules',
      [...others, ...ids.map((id) => ({ subject_type: subjectType, subject_id: id }))],
      { shouldDirty: true },
    )
  }

  return (
    <Field>
      <FieldLabel>{t('admin.fields.commission_rate.rules.label')}</FieldLabel>
      <span className="text-xs text-muted-foreground">
        {t('admin.fields.commission_rate.rules.help')}
      </span>
      <div className="flex flex-col gap-3 pt-1">
        {(subjectTypes?.data ?? []).map((subjectType) => {
          const picker = commissionRuleSubjectPicker(subjectType.type)

          return (
            <div key={subjectType.type} className="flex flex-col gap-1">
              <span className="text-xs font-medium">{subjectType.name}</span>
              {picker ? (
                <ResourceMultiAutocomplete
                  {...picker(`commission-rule-${subjectType.type}`)}
                  value={idsFor(subjectType.type)}
                  onChange={(ids: string[]) => setIdsFor(subjectType.type, ids)}
                />
              ) : (
                // The server can offer a dimension this build has no picker
                // for. Saying so beats rendering nothing, which reads as the
                // dimension not existing.
                <span className="text-xs text-muted-foreground">
                  {t('admin.commission_rates.rule_picker_unavailable')}
                </span>
              )}
            </div>
          )
        })}
        {rules.length === 0 && (
          <span className="text-xs text-muted-foreground">
            {t('admin.commission_rates.applies_to_everything')}
          </span>
        )}
      </div>
    </Field>
  )
}

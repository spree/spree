import { zodResolver } from '@hookform/resolvers/zod'
import type { Market } from '@spree/admin-sdk'
import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useEffect, useMemo } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { adminClient } from '@/client'
import { Can } from '@/components/spree/can'
import { useConfirm } from '@/components/spree/confirm-dialog'
import { CountryMultiCombobox } from '@/components/spree/country-combobox'
import { CurrencySelect } from '@/components/spree/currency-select'
import { LocaleSelect } from '@/components/spree/locale-select'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
import { RowActions } from '@/components/spree/row-actions'
import { useRowClickBridge } from '@/components/spree/row-click-bridge'
import { Button } from '@/components/ui/button'
import { Field, FieldError, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'
import { Switch } from '@/components/ui/switch'
import {
  marketsQueryKey,
  useCreateMarket,
  useDeleteMarket,
  useMarket,
  useUpdateMarket,
} from '@/hooks/use-markets'
import { mapSpreeErrorsToForm } from '@/lib/form-errors'
import { Subject } from '@/lib/permissions'
import { usePermissions } from '@/providers/permission-provider'
import { useStore } from '@/providers/store-provider'
import {
  MARKET_DEFAULTS,
  type MarketFormValues,
  marketFormSchema,
  marketValuesToParams,
} from '@/schemas/market'
import '@/tables/markets'

const marketsSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/markets')({
  validateSearch: marketsSearchSchema,
  component: MarketsPage,
})

function MarketsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof marketsSearchSchema>
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const confirm = useConfirm()
  const deleteMutation = useDeleteMarket()
  const { permissions } = usePermissions()

  const editId = search.edit
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

  useRowClickBridge('data-market-id', openEdit)

  async function handleDelete(market: Market) {
    const ok = await confirm({
      title: t('admin.markets.delete_confirm.title'),
      message: t('admin.markets.delete_confirm.message', { name: market.name ?? '' }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(market.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<Market>
        tableKey="markets"
        queryKey="markets"
        queryFn={(params) => adminClient.markets.list(params)}
        searchParams={search}
        rowActions={(market) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(market.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.Market),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(market),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.Market}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.markets.add_cta')}
            </Button>
          </Can>
        }
        reorder={{
          onReorder: async (id, position) => {
            await adminClient.markets.update(id, { position })
            queryClient.invalidateQueries({ queryKey: marketsQueryKey })
          },
        }}
      />

      {isCreating && <CreateMarketSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && <EditMarketSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />}
    </>
  )
}

function CreateMarketSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateMarket()
  const { defaultCurrency, defaultLocale } = useStore()

  // Seed the form with the store defaults so a typical "Europe" / "ROW"
  // setup is mostly pre-filled — the merchant only edits name + countries.
  const initialDefaults: MarketFormValues = useMemo(
    () => ({
      ...MARKET_DEFAULTS,
      currency: defaultCurrency,
      default_locale: defaultLocale,
    }),
    [defaultCurrency, defaultLocale],
  )

  const form = useForm<MarketFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(marketFormSchema) as any,
    defaultValues: initialDefaults,
  })

  async function onSubmit(values: MarketFormValues) {
    try {
      await createMutation.mutateAsync(marketValuesToParams(values))
      form.reset(initialDefaults)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(initialDefaults)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.settings.markets.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.markets.create_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <MarketFormFields form={form} />
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
                : t('admin.markets.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditMarketSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: market, isLoading } = useMarket(id)
  const updateMutation = useUpdateMarket(id)

  const form = useForm<MarketFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(marketFormSchema) as any,
    defaultValues: MARKET_DEFAULTS,
  })

  useEffect(() => {
    if (market) {
      form.reset({
        name: market.name,
        currency: market.currency,
        default_locale: market.default_locale,
        supported_locales: market.supported_locales.filter((l) => l !== market.default_locale),
        tax_inclusive: market.tax_inclusive,
        default: market.default,
        country_isos: market.country_isos,
      })
    }
  }, [market, form])

  async function onSubmit(values: MarketFormValues) {
    try {
      await updateMutation.mutateAsync(marketValuesToParams(values))
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
            {market?.name ?? t('admin.pages.settings.markets.edit_sheet_title')}
          </SheetTitle>
          <SheetDescription>{t('admin.markets.edit_description')}</SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              <MarketFormFields form={form} />
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

function MarketFormFields({ form }: { form: UseFormReturn<MarketFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const defaultLocaleField = form.watch('default_locale')

  return (
    <FieldGroup>
      {errors.root?.message && (
        <p className="text-sm text-destructive" role="alert">
          {errors.root.message}
        </p>
      )}

      <Field>
        <FieldLabel htmlFor="market-name">{t('admin.fields.name.label')}</FieldLabel>
        <Input
          id="market-name"
          autoFocus
          placeholder={t('admin.fields.market.name.placeholder')}
          aria-invalid={!!errors.name || undefined}
          {...form.register('name')}
        />
        <FieldError errors={[errors.name]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="market-currency">{t('admin.fields.market.currency.label')}</FieldLabel>
        <Controller
          name="currency"
          control={form.control}
          render={({ field }) => (
            <CurrencySelect id="market-currency" value={field.value} onChange={field.onChange} />
          )}
        />
        <span className="text-xs text-muted-foreground">
          {t('admin.fields.market.currency.help')}
        </span>
        <FieldError errors={[errors.currency]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="market-default-locale">
          {t('admin.fields.market.default_locale.label')}
        </FieldLabel>
        <Controller
          name="default_locale"
          control={form.control}
          render={({ field }) => (
            <LocaleSelect
              id="market-default-locale"
              value={field.value}
              onChange={field.onChange}
            />
          )}
        />
        <span className="text-xs text-muted-foreground">
          {t('admin.fields.market.default_locale.help')}
        </span>
        <FieldError errors={[errors.default_locale]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="market-supported-locales">
          {t('admin.fields.market.supported_locales.label')}
        </FieldLabel>
        <Controller
          name="supported_locales"
          control={form.control}
          render={({ field }) => (
            <LocaleSelect
              multiple
              id="market-supported-locales"
              value={field.value}
              onChange={field.onChange}
              excludeCode={defaultLocaleField}
            />
          )}
        />
        <span className="text-xs text-muted-foreground">
          {t('admin.fields.market.supported_locales.help')}
        </span>
      </Field>

      <Field>
        <FieldLabel htmlFor="market-countries">
          {t('admin.fields.market.country_isos.label')}
        </FieldLabel>
        <Controller
          name="country_isos"
          control={form.control}
          render={({ field }) => (
            <CountryMultiCombobox value={field.value} onValueChange={field.onChange} />
          )}
        />
        <span className="text-xs text-muted-foreground">
          {t('admin.fields.market.country_isos.help')}
        </span>
        <FieldError errors={[errors.country_isos]} />
      </Field>

      <Field>
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col">
            <FieldLabel htmlFor="market-tax-inclusive" className="cursor-pointer">
              {t('admin.fields.market.tax_inclusive.label')}
            </FieldLabel>
            <span className="text-xs text-muted-foreground">
              {t('admin.fields.market.tax_inclusive.help')}
            </span>
          </div>
          <Controller
            name="tax_inclusive"
            control={form.control}
            render={({ field }) => (
              <Switch
                id="market-tax-inclusive"
                checked={!!field.value}
                onCheckedChange={field.onChange}
              />
            )}
          />
        </div>
      </Field>

      <Field>
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col">
            <FieldLabel htmlFor="market-default" className="cursor-pointer">
              {t('admin.fields.market.default.label')}
            </FieldLabel>
            <span className="text-xs text-muted-foreground">
              {t('admin.fields.market.default.help')}
            </span>
          </div>
          <Controller
            name="default"
            control={form.control}
            render={({ field }) => (
              <Switch
                id="market-default"
                checked={!!field.value}
                onCheckedChange={field.onChange}
              />
            )}
          />
        </div>
      </Field>
    </FieldGroup>
  )
}

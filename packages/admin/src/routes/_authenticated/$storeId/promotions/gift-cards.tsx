import { zodResolver } from '@hookform/resolvers/zod'
import type { Customer, GiftCard } from '@spree/admin-sdk'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useEffect, useRef } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { Can } from '@/components/spree/can'
import { useConfirm } from '@/components/spree/confirm-dialog'
import { CurrencySelect } from '@/components/spree/currency-select'
import { ResourceCombobox } from '@/components/spree/resource-combobox'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
import { RowActions } from '@/components/spree/row-actions'
import { useRowClickBridge } from '@/components/spree/row-click-bridge'
import { StoreDatePicker } from '@/components/spree/store-date-picker'
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
import { customerAutocompleteProps } from '@/hooks/use-customers'
import {
  listGiftCards,
  useCreateGiftCard,
  useCreateGiftCardBatch,
  useDeleteGiftCard,
  useGiftCard,
  useUpdateGiftCard,
} from '@/hooks/use-gift-cards'
import { mapSpreeErrorsToForm } from '@/lib/form-errors'
import { Subject } from '@/lib/permissions'
import { usePermissions } from '@/providers/permission-provider'
import { useStore } from '@/providers/store-provider'
import {
  BATCH_LIMIT,
  type GiftCardCreateFormValues,
  type GiftCardEditFormValues,
  giftCardBatchValuesToParams,
  giftCardCreateFormSchema,
  giftCardEditFormSchema,
  giftCardEditValuesToParams,
  giftCardSingleValuesToParams,
} from '@/schemas/gift-card'
import '@/tables/gift-cards'

const giftCardsSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/promotions/gift-cards')({
  validateSearch: giftCardsSearchSchema,
  component: GiftCardsPage,
})

// `customer` chips on every row need the customer association inlined;
// `created_by` is shown in the edit sheet; `gift_card_batch` powers the
// per-row batch chip + filter. Pulling them on the index keeps the table
// self-sufficient without a follow-up fetch per row.
const LIST_EXPAND = ['customer', 'created_by', 'gift_card_batch']

function GiftCardsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof giftCardsSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteGiftCard()
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

  useRowClickBridge('data-gift-card-id', openEdit)

  async function handleDelete(giftCard: GiftCard) {
    const ok = await confirm({
      title: t('admin.pages.promotions.gift_cards.delete_confirm.title'),
      message: t('admin.pages.promotions.gift_cards.delete_confirm.message'),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(giftCard.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<GiftCard>
        tableKey="gift-cards"
        queryKey="gift-cards"
        queryFn={listGiftCards}
        searchParams={search}
        defaultParams={{ expand: LIST_EXPAND }}
        rowActions={(giftCard) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(giftCard.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.GiftCard),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(giftCard),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.GiftCard}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.pages.promotions.gift_cards.new_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateGiftCardSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && <EditGiftCardSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />}
    </>
  )
}

// ----------------------------------------------------------------------------
// Create sheet — single sheet for both single-issue and batch-issue. The
// flow branches off `quantity`: `1` posts to `/gift_cards`; `>1` posts to
// `/gift_card_batches` (server generates `codes_count` cards).
// ----------------------------------------------------------------------------

function CreateGiftCardSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateGiftCard()
  const createBatchMutation = useCreateGiftCardBatch()
  // `CurrencySelect` falls back to the store default visually, but we have to
  // seed `currency` here too so react-hook-form's validator doesn't reject
  // the submit on a blank string before `mutate` ever runs.
  const { defaultCurrency } = useStore()
  const form = useForm<GiftCardCreateFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(giftCardCreateFormSchema) as any,
    defaultValues: {
      code: '',
      // Empty so the input shows its placeholder; zod's `z.coerce.number()`
      // parses on submit and rejects blanks via `positive()`.
      amount: '' as unknown as number,
      currency: defaultCurrency,
      expires_at: '',
      customer_id: '',
      quantity: 1,
    },
  })

  const quantity = form.watch('quantity')
  const isBatch = Number(quantity) > 1

  async function onSubmit(values: GiftCardCreateFormValues) {
    try {
      if (Number(values.quantity) > 1) {
        await createBatchMutation.mutateAsync(giftCardBatchValuesToParams(values))
      } else {
        await createMutation.mutateAsync(giftCardSingleValuesToParams(values))
      }
      form.reset()
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset()
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.promotions.gift_cards.new_sheet_title')}</SheetTitle>
          <SheetDescription>
            {t('admin.pages.promotions.gift_cards.sheet.create_description')}
          </SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            {form.formState.errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {form.formState.errors.root.message}
              </p>
            )}
            <CreateGiftCardFormFields form={form} isBatch={isBatch} />
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
                : isBatch
                  ? t('admin.pages.promotions.gift_cards.create_batch_cta', { count: quantity })
                  : t('admin.pages.promotions.gift_cards.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

// ----------------------------------------------------------------------------
// Edit sheet
// ----------------------------------------------------------------------------

function EditGiftCardSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: giftCard, isLoading } = useGiftCard(id, ['customer', 'created_by', 'orders'])
  const updateMutation = useUpdateGiftCard(id)

  const form = useForm<GiftCardEditFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(giftCardEditFormSchema) as any,
    defaultValues: {
      code: '',
      amount: 0,
      currency: '',
      expires_at: '',
      customer_id: '',
    },
  })

  // Reset only when the *record identity* changes (or the form is pristine)
  // so a background refetch can't clobber unsaved edits in the sheet.
  const prevGiftCardIdRef = useRef<string | undefined>(undefined)
  useEffect(() => {
    if (!giftCard) return
    const idChanged = giftCard.id !== prevGiftCardIdRef.current
    if (idChanged || !form.formState.isDirty) {
      prevGiftCardIdRef.current = giftCard.id
      form.reset({
        code: giftCard.code,
        amount: Number(giftCard.amount),
        currency: giftCard.currency,
        expires_at: giftCard.expires_at ?? '',
        customer_id: giftCard.customer?.id ?? '',
      })
    }
  }, [giftCard, form])

  async function onSubmit(values: GiftCardEditFormValues) {
    try {
      await updateMutation.mutateAsync(giftCardEditValuesToParams(values))
      form.reset(values)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  // Server-side `editable?` is `active?` — redeemed/canceled cards are
  // read-only. Don't even show the form for those; let staff see the audit
  // info only.
  const editable = giftCard?.active ?? false

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>
            {giftCard?.code ?? t('admin.pages.promotions.gift_cards.edit_sheet_title')}
          </SheetTitle>
          <SheetDescription>
            {t('admin.pages.promotions.gift_cards.sheet.edit_description')}
          </SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
        ) : !giftCard ? (
          <div className="p-4 text-sm text-muted-foreground">
            {t('admin.pages.promotions.gift_cards.not_found')}
          </div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              {form.formState.errors.root?.message && (
                <p className="text-sm text-destructive" role="alert">
                  {form.formState.errors.root.message}
                </p>
              )}
              <EditGiftCardFormFields form={form} readOnly={!editable} />
              <GiftCardUsageSummary giftCard={giftCard} />
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
                disabled={!editable || form.formState.isSubmitting || !form.formState.isDirty}
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

// ----------------------------------------------------------------------------
// Form fields
// ----------------------------------------------------------------------------

function CustomerPickerController({
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form,
  readOnly = false,
}: {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: any
  readOnly?: boolean
}) {
  const { t } = useTranslation()
  return (
    <Controller
      name="customer_id"
      control={form.control}
      render={({ field }) =>
        readOnly ? (
          <div className="text-sm text-muted-foreground">
            {field.value || t('admin.pages.promotions.gift_cards.no_customer')}
          </div>
        ) : (
          <ResourceCombobox<Customer>
            {...customerAutocompleteProps('customer-picker')}
            value={field.value || undefined}
            onChange={(id) => field.onChange(id ?? '')}
            renderOption={(c) => (
              <div>
                <div className="font-medium">{c.email}</div>
                {(c.first_name || c.last_name) && (
                  <div className="text-xs text-muted-foreground">{c.full_name}</div>
                )}
              </div>
            )}
          />
        )
      }
    />
  )
}

function AmountCurrencyRow<T extends GiftCardCreateFormValues | GiftCardEditFormValues>({
  form,
  readOnly,
  currencyLocked,
}: {
  form: UseFormReturn<T>
  readOnly: boolean
  /** True on edit — currency can't change after creation. */
  currencyLocked: boolean
}) {
  const { t } = useTranslation()
  const errors = form.formState.errors as Record<string, { message?: string } | undefined>
  return (
    <div className="grid grid-cols-2 gap-3">
      <Field>
        <FieldLabel htmlFor="amount">{t('admin.fields.gift_card.amount.label')}</FieldLabel>
        <Input
          id="amount"
          type="number"
          step="0.01"
          min={0}
          disabled={readOnly}
          aria-invalid={!!errors.amount || undefined}
          {...form.register('amount' as never)}
        />
        <FieldError errors={[errors.amount]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="currency">{t('admin.fields.gift_card.currency.label')}</FieldLabel>
        <Controller
          name={'currency' as never}
          control={form.control}
          render={({ field }) => (
            <CurrencySelect
              id="currency"
              value={(field.value as string) || undefined}
              onChange={field.onChange}
              disabled={readOnly || currencyLocked}
            />
          )}
        />
      </Field>
    </div>
  )
}

function CreateGiftCardFormFields({
  form,
  isBatch,
}: {
  form: UseFormReturn<GiftCardCreateFormValues>
  isBatch: boolean
}) {
  const { t } = useTranslation()
  const { errors } = form.formState
  return (
    <FieldGroup>
      <Field>
        <FieldLabel htmlFor="quantity">{t('admin.fields.gift_card.quantity.label')}</FieldLabel>
        <Input
          id="quantity"
          type="number"
          min={1}
          max={BATCH_LIMIT}
          step={1}
          aria-invalid={!!errors.quantity || undefined}
          {...form.register('quantity')}
        />
        <p className="text-xs text-muted-foreground">{t('admin.fields.gift_card.quantity.help')}</p>
        <FieldError errors={[errors.quantity]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="code">
          {isBatch
            ? t('admin.pages.promotions.gift_cards.prefix.label')
            : t('admin.fields.gift_card.code.label')}
        </FieldLabel>
        <Input
          id="code"
          placeholder={t(
            isBatch
              ? 'admin.pages.promotions.gift_cards.prefix.placeholder'
              : 'admin.pages.promotions.gift_cards.prefix.auto_placeholder',
          )}
          aria-invalid={!!errors.code || undefined}
          {...form.register('code')}
        />
        {!isBatch && (
          <p className="text-xs text-muted-foreground">{t('admin.fields.gift_card.code.help')}</p>
        )}
        <FieldError errors={[errors.code]} />
      </Field>

      <AmountCurrencyRow form={form} readOnly={false} currencyLocked={false} />

      <Field>
        <FieldLabel htmlFor="expires_at">{t('admin.fields.gift_card.expires_at.label')}</FieldLabel>
        <Controller
          name="expires_at"
          control={form.control}
          render={({ field }) => (
            <StoreDatePicker
              value={field.value || null}
              onChange={(next) => field.onChange(next ?? '')}
              placeholder={t('admin.fields.gift_card.expires_at.placeholder')}
              inline
            />
          )}
        />
        <FieldError errors={[form.formState.errors.expires_at]} />
      </Field>

      {/* A single customer can't be attached to a whole batch — hide the
          field in batch mode to make the difference obvious. */}
      {!isBatch && (
        <Field>
          <FieldLabel>{`${t('admin.fields.gift_card.customer_id.label')} (${t('admin.common.optional').toLowerCase()})`}</FieldLabel>
          <CustomerPickerController form={form} />
          <FieldError errors={[errors.customer_id]} />
        </Field>
      )}
    </FieldGroup>
  )
}

function EditGiftCardFormFields({
  form,
  readOnly = false,
}: {
  form: UseFormReturn<GiftCardEditFormValues>
  readOnly?: boolean
}) {
  const { t } = useTranslation()
  return (
    <FieldGroup>
      <AmountCurrencyRow form={form} readOnly={readOnly} currencyLocked />

      <Field>
        <FieldLabel htmlFor="expires_at">{t('admin.fields.gift_card.expires_at.label')}</FieldLabel>
        <Controller
          name="expires_at"
          control={form.control}
          render={({ field }) => (
            <StoreDatePicker
              value={field.value || null}
              onChange={(next) => field.onChange(next ?? '')}
              placeholder={t('admin.fields.gift_card.expires_at.placeholder')}
              disabled={readOnly}
              inline
            />
          )}
        />
        <FieldError errors={[form.formState.errors.expires_at]} />
      </Field>

      <Field>
        <FieldLabel>{`${t('admin.fields.gift_card.customer_id.label')} (${t('admin.common.optional').toLowerCase()})`}</FieldLabel>
        <CustomerPickerController form={form} readOnly={readOnly} />
        <FieldError
          errors={[
            (form.formState.errors as Record<string, { message?: string } | undefined>).customer_id,
          ]}
        />
      </Field>
    </FieldGroup>
  )
}

// ----------------------------------------------------------------------------
// Usage summary — shown inside the edit sheet so staff can see redemption
// progress without leaving the modal.
// ----------------------------------------------------------------------------

function GiftCardUsageSummary({ giftCard }: { giftCard: GiftCard }) {
  const { t } = useTranslation()
  return (
    <div className="rounded-md border bg-muted/30 p-3 text-sm">
      <div className="mb-2 font-medium">{t('admin.pages.promotions.gift_cards.usage.title')}</div>
      <div className="grid grid-cols-2 gap-1 text-muted-foreground">
        <span>{t('admin.pages.promotions.gift_cards.usage.amount')}</span>
        <span className="text-right text-foreground tabular-nums">{giftCard.display_amount}</span>
        <span>{t('admin.pages.promotions.gift_cards.usage.used')}</span>
        <span className="text-right text-foreground tabular-nums">
          {giftCard.display_amount_used}
        </span>
        <span>{t('admin.pages.promotions.gift_cards.usage.remaining')}</span>
        <span className="text-right text-foreground tabular-nums">
          {giftCard.display_amount_remaining}
        </span>
        {giftCard.created_by && (
          <>
            <span>{t('admin.pages.promotions.gift_cards.usage.issued_by')}</span>
            <span className="text-right text-foreground">{giftCard.created_by.email}</span>
          </>
        )}
      </div>
    </div>
  )
}

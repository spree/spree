import { zodResolver } from '@hookform/resolvers/zod'
import type {
  Customer,
  GiftCard,
  GiftCardBatchCreateParams,
  GiftCardCreateParams,
  GiftCardUpdateParams,
} from '@spree/admin-sdk'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useEffect } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { adminClient } from '@/client'
import { Can } from '@/components/spree/can'
import { useConfirm } from '@/components/spree/confirm-dialog'
import { CurrencySelect } from '@/components/spree/currency-select'
import { ResourceCombobox } from '@/components/spree/resource-combobox'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
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
  useCreateGiftCard,
  useCreateGiftCardBatch,
  useDeleteGiftCard,
  useGiftCard,
  useUpdateGiftCard,
} from '@/hooks/use-gift-cards'
import { mapSpreeErrorsToForm } from '@/lib/form-errors'
import { Subject } from '@/lib/permissions'
import { useStore } from '@/providers/store-provider'
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
  const search = Route.useSearch() as z.infer<typeof giftCardsSearchSchema>
  const navigate = useNavigate()

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

  return (
    <>
      <ResourceTable<GiftCard>
        tableKey="gift-cards"
        queryKey="gift-cards"
        queryFn={(params) => adminClient.giftCards.list(params)}
        searchParams={search}
        defaultParams={{ expand: LIST_EXPAND }}
        actions={
          <Can I="create" a={Subject.GiftCard}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              New gift card
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
// Form schemas — separate for create (with `quantity`) vs edit (no quantity,
// no code-prefix branching).
// ----------------------------------------------------------------------------

// Mirrors `Spree::Config[:gift_card_batch_limit]`. Hardcoded for now; if the
// merchant overrides it we'll surface it via a store-settings endpoint later.
const BATCH_LIMIT = 50_000

const createFormSchema = z.object({
  // When `quantity === 1` this is the optional caller-supplied code.
  // When `quantity > 1` it becomes the required batch `prefix`.
  code: z.string().optional(),
  amount: z.coerce.number().positive('Amount must be greater than zero'),
  currency: z.string().min(1, 'Currency is required'),
  expires_at: z.string().optional(),
  customer_id: z.string().optional(),
  quantity: z.coerce.number().int().min(1).max(BATCH_LIMIT),
})

type CreateFormValues = z.infer<typeof createFormSchema>

const editFormSchema = z.object({
  code: z.string().optional(),
  amount: z.coerce.number().positive('Amount must be greater than zero'),
  currency: z.string().min(1, 'Currency is required'),
  expires_at: z.string().optional(),
  customer_id: z.string().optional(),
})

type EditFormValues = z.infer<typeof editFormSchema>

function blank(s: string | undefined): string | undefined {
  return s && s.length > 0 ? s : undefined
}

function editValuesToParams(v: EditFormValues): GiftCardUpdateParams {
  return {
    amount: v.amount,
    expires_at: v.expires_at || null,
    user_id: blank(v.customer_id) ?? null,
  }
}

function singleValuesToParams(v: CreateFormValues): GiftCardCreateParams {
  return {
    code: blank(v.code),
    amount: v.amount,
    currency: v.currency,
    expires_at: v.expires_at || null,
    user_id: blank(v.customer_id) ?? null,
  }
}

function batchValuesToParams(v: CreateFormValues): GiftCardBatchCreateParams {
  // `code` carries the prefix in batch mode; required, validated below.
  return {
    prefix: v.code ?? '',
    amount: v.amount,
    currency: v.currency,
    codes_count: v.quantity,
    expires_at: v.expires_at || null,
  }
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
  const createMutation = useCreateGiftCard()
  const createBatchMutation = useCreateGiftCardBatch()
  // `CurrencySelect` falls back to the store default visually, but we have to
  // seed `currency` here too so react-hook-form's validator doesn't reject
  // the submit on a blank string before `mutate` ever runs.
  const { defaultCurrency } = useStore()
  const form = useForm<CreateFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(createFormSchema) as any,
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

  async function onSubmit(values: CreateFormValues) {
    try {
      if (Number(values.quantity) > 1) {
        // Batches require a prefix; surface the validation error inline rather
        // than letting the server 422.
        if (!values.code?.trim()) {
          form.setError('code', { type: 'required', message: 'Prefix is required for batches' })
          return
        }
        await createBatchMutation.mutateAsync(batchValuesToParams(values))
      } else {
        await createMutation.mutateAsync(singleValuesToParams(values))
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
          <SheetTitle>New gift card</SheetTitle>
          <SheetDescription>
            {isBatch
              ? `Bulk-issue ${quantity} gift cards. The server generates codes by suffixing random hex onto the prefix.`
              : 'Issuing a gift card credits the recipient with the listed amount. The code is auto-generated unless you provide one. No email is sent — share the code manually.'}
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
              Cancel
            </Button>
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting
                ? 'Creating…'
                : isBatch
                  ? `Create ${quantity} gift cards`
                  : 'Create gift card'}
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
  const { data: giftCard, isLoading } = useGiftCard(id, ['customer', 'created_by', 'orders'])
  const updateMutation = useUpdateGiftCard(id)
  const deleteMutation = useDeleteGiftCard()
  const confirm = useConfirm()

  const form = useForm<EditFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(editFormSchema) as any,
    defaultValues: {
      code: '',
      amount: 0,
      currency: '',
      expires_at: '',
      customer_id: '',
    },
  })

  useEffect(() => {
    if (giftCard) {
      form.reset({
        code: giftCard.code,
        amount: Number(giftCard.amount),
        currency: giftCard.currency,
        expires_at: giftCard.expires_at ?? '',
        customer_id: giftCard.customer?.id ?? '',
      })
    }
  }, [giftCard, form])

  async function onSubmit(values: EditFormValues) {
    try {
      await updateMutation.mutateAsync(editValuesToParams(values))
      form.reset(values)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  async function onDelete() {
    const ok = await confirm({
      title: 'Delete gift card?',
      message: `Gift card ${giftCard?.code ?? ''} will be removed. Codes that have already been redeemed cannot be deleted.`,
      variant: 'destructive',
      confirmLabel: 'Delete',
    })
    if (!ok) return
    await deleteMutation.mutateAsync(id)
    onOpenChange(false)
  }

  // Server-side `editable?` is `active?` — redeemed/canceled cards are
  // read-only. Don't even show the form for those; let staff see the audit
  // info only.
  const editable = giftCard?.active ?? false

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{giftCard?.code ?? 'Edit gift card'}</SheetTitle>
          <SheetDescription>
            {editable
              ? 'Adjust amount, expiration, or recipient. Code cannot be changed.'
              : 'This card cannot be edited — once redeemed, canceled, or expired, the details are locked.'}
          </SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">Loading…</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              {form.formState.errors.root?.message && (
                <p className="text-sm text-destructive" role="alert">
                  {form.formState.errors.root.message}
                </p>
              )}
              <EditGiftCardFormFields form={form} readOnly={!editable} />
              {giftCard && <GiftCardUsageSummary giftCard={giftCard} />}
            </div>
            <SheetFooter>
              <Can I="destroy" a={Subject.GiftCard}>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={onDelete}
                  disabled={form.formState.isSubmitting || deleteMutation.isPending}
                  className="mr-auto text-destructive hover:bg-destructive/10 hover:text-destructive"
                >
                  Delete
                </Button>
              </Can>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => onOpenChange(false)}
                disabled={form.formState.isSubmitting}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                size="sm"
                disabled={!editable || form.formState.isSubmitting || !form.formState.isDirty}
              >
                {form.formState.isSubmitting ? 'Saving…' : 'Save'}
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
  return (
    <Controller
      name="customer_id"
      control={form.control}
      render={({ field }) =>
        readOnly ? (
          <div className="text-sm text-muted-foreground">
            {field.value || 'No customer attached'}
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

function AmountCurrencyRow<T extends CreateFormValues | EditFormValues>({
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
        <FieldLabel htmlFor="gc-amount">{t('admin.fields.gift_card.amount.label')}</FieldLabel>
        <Input
          id="gc-amount"
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
        <FieldLabel htmlFor="gc-currency">{t('admin.fields.gift_card.currency.label')}</FieldLabel>
        <Controller
          name={'currency' as never}
          control={form.control}
          render={({ field }) => (
            <CurrencySelect
              id="gc-currency"
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
  form: UseFormReturn<CreateFormValues>
  isBatch: boolean
}) {
  const { t } = useTranslation()
  const { errors } = form.formState
  return (
    <FieldGroup>
      <Field>
        <FieldLabel htmlFor="gc-quantity">{t('admin.fields.gift_card.quantity.label')}</FieldLabel>
        <Input
          id="gc-quantity"
          type="number"
          min={1}
          max={BATCH_LIMIT}
          step={1}
          aria-invalid={!!errors.quantity || undefined}
          {...form.register('quantity')}
        />
        <p className="text-xs text-muted-foreground">
          {`Issue 1 card or bulk-issue up to ${BATCH_LIMIT.toLocaleString()} as a batch.`}
        </p>
        <FieldError errors={[errors.quantity]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="gc-code">
          {isBatch ? 'Prefix' : t('admin.fields.gift_card.code.label')}
        </FieldLabel>
        <Input
          id="gc-code"
          placeholder={
            isBatch ? 'e.g. WELCOME — codes will be WELCOME-abc123' : 'Auto-generated when blank'
          }
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
        <FieldLabel htmlFor="gc-expires-at">
          {t('admin.fields.gift_card.expires_at.label')}
        </FieldLabel>
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
      </Field>

      {/* A single customer can't be attached to a whole batch — hide the
          field in batch mode to make the difference obvious. */}
      {!isBatch && (
        <Field>
          <FieldLabel>{t('admin.fields.gift_card.customer_id.label')} (optional)</FieldLabel>
          <CustomerPickerController form={form} />
        </Field>
      )}
    </FieldGroup>
  )
}

function EditGiftCardFormFields({
  form,
  readOnly = false,
}: {
  form: UseFormReturn<EditFormValues>
  readOnly?: boolean
}) {
  const { t } = useTranslation()
  return (
    <FieldGroup>
      <AmountCurrencyRow form={form} readOnly={readOnly} currencyLocked />

      <Field>
        <FieldLabel htmlFor="gc-expires-at">
          {t('admin.fields.gift_card.expires_at.label')}
        </FieldLabel>
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
      </Field>

      <Field>
        <FieldLabel>{t('admin.fields.gift_card.customer_id.label')} (optional)</FieldLabel>
        <CustomerPickerController form={form} readOnly={readOnly} />
      </Field>
    </FieldGroup>
  )
}

// ----------------------------------------------------------------------------
// Usage summary — shown inside the edit sheet so staff can see redemption
// progress without leaving the modal.
// ----------------------------------------------------------------------------

function GiftCardUsageSummary({ giftCard }: { giftCard: GiftCard }) {
  return (
    <div className="rounded-md border bg-muted/30 p-3 text-sm">
      <div className="mb-2 font-medium">Usage</div>
      <div className="grid grid-cols-2 gap-1 text-muted-foreground">
        <span>Amount</span>
        <span className="text-right text-foreground tabular-nums">{giftCard.display_amount}</span>
        <span>Used</span>
        <span className="text-right text-foreground tabular-nums">
          {giftCard.display_amount_used}
        </span>
        <span>Remaining</span>
        <span className="text-right text-foreground tabular-nums">
          {giftCard.display_amount_remaining}
        </span>
        {giftCard.created_by && (
          <>
            <span>Issued by</span>
            <span className="text-right text-foreground">{giftCard.created_by.email}</span>
          </>
        )}
      </div>
    </div>
  )
}

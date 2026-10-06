import { zodResolver } from '@hookform/resolvers/zod'
import type { Customer, StoreCredit } from '@spree/admin-sdk'
import {
  CurrencySelect,
  currencyParts,
  mapSpreeErrorsToForm,
  normalizeMoneyInput,
} from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  InputGroupText,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  Textarea,
  useConfirm,
} from '@spree/dashboard-ui'
import { EllipsisVerticalIcon, PencilIcon, PlusIcon, TrashIcon } from '@spree/dashboard-ui/icons'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useCurrencyLocale } from '../../../hooks/use-currency-locale'
import {
  type StoreCreditUpdateParams,
  useDeleteCustomerStoreCredit,
  useUpdateCustomerStoreCredit,
} from '../../../hooks/use-customer-store-credits'
import {
  type EditStoreCreditFormValues,
  editStoreCreditFormSchema,
} from '../../../schemas/store-credit'
import { IssueStoreCreditDialog } from '../store-credits/issue-store-credit-dialog'

export function CustomerStoreCreditsCard({ customer }: { customer: Customer }) {
  const { t } = useTranslation()
  const [addOpen, setAddOpen] = useState(false)
  const [editing, setEditing] = useState<StoreCredit | null>(null)
  const confirm = useConfirm()
  const credits = customer.store_credits ?? []

  const deleteMutation = useDeleteCustomerStoreCredit(customer.id)

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            {t('admin.customers.detail.store_credit.title')}
            {credits.length > 0 && <Badge>{credits.length}</Badge>}
          </CardTitle>
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
              <PlusIcon className="size-4" />
              {t('admin.pages.customers.detail.issue_credit')}
            </Button>
          </CardAction>
        </CardHeader>
        {credits.length === 0 ? (
          <CardContent>
            <p className="text-sm text-muted-foreground">
              {t('admin.customers.detail.store_credit.empty')}
            </p>
          </CardContent>
        ) : (
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('admin.fields.amount.label')}</TableHead>
                  <TableHead>{t('admin.customers.detail.store_credit.table.used')}</TableHead>
                  <TableHead>{t('admin.customers.detail.store_credit.table.remaining')}</TableHead>
                  <TableHead>{t('admin.customers.detail.store_credit.table.memo')}</TableHead>
                  <TableHead className="w-10" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {credits.map((sc: StoreCredit) => (
                  <TableRow key={sc.id}>
                    <TableCell className="font-medium tabular-nums">
                      {sc.display_amount ?? sc.amount}
                    </TableCell>
                    <TableCell className="tabular-nums">
                      {sc.display_amount_used ?? sc.amount_used}
                    </TableCell>
                    <TableCell className="tabular-nums">
                      {sc.display_amount_remaining ?? sc.amount_remaining}
                    </TableCell>
                    <TableCell className="text-muted-foreground">{sc.memo ?? '—'}</TableCell>
                    <TableCell className="text-right">
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon-xs">
                            <EllipsisVerticalIcon className="size-4" />
                            <span className="sr-only">{t('admin.actions.actions_menu')}</span>
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem onClick={() => setEditing(sc)}>
                            <PencilIcon className="size-4" />
                            {t('admin.actions.edit')}
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            variant="destructive"
                            onClick={async () => {
                              if (
                                await confirm({
                                  message: t(
                                    'admin.customers.detail.store_credit.delete_confirm_message',
                                  ),
                                  variant: 'destructive',
                                  confirmLabel: t('admin.actions.delete'),
                                })
                              ) {
                                deleteMutation.mutate(sc.id)
                              }
                            }}
                          >
                            <TrashIcon className="size-4" />
                            {t('admin.actions.delete')}
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </CardContent>
        )}
      </Card>

      <IssueStoreCreditDialog customerId={customer.id} open={addOpen} onOpenChange={setAddOpen} />
      {editing && (
        <EditStoreCreditDialog
          customerId={customer.id}
          credit={editing}
          onOpenChange={(o) => {
            if (!o) setEditing(null)
          }}
        />
      )}
    </>
  )
}

function EditStoreCreditDialog({
  customerId,
  credit,
  onOpenChange,
}: {
  customerId: string
  credit: StoreCredit
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  // Server rejects amount changes once any of it has been used. Lock the
  // field so the merchant doesn't submit a value that will only come back
  // as a 422 store_credit_in_use.
  const amountLocked = Number(credit.amount_used ?? 0) > 0

  const localeForCurrency = useCurrencyLocale()
  // Currency is locked on edit, so resolve its market locale once. The amount
  // hydrates from the canonical API value (`"50.00"`) but is displayed/edited
  // in that locale's format (`"50,00"` for EUR); on submit we normalize back to
  // canonical. Displaying in the same locale we normalize from keeps an
  // untouched amount from being mangled on save.
  const creditLocale = localeForCurrency(credit.currency) || 'en'
  const { decimal, symbol } = currencyParts(credit.currency, creditLocale)

  const form = useForm<EditStoreCreditFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(editStoreCreditFormSchema) as any,
    defaultValues: {
      amount: credit.amount ? credit.amount.replace('.', decimal) : '',
      memo: credit.memo ?? '',
    },
  })
  const { errors } = form.formState

  const mutation = useUpdateCustomerStoreCredit(customerId, credit.id)

  async function onSubmit(values: EditStoreCreditFormValues) {
    const params: StoreCreditUpdateParams = {}

    if (!amountLocked) {
      const amountValue = values.amount.toString().trim()
      // Normalize from the credit's display locale to the canonical
      // `"1234.56"` the API expects.
      if (amountValue) {
        params.amount = normalizeMoneyInput(amountValue, creditLocale)
      }
    }

    params.memo = values.memo

    try {
      await mutation.mutateAsync(params)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Dialog open onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.customers.detail.edit_credit')}</DialogTitle>
          <DialogDescription>
            {t('admin.customers.detail.store_credit.edit_description')}
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={form.handleSubmit(onSubmit)}>
          <DialogBody>
            {errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {errors.root.message}
              </p>
            )}
            <FieldGroup>
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor="edit-sc-amount">
                    {t('admin.fields.store_credit.amount.label')}
                  </FieldLabel>
                  <InputGroup>
                    <InputGroupAddon>
                      <InputGroupText>{symbol}</InputGroupText>
                    </InputGroupAddon>
                    <InputGroupInput
                      id="edit-sc-amount"
                      type="text"
                      inputMode="decimal"
                      disabled={amountLocked}
                      aria-invalid={!!errors.amount || undefined}
                      {...form.register('amount')}
                    />
                  </InputGroup>
                  <FieldError errors={[errors.amount]} />
                </Field>
                <Field>
                  {/* Currency is locked: the API doesn't accept `currency`
                      on update (changing it on a partially-used credit
                      would invalidate amount_used / amount_remaining). We
                      surface it disabled so the merchant always sees which
                      currency the credit is in. */}
                  <FieldLabel htmlFor="edit-sc-currency">
                    {t('admin.fields.store_credit.currency.label')}
                  </FieldLabel>
                  <CurrencySelect id="edit-sc-currency" value={credit.currency} disabled />
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor="edit-sc-memo">
                  {t('admin.fields.store_credit.memo.label')}
                </FieldLabel>
                <Textarea
                  id="edit-sc-memo"
                  rows={3}
                  placeholder={t('admin.fields.store_credit.memo.placeholder')}
                  aria-invalid={!!errors.memo || undefined}
                  {...form.register('memo')}
                />
                <FieldError errors={[errors.memo]} />
              </Field>
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

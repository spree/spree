import type { Discount, Fee, Order } from '@spree/admin-sdk'
import { adminClient, currencyParts, formatPrice } from '@spree/dashboard-core'
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
  FieldGroup,
  FieldLabel,
  Input,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  InputGroupText,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import {
  BanknoteIcon,
  EllipsisVerticalIcon,
  PlusIcon,
  ReceiptTextIcon,
  TagIcon,
  TrashIcon,
} from '@spree/dashboard-ui/icons'
import i18n from 'i18next'
import { type FormEvent, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  useOrderAdjustmentLinesMutation,
  useOrderDiscounts,
  useOrderFees,
  useOrderTaxLines,
} from '../../../hooks/use-order'
import {
  groupTaxLines,
  showsTaxabilityReason,
  type TaxLineGroup,
} from '../../../lib/tax-line-groups'
import { FEE_KINDS } from '../../../schemas/order'

/** The API accepts any kind string, so unknown values fall back to the raw value. */
function feeKindLabel(kind: string) {
  return (FEE_KINDS as readonly string[]).includes(kind)
    ? i18n.t(`admin.orders.detail.adjustment_lines.fee_kind_${kind}`)
    : kind
}

/** Trailing action cell — renders empty (keeping column width) for undeletable rows. */
function AdjustmentDeleteCell({
  onDelete,
  deleting,
}: {
  onDelete?: () => void
  deleting?: boolean
}) {
  return (
    <TableCell className="w-10 text-right">
      {onDelete && (
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="ghost"
              size="icon-xs"
              disabled={deleting}
              aria-label={i18n.t('admin.actions.actions_menu')}
            >
              <EllipsisVerticalIcon className="size-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem variant="destructive" onClick={onDelete}>
              <TrashIcon className="size-4" />
              {i18n.t('admin.actions.delete')}
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      )}
    </TableCell>
  )
}

/** The certificate line under an exempt tax row, or nothing. */
function taxExemptionDetail(group: TaxLineGroup): string | null {
  const number = group.exemption?.certificate_number
  if (group.taxabilityReason !== 'customer_exempt' || !number) return null

  const reasonCode = group.exemption?.reason_code
  const reason = reasonCode
    ? i18n.t(`admin.tax_exemption_certificates.reason_codes.${reasonCode}`, {
        defaultValue: reasonCode,
      })
    : null

  return reason
    ? i18n.t('admin.orders.detail.adjustment_lines.tax_exempt_certificate', {
        reason,
        number,
      })
    : i18n.t('admin.orders.detail.adjustment_lines.tax_exempt_certificate_number', {
        number,
      })
}

export function TaxLinesCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const orderId = order.id
  const { data: taxLines, isPending, isError, isSuccess } = useOrderTaxLines(orderId)
  const taxGroups = groupTaxLines(taxLines?.data ?? [])
  const emptyMessage = isPending
    ? t('admin.common.loading')
    : isError
      ? t('admin.errors.failed_to_load')
      : isSuccess && order.completed_at
        ? t('admin.orders.detail.adjustment_lines.taxes_unmatched')
        : t('admin.orders.detail.adjustment_lines.taxes_empty')

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <ReceiptTextIcon className="size-4" />
          {t('admin.orders.detail.adjustment_lines.taxes')}
        </CardTitle>
      </CardHeader>

      {taxGroups.length === 0 ? (
        <CardContent>
          <p className="text-sm text-muted-foreground">{emptyMessage}</p>
        </CardContent>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>{t('admin.orders.detail.adjustment_lines.column_label')}</TableHead>
              <TableHead className="text-right">
                {t('admin.orders.detail.adjustment_lines.column_amount')}
              </TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {taxGroups.map((group) => {
              const detail = taxExemptionDetail(group)
              return (
                <TableRow key={group.key}>
                  <TableCell>
                    <div className="flex flex-col gap-0.5">
                      <div className="flex flex-wrap items-center gap-2">
                        <span>{group.label}</span>
                        {showsTaxabilityReason(group) && (
                          <Badge variant="secondary">
                            {t(
                              `admin.orders.detail.adjustment_lines.taxability_reason.${group.taxabilityReason}`,
                              { defaultValue: group.taxabilityReason ?? undefined },
                            )}
                          </Badge>
                        )}
                      </div>
                      {detail && <span className="text-xs text-muted-foreground">{detail}</span>}
                    </div>
                  </TableCell>
                  <TableCell className="text-right tabular-nums">
                    {formatPrice({
                      amount: group.amount.toFixed(2),
                      currency: order.currency,
                      display_amount: null,
                    })}
                  </TableCell>
                </TableRow>
              )
            })}
          </TableBody>
        </Table>
      )}
    </Card>
  )
}

export function OrderDiscountsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const orderId = order.id
  const confirm = useConfirm()
  const [addDiscountOpen, setAddDiscountOpen] = useState(false)

  const { data: discounts } = useOrderDiscounts(orderId)
  const deleteDiscountMutation = useOrderAdjustmentLinesMutation(orderId, (id: string) =>
    adminClient.orders.discounts.delete(orderId, id),
  )

  // Only promotion rows are system-owned; anything else is admin-entered and deletable.
  const discountRows = discounts?.data ?? []

  async function handleDeleteDiscount(row: Discount) {
    const confirmed = await confirm({
      title: t('admin.orders.detail.adjustment_lines.delete_discount_title'),
      message: t('admin.orders.detail.adjustment_lines.delete_discount_message', {
        label: row.label,
      }),
      confirmLabel: t('admin.actions.delete'),
      variant: 'destructive',
    })
    if (confirmed) deleteDiscountMutation.mutate(row.id)
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <TagIcon className="size-4" />
          {t('admin.orders.detail.adjustment_lines.discounts')}
        </CardTitle>
        <CardAction>
          <Button variant="outline" size="sm" onClick={() => setAddDiscountOpen(true)}>
            <PlusIcon className="size-4" />
            {t('admin.orders.detail.adjustment_lines.add_discount')}
          </Button>
        </CardAction>
      </CardHeader>

      {discountRows.length === 0 ? (
        <CardContent>
          <p className="text-sm text-muted-foreground">
            {t('admin.orders.detail.adjustment_lines.discounts_empty')}
          </p>
        </CardContent>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>{t('admin.orders.detail.adjustment_lines.column_label')}</TableHead>
              <TableHead>{t('admin.orders.detail.adjustment_lines.column_source')}</TableHead>
              <TableHead>{t('admin.orders.detail.adjustment_lines.column_code')}</TableHead>
              <TableHead className="text-right">
                {t('admin.orders.detail.adjustment_lines.column_amount')}
              </TableHead>
              <TableHead className="w-10" />
            </TableRow>
          </TableHeader>
          <TableBody>
            {discountRows.map((row) => (
              <TableRow key={row.id}>
                <TableCell>{row.label}</TableCell>
                <TableCell>
                  <Badge variant="secondary">
                    {row.kind === 'promotion'
                      ? t('admin.orders.detail.adjustment_lines.kind_promotion')
                      : t('admin.orders.detail.adjustment_lines.kind_manual')}
                  </Badge>
                </TableCell>
                <TableCell className="text-muted-foreground">
                  {row.code ? <Badge variant="outline">{row.code}</Badge> : '—'}
                </TableCell>
                <TableCell className="text-right tabular-nums">{row.display_amount}</TableCell>
                <AdjustmentDeleteCell
                  onDelete={row.kind === 'promotion' ? undefined : () => handleDeleteDiscount(row)}
                  deleting={deleteDiscountMutation.isPending}
                />
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}

      <AddDiscountDialog order={order} open={addDiscountOpen} onOpenChange={setAddDiscountOpen} />
    </Card>
  )
}

export function FeesCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const orderId = order.id
  const confirm = useConfirm()
  const [addFeeOpen, setAddFeeOpen] = useState(false)

  const { data: fees } = useOrderFees(orderId)
  const deleteFeeMutation = useOrderAdjustmentLinesMutation(orderId, (id: string) =>
    adminClient.orders.fees.delete(orderId, id),
  )

  const feeRows = fees?.data ?? []

  async function handleDeleteFee(row: Fee) {
    const confirmed = await confirm({
      title: t('admin.orders.detail.adjustment_lines.delete_fee_title'),
      message: t('admin.orders.detail.adjustment_lines.delete_fee_message', { label: row.label }),
      confirmLabel: t('admin.actions.delete'),
      variant: 'destructive',
    })
    if (confirmed) deleteFeeMutation.mutate(row.id)
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <BanknoteIcon className="size-4" />
          {t('admin.orders.detail.adjustment_lines.fees')}
        </CardTitle>
        <CardAction>
          <Button variant="outline" size="sm" onClick={() => setAddFeeOpen(true)}>
            <PlusIcon className="size-4" />
            {t('admin.orders.detail.adjustment_lines.add_fee')}
          </Button>
        </CardAction>
      </CardHeader>

      {feeRows.length === 0 ? (
        <CardContent>
          <p className="text-sm text-muted-foreground">
            {t('admin.orders.detail.adjustment_lines.fees_empty')}
          </p>
        </CardContent>
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>{t('admin.orders.detail.adjustment_lines.column_label')}</TableHead>
              <TableHead>{t('admin.orders.detail.adjustment_lines.column_kind')}</TableHead>
              <TableHead className="text-right">
                {t('admin.orders.detail.adjustment_lines.column_amount')}
              </TableHead>
              <TableHead className="w-10" />
            </TableRow>
          </TableHeader>
          <TableBody>
            {feeRows.map((row) => (
              <TableRow key={row.id}>
                <TableCell>{row.label}</TableCell>
                <TableCell className="text-muted-foreground">
                  {row.kind ? <Badge variant="outline">{feeKindLabel(row.kind)}</Badge> : '—'}
                </TableCell>
                <TableCell className="text-right tabular-nums">{row.display_amount}</TableCell>
                <AdjustmentDeleteCell
                  onDelete={() => handleDeleteFee(row)}
                  deleting={deleteFeeMutation.isPending}
                />
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}

      <AddFeeDialog order={order} open={addFeeOpen} onOpenChange={setAddFeeOpen} />
    </Card>
  )
}

function AddDiscountDialog({
  order,
  open,
  onOpenChange,
}: {
  order: Order
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t, i18n } = useTranslation()
  const orderId = order.id
  const [target, setTarget] = useState('order')
  const [valueType, setValueType] = useState('flat')
  const [value, setValue] = useState('')

  const mutation = useOrderAdjustmentLinesMutation(
    orderId,
    (params: {
      label: string
      value: string
      value_type: 'flat' | 'percent'
      line_item_id?: string
    }) => adminClient.orders.discounts.create(orderId, params),
  )

  const targetOptions = [
    { value: 'order', label: t('admin.orders.detail.adjustment_lines.target_order') },
    ...(order.items ?? []).map((item) => ({ value: item.id, label: item.name ?? item.id })),
  ]
  const valueTypeOptions = [
    { value: 'flat', label: t('admin.orders.detail.adjustment_lines.value_type_flat') },
    { value: 'percent', label: t('admin.orders.detail.adjustment_lines.value_type_percent') },
  ]
  const { symbol: currencySymbol } = currencyParts(order.currency, i18n.language)

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const fd = new FormData(e.currentTarget)
    mutation.mutate(
      {
        label: fd.get('label') as string,
        value,
        value_type: valueType as 'flat' | 'percent',
        ...(target !== 'order' ? { line_item_id: target } : {}),
      },
      {
        onSuccess: () => {
          setValue('')
          onOpenChange(false)
        },
      },
    )
  }

  // Mirrors Orders::AddManualDiscount: percent applies to the already-
  // discounted line amounts, clamped so no line goes below zero.
  const numericValue = Number.parseFloat(value)
  let previewAmount: number | null = null
  if (valueType === 'percent' && Number.isFinite(numericValue) && numericValue > 0) {
    const items = order.items ?? []
    const base =
      target === 'order'
        ? items.reduce(
            (sum, item) => sum + Math.max(Number.parseFloat(item.discounted_amount), 0),
            0,
          )
        : Math.max(
            Number.parseFloat(items.find((item) => item.id === target)?.discounted_amount ?? '0'),
            0,
          )
    if (base > 0) previewAmount = Math.min((base * numericValue) / 100, base)
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.orders.detail.adjustment_lines.add_discount')}</DialogTitle>
          <DialogDescription>
            {t('admin.orders.detail.adjustment_lines.add_discount_description')}
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit}>
          <DialogBody>
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="discount-label">
                  {t('admin.orders.detail.adjustment_lines.label_field')}
                </FieldLabel>
                <Input id="discount-label" name="label" required />
              </Field>
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor="discount-value">
                    {t('admin.orders.detail.adjustment_lines.value_field')}
                  </FieldLabel>
                  <InputGroup>
                    {valueType === 'percent' ? null : (
                      <InputGroupAddon>
                        <InputGroupText>{currencySymbol}</InputGroupText>
                      </InputGroupAddon>
                    )}
                    <InputGroupInput
                      id="discount-value"
                      name="value"
                      type="number"
                      step="0.01"
                      min="0.01"
                      value={value}
                      onChange={(e) => setValue(e.target.value)}
                      required
                    />
                    {valueType === 'percent' ? (
                      <InputGroupAddon align="inline-end">
                        <InputGroupText>%</InputGroupText>
                      </InputGroupAddon>
                    ) : null}
                  </InputGroup>
                </Field>
                <Field>
                  <FieldLabel>
                    {t('admin.orders.detail.adjustment_lines.value_type_field')}
                  </FieldLabel>
                  <Select
                    items={valueTypeOptions}
                    value={valueType}
                    onValueChange={(v) => setValueType(v as string)}
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {valueTypeOptions.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                          {option.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </Field>
              </div>
              <Field>
                <FieldLabel>{t('admin.orders.detail.adjustment_lines.target_field')}</FieldLabel>
                <Select
                  items={targetOptions}
                  value={target}
                  onValueChange={(v) => setTarget(v as string)}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {targetOptions.map((option) => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </Field>
              {previewAmount !== null && (
                <p className="text-sm text-muted-foreground">
                  {t('admin.orders.detail.adjustment_lines.percent_preview', {
                    amount: new Intl.NumberFormat(i18n.language, {
                      style: 'currency',
                      currency: order.currency,
                    }).format(previewAmount),
                  })}
                </p>
              )}
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending
                ? t('admin.actions.saving')
                : t('admin.orders.detail.adjustment_lines.add_discount')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function AddFeeDialog({
  order,
  open,
  onOpenChange,
}: {
  order: Order
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const orderId = order.id
  const [target, setTarget] = useState('order')
  const [kind, setKind] = useState<string>('surcharge')

  const mutation = useOrderAdjustmentLinesMutation(
    orderId,
    (params: { label: string; amount: string; kind?: string; line_item_id?: string }) =>
      adminClient.orders.fees.create(orderId, params),
  )

  const targetOptions = [
    { value: 'order', label: t('admin.orders.detail.adjustment_lines.target_order') },
    ...(order.items ?? []).map((item) => ({ value: item.id, label: item.name ?? item.id })),
  ]

  const kindOptions = FEE_KINDS.map((value) => ({
    value,
    label: t(`admin.orders.detail.adjustment_lines.fee_kind_${value}`),
  }))
  const { symbol: currencySymbol } = currencyParts(order.currency, i18n.language)

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const fd = new FormData(e.currentTarget)
    mutation.mutate(
      {
        label: fd.get('label') as string,
        amount: fd.get('amount') as string,
        kind,
        ...(target !== 'order' ? { line_item_id: target } : {}),
      },
      { onSuccess: () => onOpenChange(false) },
    )
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.orders.detail.adjustment_lines.add_fee')}</DialogTitle>
          <DialogDescription>
            {t('admin.orders.detail.adjustment_lines.add_fee_description')}
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit}>
          <DialogBody>
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="fee-label">
                  {t('admin.orders.detail.adjustment_lines.label_field')}
                </FieldLabel>
                <Input id="fee-label" name="label" required />
              </Field>
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor="fee-amount">
                    {t('admin.orders.detail.adjustment_lines.amount_field')}
                  </FieldLabel>
                  <InputGroup>
                    <InputGroupAddon>
                      <InputGroupText>{currencySymbol}</InputGroupText>
                    </InputGroupAddon>
                    <InputGroupInput
                      id="fee-amount"
                      name="amount"
                      type="number"
                      step="0.01"
                      min="0"
                      required
                    />
                  </InputGroup>
                </Field>
                <Field>
                  <FieldLabel>{t('admin.orders.detail.adjustment_lines.kind_field')}</FieldLabel>
                  <Select
                    items={kindOptions}
                    value={kind}
                    onValueChange={(v) => setKind(v as string)}
                  >
                    <SelectTrigger>
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
                </Field>
              </div>
              <Field>
                <FieldLabel>{t('admin.orders.detail.adjustment_lines.target_field')}</FieldLabel>
                <Select
                  items={targetOptions}
                  value={target}
                  onValueChange={(v) => setTarget(v as string)}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {targetOptions.map((option) => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </Field>
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending
                ? t('admin.actions.saving')
                : t('admin.orders.detail.adjustment_lines.add_fee')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

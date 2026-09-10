import type { StockReceiptCreateParams } from '@spree/admin-sdk'
import { Can, StoreDatePicker, type SubjectName } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldLabel,
  Input,
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
} from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { REJECTION_REASONS, type RejectionReason } from '../../schemas/inventory-operations'
import { QuantityCell, QuantityHead } from './quantity-cell'
import { VariantLink } from './variant-link'

/**
 * What a purchase order line and a transfer line have in common once a
 * delivery is being counted against them. The promised quantity has a
 * different name on each, so callers map it to `quantity_expected`.
 */
export interface ReceivableLine {
  id: string
  product_id: string | null
  variant_name: string | null
  variant_sku: string | null
  thumbnail_url: string | null
  quantity_expected: number
  quantity_received: number
  quantity_rejected: number
  outstanding: number
}

interface Count {
  accepted: number
  rejected: number
  reason: RejectionReason | ''
}

/**
 * One delivery, as the dock counts it: what arrived intact, what was refused
 * and why, per line — this delivery's figures, not running totals. Submitting
 * books a stock receipt; a second delivery starts from zero again.
 */
export function ReceiveDeliveryCard({
  lines,
  expectedLabel,
  subject,
  pending,
  onReceive,
}: {
  lines: ReceivableLine[]
  /** The column heading for the promised quantity: "Ordered" or "Shipped". */
  expectedLabel: string
  subject: SubjectName
  pending: boolean
  onReceive: (params: StockReceiptCreateParams) => Promise<unknown>
}) {
  const { t } = useTranslation()
  const [counts, setCounts] = useState<Record<string, Count>>({})
  const [reference, setReference] = useState('')
  const [receivedAt, setReceivedAt] = useState<string | undefined>(undefined)
  const [notes, setNotes] = useState('')

  const countFor = (id: string): Count => counts[id] ?? { accepted: 0, rejected: 0, reason: '' }
  const setCount = (id: string, patch: Partial<Count>) =>
    setCounts((prev) => ({ ...prev, [id]: { ...countFor(id), ...patch } }))

  const accepted = lines.reduce((sum, line) => sum + countFor(line.id).accepted, 0)
  const rejected = lines.reduce((sum, line) => sum + countFor(line.id).rejected, 0)
  // A refusal has to say why; the server refuses it otherwise.
  const missingReason = lines.some((line) => {
    const count = countFor(line.id)
    return count.rejected > 0 && !count.reason
  })

  async function handleReceive() {
    const items = lines
      .filter((line) => countFor(line.id).accepted > 0 || countFor(line.id).rejected > 0)
      .map((line) => {
        const count = countFor(line.id)
        return {
          id: line.id,
          quantity_accepted: count.accepted,
          quantity_rejected: count.rejected,
          rejection_reason: count.rejected > 0 ? count.reason || undefined : undefined,
        }
      })

    const booked = await onReceive({
      items,
      reference: reference.trim() || undefined,
      received_at: receivedAt,
      notes: notes.trim() || undefined,
    })
      .then(() => true)
      .catch(() => false)
    if (!booked) return

    setCounts({})
    setReference('')
    setReceivedAt(undefined)
    setNotes('')
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.stock_receipts.receive_title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4 p-0">
        <div className="grid gap-4 px-4 pt-4 md:grid-cols-3">
          <Field>
            <FieldLabel htmlFor="receipt-reference">
              {t('admin.stock_receipts.fields.reference')}
            </FieldLabel>
            <Input
              id="receipt-reference"
              value={reference}
              placeholder={t('admin.stock_receipts.fields.reference_placeholder')}
              onChange={(event) => setReference(event.target.value)}
            />
          </Field>
          <Field>
            <FieldLabel>{t('admin.stock_receipts.fields.received_at')}</FieldLabel>
            {/* Left blank, the server stamps now — the usual case. */}
            <StoreDatePicker
              value={receivedAt}
              onChange={(value) => setReceivedAt(value ?? undefined)}
              includeTime
              placeholder={t('admin.stock_receipts.fields.received_at_placeholder')}
            />
          </Field>
          <Field>
            <FieldLabel htmlFor="receipt-notes">
              {t('admin.stock_receipts.fields.notes')}
            </FieldLabel>
            <Input
              id="receipt-notes"
              value={notes}
              onChange={(event) => setNotes(event.target.value)}
            />
          </Field>
        </div>

        <Table scrollX>
          <TableHeader>
            <TableRow>
              <TableHead>{t('admin.inventory_lines.columns.variant')}</TableHead>
              <TableHead className="text-right">{expectedLabel}</TableHead>
              <TableHead className="text-right">
                {t('admin.stock_receipts.columns.received_so_far')}
              </TableHead>
              <QuantityHead>{t('admin.stock_receipts.columns.accepted')}</QuantityHead>
              <QuantityHead>{t('admin.stock_receipts.columns.rejected')}</QuantityHead>
              <TableHead>{t('admin.stock_receipts.columns.reason')}</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {lines.map((line) => {
              const count = countFor(line.id)
              return (
                <TableRow key={line.id}>
                  <TableCell>
                    <VariantLink
                      productId={line.product_id}
                      name={line.variant_name}
                      sku={line.variant_sku}
                      thumbnailUrl={line.thumbnail_url}
                    />
                  </TableCell>
                  <TableCell className="text-right tabular-nums">
                    {line.quantity_expected}
                  </TableCell>
                  <TableCell className="text-right tabular-nums">
                    {line.quantity_received}
                    {line.quantity_rejected > 0 && (
                      <span className="ml-1 text-muted-foreground text-xs">
                        {t('admin.stock_receipts.rejected_so_far', {
                          count: line.quantity_rejected,
                        })}
                      </span>
                    )}
                  </TableCell>
                  {/* No ceiling: a supplier sending more than was ordered is a
                      fact to record, not a typo to refuse. */}
                  <QuantityCell
                    editable
                    value={count.accepted}
                    min={0}
                    label={t('admin.stock_receipts.columns.accepted')}
                    onChange={(value) => setCount(line.id, { accepted: value })}
                  />
                  <QuantityCell
                    editable
                    value={count.rejected}
                    min={0}
                    label={t('admin.stock_receipts.columns.rejected')}
                    onChange={(value) => setCount(line.id, { rejected: value })}
                  />
                  <TableCell>
                    {count.rejected > 0 ? (
                      <Select
                        items={REJECTION_REASONS.map((value) => ({
                          value,
                          label: t(`admin.stock_receipts.rejection_reasons.${value}`),
                        }))}
                        value={count.reason}
                        onValueChange={(value) =>
                          setCount(line.id, { reason: (value as RejectionReason | null) ?? '' })
                        }
                      >
                        <SelectTrigger aria-label={t('admin.stock_receipts.columns.reason')}>
                          <SelectValue placeholder={t('admin.stock_receipts.reason_placeholder')} />
                        </SelectTrigger>
                        <SelectContent>
                          {REJECTION_REASONS.map((value) => (
                            <SelectItem key={value} value={value}>
                              {t(`admin.stock_receipts.rejection_reasons.${value}`)}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    ) : (
                      <span className="text-muted-foreground">—</span>
                    )}
                  </TableCell>
                </TableRow>
              )
            })}
          </TableBody>
        </Table>

        <div className="flex items-center justify-between px-4 pb-4">
          <p className="text-muted-foreground text-sm tabular-nums">
            {t('admin.stock_receipts.delivery_total', { accepted, rejected })}
          </p>
          <Can I="update" a={subject}>
            <Button
              type="button"
              onClick={handleReceive}
              disabled={pending || (accepted === 0 && rejected === 0) || missingReason}
            >
              {pending ? t('admin.actions.saving') : t('admin.stock_receipts.actions.receive')}
            </Button>
          </Can>
        </div>
      </CardContent>
    </Card>
  )
}

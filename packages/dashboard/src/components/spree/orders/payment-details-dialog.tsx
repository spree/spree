import type { Payment } from '@spree/admin-sdk'
import { Money } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  RelativeTime,
  StatusBadge,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { ExternalLinkIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'

type CheckOutcome = 'passed' | 'failed' | 'not_checked'

const OUTCOME_VARIANTS = {
  passed: 'success',
  failed: 'destructive',
  not_checked: 'outline',
} as const

function addressCheck(payment: Payment): CheckOutcome {
  if (!payment.avs_response) return 'not_checked'
  return payment.avs_risky ? 'failed' : 'passed'
}

function securityCodeCheck(payment: Payment): CheckOutcome {
  if (!payment.cvv_response_code) return 'not_checked'
  return payment.cvv_risky ? 'failed' : 'passed'
}

/** What the card issuer reported about a payment, and each capture of its money. */
export function PaymentDetailsDialog({
  payment,
  currency,
  open,
  onOpenChange,
}: {
  payment: Payment
  currency: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const captures = payment.capture_events ?? []

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>
            {t('admin.orders.detail.payment_details.title', { number: payment.number })}
          </DialogTitle>
          <DialogDescription>
            {t('admin.orders.detail.payment_details.description')}
          </DialogDescription>
        </DialogHeader>
        <DialogBody className="flex flex-col gap-6">
          <dl className="grid grid-cols-[auto_1fr] gap-x-6 gap-y-2 text-sm">
            <dt className="text-muted-foreground">
              {t('admin.orders.detail.payments_table.method')}
            </dt>
            <dd>{payment.payment_method?.name ?? '—'}</dd>
            <dt className="text-muted-foreground">
              {t('admin.orders.detail.payments_table.state')}
            </dt>
            <dd>
              <StatusBadge status={payment.status} />
            </dd>
            <dt className="text-muted-foreground">{t('admin.fields.amount.label')}</dt>
            <dd className="tabular-nums">
              <Money amount={payment.amount} currency={currency} />
            </dd>
            <dt className="text-muted-foreground">
              {t('admin.orders.detail.payment_details.transaction_id')}
            </dt>
            <dd className="font-mono text-xs break-all">{payment.response_code ?? '—'}</dd>
            {payment.source_type === 'credit_card' && (
              <>
                <CheckRow
                  label={t('admin.orders.detail.payment_details.address_check')}
                  outcome={addressCheck(payment)}
                  code={payment.avs_response}
                />
                <CheckRow
                  label={t('admin.orders.detail.payment_details.security_code_check')}
                  outcome={securityCodeCheck(payment)}
                  code={payment.cvv_response_code}
                  message={payment.cvv_response_message}
                />
              </>
            )}
          </dl>
          <section className="flex flex-col gap-2">
            <h3 className="font-medium text-sm">
              {t('admin.orders.detail.payment_details.captures')}
            </h3>
            {captures.length === 0 ? (
              <p className="text-muted-foreground text-sm">
                {t('admin.orders.detail.payment_details.captures_empty')}
              </p>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>{t('admin.orders.detail.payment_details.captured_at')}</TableHead>
                    <TableHead className="text-right">{t('admin.fields.amount.label')}</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {captures.map((capture) => (
                    <TableRow key={capture.id}>
                      <TableCell>
                        <RelativeTime iso={capture.created_at} />
                      </TableCell>
                      <TableCell className="text-right tabular-nums">
                        <Money amount={capture.amount} currency={currency} />
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </section>
        </DialogBody>
        {payment.gateway_dashboard_payment_url && (
          <DialogFooter>
            <Button variant="outline" asChild>
              <a
                href={payment.gateway_dashboard_payment_url}
                target="_blank"
                rel="noopener noreferrer"
              >
                <ExternalLinkIcon data-icon="inline-start" />
                {t('admin.orders.detail.payments_table.view_at_gateway', {
                  gateway: payment.payment_method?.name,
                })}
              </a>
            </Button>
          </DialogFooter>
        )}
      </DialogContent>
    </Dialog>
  )
}

function CheckRow({
  label,
  outcome,
  code,
  message,
}: {
  label: string
  outcome: CheckOutcome
  code: string | null
  message?: string | null
}) {
  const { t } = useTranslation()

  return (
    <>
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="flex flex-wrap items-center gap-2">
        <Badge variant={OUTCOME_VARIANTS[outcome]}>
          {t(`admin.orders.detail.payment_details.check.${outcome}`)}
        </Badge>
        {code && (
          <span className="text-muted-foreground text-xs">
            {t('admin.orders.detail.payment_details.code', { code })}
          </span>
        )}
        {message && <span className="text-muted-foreground text-xs">{message}</span>}
      </dd>
    </>
  )
}

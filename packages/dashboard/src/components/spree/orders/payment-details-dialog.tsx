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

export type CheckOutcome = 'passed' | 'failed' | 'unavailable' | 'not_checked'

const OUTCOME_VARIANTS = {
  passed: 'success',
  failed: 'destructive',
  unavailable: 'warning',
  not_checked: 'outline',
} as const

// Results where the check was not run, or only in part — the issuer's system
// was down, the card or its issuer does not support it, or the street line was
// not verified — as opposed to one that was run and did not match. Spree still
// counts these as risky; only the label differs. Meanings follow
// ActiveMerchant's AVSResult and CVVResult. CVV `S` (a code is on the card but
// none was sent) is the merchant's omission, so it stays a failure.
const UNAVAILABLE_AVS_CODES = new Set(['E', 'G', 'I', 'P', 'R', 'S', 'U'])
const UNAVAILABLE_CVV_CODES = new Set(['P', 'U', 'X'])

// The backend's risk flag decides whether a check is risky; the code only
// tells a failure from a check that was not run. A risky result always reads
// as one of the two, even with a blank code, so its warning is never lost.
function riskyOutcome(code: string | null, unavailableCodes: Set<string>): CheckOutcome {
  const normalized = code?.trim().toUpperCase()
  return normalized && unavailableCodes.has(normalized) ? 'unavailable' : 'failed'
}

export function addressCheck(payment: Pick<Payment, 'avs_response' | 'avs_risky'>): CheckOutcome {
  if (payment.avs_risky) return riskyOutcome(payment.avs_response, UNAVAILABLE_AVS_CODES)
  return payment.avs_response ? 'passed' : 'not_checked'
}

export function securityCodeCheck(
  payment: Pick<Payment, 'cvv_response_code' | 'cvv_risky'>,
): CheckOutcome {
  if (payment.cvv_risky) return riskyOutcome(payment.cvv_response_code, UNAVAILABLE_CVV_CODES)
  return payment.cvv_response_code ? 'passed' : 'not_checked'
}

/**
 * The worst of a card payment's two checks when either is risky, for the
 * warning on the payments table — so the table and this dialog agree.
 */
export function riskyCardChecks(
  payment: Pick<Payment, 'avs_response' | 'avs_risky' | 'cvv_response_code' | 'cvv_risky'>,
): 'failed' | 'unavailable' | null {
  const outcomes = [addressCheck(payment), securityCodeCheck(payment)]
  if (outcomes.includes('failed')) return 'failed'
  if (outcomes.includes('unavailable')) return 'unavailable'
  return null
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
          <dl className="grid grid-cols-[auto_1fr] gap-x-6 gap-y-2 text-base">
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
            <h3 className="font-medium text-base">
              {t('admin.orders.detail.payment_details.captures')}
            </h3>
            {captures.length === 0 ? (
              <p className="text-muted-foreground text-base">
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

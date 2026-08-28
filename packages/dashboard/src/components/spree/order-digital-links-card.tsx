import type { DigitalLink, Order } from '@spree/admin-sdk'
import { formatStoreDateTime, useStore } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  StatusBadge,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import { MailIcon, RotateCcwIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import { useResendDigitalLinks, useResetDigitalLink } from '../../hooks/use-digital-assets'

interface LinkRow {
  link: DigitalLink
  itemName: string
}

export function OrderDigitalLinksCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { timezone } = useStore()
  const confirm = useConfirm()
  const resetLink = useResetDigitalLink(order.id)
  const resendEmail = useResendDigitalLinks(order.id)

  const rows: LinkRow[] = (order.items ?? []).flatMap((item) =>
    (item.digital_links ?? []).map((link) => ({ link, itemName: item.name })),
  )

  if (rows.length === 0) return null

  async function handleReset(row: LinkRow) {
    const confirmed = await confirm({
      title: t('admin.digital_links.reset_title'),
      message: t('admin.digital_links.reset_description', { name: row.link.filename }),
    })
    if (confirmed) await resetLink.mutateAsync(row.link.id)
  }

  // `authorizable` already folds both refusal reasons; the specific one is
  // what the merchant needs to see, so it is named rather than inferred.
  function statusFor(link: DigitalLink): 'expired' | 'used_up' | 'available' {
    if (link.expired) return 'expired'
    if (link.access_limit_exceeded) return 'used_up'
    return 'available'
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.digital_links.title')}</CardTitle>
        <CardAction>
          <Button
            type="button"
            variant="outline"
            size="sm"
            disabled={resendEmail.isPending}
            onClick={() => resendEmail.mutate(undefined)}
          >
            <MailIcon className="mr-2 size-4" />
            {t('admin.digital_links.resend_email')}
          </Button>
        </CardAction>
      </CardHeader>
      <CardContent>
        <div className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('admin.digital_links.columns.file')}</TableHead>
                <TableHead>{t('admin.digital_links.columns.item')}</TableHead>
                <TableHead>{t('admin.digital_links.columns.downloads')}</TableHead>
                <TableHead>{t('admin.digital_links.columns.expires')}</TableHead>
                <TableHead>{t('admin.digital_links.columns.status')}</TableHead>
                <TableHead />
              </TableRow>
            </TableHeader>
            <TableBody>
              {rows.map((row) => (
                <TableRow key={row.link.id}>
                  <TableCell className="font-medium">{row.link.filename}</TableCell>
                  <TableCell className="text-muted-foreground">{row.itemName}</TableCell>
                  <TableCell className="tabular-nums">{row.link.access_counter}</TableCell>
                  <TableCell className="text-muted-foreground">
                    {row.link.expires_at
                      ? formatStoreDateTime(row.link.expires_at, timezone)
                      : t('admin.digital_links.never_expires')}
                  </TableCell>
                  <TableCell>
                    <StatusBadge
                      status={statusFor(row.link)}
                      label={t(`admin.digital_links.status.${statusFor(row.link)}`)}
                    />
                  </TableCell>
                  <TableCell className="text-right">
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      disabled={resetLink.isPending}
                      onClick={() => handleReset(row)}
                    >
                      <RotateCcwIcon className="mr-2 size-4" />
                      {t('admin.digital_links.reset')}
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      </CardContent>
    </Card>
  )
}

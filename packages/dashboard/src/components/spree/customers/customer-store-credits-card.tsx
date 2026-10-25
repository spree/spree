import type { Customer, StoreCredit } from '@spree/admin-sdk'
import { Money } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import { EllipsisVerticalIcon, PencilIcon, PlusIcon, TrashIcon } from '@spree/dashboard-ui/icons'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useDeleteCustomerStoreCredit } from '../../../hooks/use-customer-store-credits'
import { EditStoreCreditDialog } from '../store-credits/edit-store-credit-dialog'
import { IssueStoreCreditDialog } from '../store-credits/issue-store-credit-dialog'

export function CustomerStoreCreditsCard({ customer }: { customer: Customer }) {
  const { t } = useTranslation()
  const [addOpen, setAddOpen] = useState(false)
  const [editing, setEditing] = useState<StoreCredit | null>(null)
  const confirm = useConfirm()
  const credits = customer.store_credits ?? []

  const deleteMutation = useDeleteCustomerStoreCredit()

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
                      <Money amount={sc.amount} currency={sc.currency} />
                    </TableCell>
                    <TableCell className="tabular-nums">
                      <Money amount={sc.amount_used} currency={sc.currency} />
                    </TableCell>
                    <TableCell className="tabular-nums">
                      <Money amount={sc.amount_remaining} currency={sc.currency} />
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
                                deleteMutation.mutate({ customerId: customer.id, id: sc.id })
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

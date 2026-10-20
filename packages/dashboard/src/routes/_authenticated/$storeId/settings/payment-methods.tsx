import type { PaymentMethod } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import { Button, RowActions, useConfirm, useRowClickBridge } from '@spree/dashboard-ui'
import { PlusIcon } from '@spree/dashboard-ui/icons'
import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import {
  CreatePaymentMethodSheet,
  EditPaymentMethodSheet,
} from '../../../../components/spree/payment-method-editors/payment-method-sheets'
import { useDeletePaymentMethod } from '../../../../hooks/use-payment-methods'
import '../../../../tables/payment-methods'

const paymentMethodsSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/payment-methods')({
  validateSearch: paymentMethodsSearchSchema,
  component: PaymentMethodsPage,
})

function PaymentMethodsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof paymentMethodsSearchSchema>
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const confirm = useConfirm()
  const deleteMutation = useDeletePaymentMethod()
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

  useRowClickBridge('data-payment-method-id', openEdit)

  async function handleDelete(method: PaymentMethod) {
    const ok = await confirm({
      title: t('admin.payment_methods.delete_confirm.title'),
      message: t('admin.payment_methods.delete_confirm.message', { name: method.name ?? '' }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    // `useDeletePaymentMethod` toasts on success/error via `onError`; the
    // `.catch` only swallows the rethrow so the row-action callback doesn't
    // surface an unhandled rejection.
    await deleteMutation.mutateAsync(method.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<PaymentMethod>
        tableKey="payment-methods"
        queryKey="payment-methods"
        queryFn={(params) => adminClient.paymentMethods.list(params)}
        searchParams={search}
        rowActions={(method) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(method.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.PaymentMethod),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(method),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.PaymentMethod}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.payment_methods.add_cta')}
            </Button>
          </Can>
        }
        reorder={{
          onReorder: async (id, position) => {
            await adminClient.paymentMethods.update(id, { position })
            queryClient.invalidateQueries({ queryKey: ['payment-methods'] })
          },
        }}
      />

      {isCreating && <CreatePaymentMethodSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && (
        <EditPaymentMethodSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />
      )}
    </>
  )
}

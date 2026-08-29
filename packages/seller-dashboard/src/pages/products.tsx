import type {
  BulkAction,
  BulkActionFormProps,
  BulkActionOutcome,
  ResourceSearch,
} from '@spree/dashboard-core'
import {
  ExportButton,
  ImportButton,
  ImportWizardDialog,
  PageHeader,
  ResourceTable,
  Subject,
} from '@spree/dashboard-core'
import {
  BulkDialog,
  Button,
  Field,
  FieldLabel,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  toastManager,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import type { BulkProductResult, Product } from '@spree/seller-sdk'
import { useNavigate, useParams } from '@tanstack/react-router'
import { ArchiveIcon, PlusIcon, SendIcon, Trash2Icon } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import '../tables/products'

/**
 * The statuses a seller may move a selection to.
 *
 * `active` is absent by design: a listing goes on sale when the marketplace
 * approves it, so the only moves offered here are the two a seller makes
 * alone (docs/plans/6.0-seller-product-submission.md).
 */
const BULK_STATUSES = ['draft', 'archived'] as const

type BulkStatus = (typeof BULK_STATUSES)[number]
type StatusFormValues = { status: BulkStatus }

/** This seller's own catalog. */
export function ProductsPage({ search }: { search: ResourceSearch & { import?: string } }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const navigate = useNavigate()

  const open = (productId: string) =>
    navigate({ to: '/$sellerId/products/$productId', params: { sellerId, productId } })

  useRowClickBridge('data-product-id', open)

  const bulkActions = useMemo<BulkAction<unknown>[]>(() => {
    // These endpoints move what they can and leave the rest, so the selection
    // size is not the outcome. The success toast is told what the server
    // actually did, and anything it left alone gets a second toast saying so —
    // otherwise "15 submitted" sits next to "12 were left alone".
    const report = (result: BulkProductResult, skippedMessage: string): BulkActionOutcome => {
      if (result.skipped_count) {
        toastManager.add({
          type: 'info',
          title: t('products.bulk.skipped', {
            count: result.skipped_count,
            message: skippedMessage,
          }),
        })
      }

      return { count: result.product_count }
    }

    const submitAction: BulkAction<unknown> = {
      key: 'submit-for-review',
      label: t('products.submit_for_review'),
      icon: <SendIcon className="size-4" />,
      subject: Subject.Product,
      confirm: {
        title: t('products.bulk.submit_confirm_title'),
        message: t('products.bulk.submit_confirm_description'),
        confirmLabel: t('products.submit_for_review'),
      },
      run: async ({ ids }) =>
        report(
          await sellerClient().products.bulkSubmit({ ids }),
          t('products.bulk.skipped_submit'),
        ),
      successMessage: t('products.bulk.submitted'),
      errorMessage: t('products.bulk.submit_failed'),
    }

    const statusAction: BulkAction<StatusFormValues> = {
      key: 'set-status',
      label: t('products.bulk.set_status_action'),
      icon: <ArchiveIcon className="size-4" />,
      subject: Subject.Product,
      form: (props) => <StatusPickerDialog {...props} />,
      run: async ({ ids, formValues }) =>
        report(
          await sellerClient().products.bulkStatusUpdate({ ids, status: formValues!.status }),
          t('products.bulk.skipped_refused'),
        ),
      successMessage: t('products.bulk.status_updated'),
      errorMessage: t('products.bulk.status_update_failed'),
    }

    const deleteAction: BulkAction<unknown> = {
      key: 'delete',
      label: t('common.delete'),
      icon: <Trash2Icon className="size-4" />,
      subject: Subject.Product,
      action: 'destroy',
      confirm: {
        title: t('products.bulk.delete_confirm_title'),
        message: t('products.bulk.delete_confirm_description'),
        confirmLabel: t('common.delete'),
        variant: 'destructive',
      },
      run: async ({ ids }) =>
        report(
          await sellerClient().products.bulkDestroy({ ids }),
          t('products.bulk.skipped_refused'),
        ),
      successMessage: t('products.bulk.deleted'),
      errorMessage: t('products.bulk.delete_failed'),
    }

    return [submitAction, statusAction, deleteAction] as BulkAction<unknown>[]
  }, [t])

  // The wizard is driven by an `?import=` param rather than component state,
  // so a refresh (or the link in the import-done email) reopens it.
  const openImportWizard = (id: string) =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, import: id }) as never })

  const closeImportWizard = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { import: _i, ...rest } = prev
        return rest as never
      },
    })

  return (
    <div className="flex flex-col gap-4">
      <PageHeader title={t('products.title')} />

      <ResourceTable<Product>
        tableKey="seller-products"
        queryKey="seller-products"
        queryFn={(params) => sellerClient().products.list(params)}
        searchParams={search}
        bulkActions={bulkActions}
        actions={(ctx) => (
          <>
            <ImportButton
              type="products"
              subject={Subject.Product}
              onCreated={(imp) => openImportWizard(imp.id)}
              resultsPath={`/${sellerId}/products`}
            />
            <ExportButton type="products" {...ctx} />
            <Button
              onClick={() => navigate({ to: '/$sellerId/products/new', params: { sellerId } })}
            >
              <PlusIcon className="size-4" />
              {t('products.add')}
            </Button>
          </>
        )}
      />

      <ImportWizardDialog
        importId={search.import ?? null}
        onClose={closeImportWizard}
        // Imported products land as drafts awaiting review, so "view records"
        // returns to this very list — where the seller submits them.
        onViewRecords={() => navigate({ to: '/$sellerId/products', params: { sellerId } })}
      />
    </div>
  )
}

function StatusPickerDialog({ onSubmit, onCancel }: BulkActionFormProps<StatusFormValues>) {
  const { t } = useTranslation()
  const [status, setStatus] = useState<BulkStatus>('draft')

  const statusItems = BULK_STATUSES.map((value) => ({
    value,
    label: t(`products.statuses.${value}`),
  }))

  return (
    <BulkDialog
      title={t('products.bulk.status_dialog_title')}
      description={t('products.bulk.status_dialog_description')}
      submitLabel={t('common.apply')}
      onCancel={onCancel}
      onSubmit={() => onSubmit({ status })}
    >
      <Field>
        <FieldLabel>{t('products.fields.status')}</FieldLabel>
        <Select
          items={statusItems}
          value={status}
          onValueChange={(value) => setStatus(value as BulkStatus)}
        >
          <SelectTrigger>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {statusItems.map((item) => (
              <SelectItem key={item.value} value={item.value}>
                {item.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </Field>
    </BulkDialog>
  )
}

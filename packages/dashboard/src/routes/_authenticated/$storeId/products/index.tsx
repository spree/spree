import type { Product } from '@spree/admin-sdk'
import { adminClient, Subject, usePermissions } from '@spree/dashboard-core'
import {
  BulkDialog,
  Button,
  Field,
  FieldLabel,
  RowActions,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  useConfirm,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import {
  FolderMinusIcon,
  FolderPlusIcon,
  PlusIcon,
  TagIcon,
  TagsIcon,
  Trash2Icon,
} from 'lucide-react'
import { useCallback, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import type { BulkAction, BulkActionFormProps } from '@/components/spree/bulk-action-bar'
import { ExportButton } from '@/components/spree/export-button'
import { ResourceMultiAutocomplete } from '@/components/spree/resource-multi-autocomplete'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
import { TagCombobox } from '@/components/spree/tag-combobox'
import { categoryAutocompleteProps } from '@/hooks/use-categories'
import { useDeleteProduct } from '@/hooks/use-product'
import {
  useBulkAddProductsToCategories,
  useBulkAddProductTags,
  useBulkDestroyProducts,
  useBulkProductStatusUpdate,
  useBulkRemoveProductsFromCategories,
  useBulkRemoveProductTags,
  useCloneProduct,
} from '@/hooks/use-products'
import '@/tables/products'

export const Route = createFileRoute('/_authenticated/$storeId/products/')({
  validateSearch: resourceSearchSchema,
  component: ProductsPage,
})

type ProductStatus = 'draft' | 'active' | 'archived'
type StatusFormValues = { status: ProductStatus }
type CategoriesFormValues = { category_ids: string[] }
type TagsFormValues = { tags: string[] }

function ProductsPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const searchParams = Route.useSearch()

  const bulkStatus = useBulkProductStatusUpdate()
  const bulkAddCategories = useBulkAddProductsToCategories()
  const bulkRemoveCategories = useBulkRemoveProductsFromCategories()
  const bulkAddTags = useBulkAddProductTags()
  const bulkRemoveTags = useBulkRemoveProductTags()
  const bulkDestroy = useBulkDestroyProducts()

  // Memo: rebuilding the array (and the row-actions render-prop) on every
  // mutation `isPending` toggle would force `<ResourceTable>` to re-render
  // every visible row.
  const bulkActions = useMemo<BulkAction<unknown>[]>(() => {
    const statusAction: BulkAction<StatusFormValues> = {
      key: 'set-status',
      label: t('admin.pages.products.bulk.set_status_action'),
      icon: <TagIcon className="size-4" />,
      subject: Subject.Product,
      form: (props) => <StatusPickerSheet {...props} />,
      run: ({ ids, formValues }) => bulkStatus.mutateAsync({ ids, status: formValues!.status }),
      successMessage: t('admin.pages.products.bulk.status_updated'),
      errorMessage: t('admin.pages.products.bulk.status_update_failed'),
    }

    const addCategories: BulkAction<CategoriesFormValues> = {
      key: 'add-to-categories',
      label: t('admin.pages.products.bulk.add_categories_action'),
      icon: <FolderPlusIcon className="size-4" />,
      subject: Subject.Product,
      form: (props) => (
        <CategoryPickerSheet
          {...props}
          title={t('admin.pages.products.bulk.categories_add_title')}
          description={t('admin.pages.products.bulk.categories_add_description')}
          submitLabel={t('admin.actions.add')}
        />
      ),
      run: ({ ids, formValues }) =>
        bulkAddCategories.mutateAsync({ ids, category_ids: formValues!.category_ids }),
      invalidate: [['categories']],
      successMessage: t('admin.pages.products.bulk.categories_added'),
      errorMessage: t('admin.pages.products.bulk.categories_add_failed'),
    }

    const removeCategories: BulkAction<CategoriesFormValues> = {
      key: 'remove-from-categories',
      label: t('admin.pages.products.bulk.remove_categories_action'),
      icon: <FolderMinusIcon className="size-4" />,
      subject: Subject.Product,
      form: (props) => (
        <CategoryPickerSheet
          {...props}
          title={t('admin.pages.products.bulk.categories_remove_title')}
          description={t('admin.pages.products.bulk.categories_remove_description')}
          submitLabel={t('admin.actions.remove')}
        />
      ),
      run: ({ ids, formValues }) =>
        bulkRemoveCategories.mutateAsync({ ids, category_ids: formValues!.category_ids }),
      invalidate: [['categories']],
      successMessage: t('admin.pages.products.bulk.categories_removed'),
      errorMessage: t('admin.pages.products.bulk.categories_remove_failed'),
    }

    const addTags: BulkAction<TagsFormValues> = {
      key: 'add-tags',
      label: t('admin.pages.products.bulk.add_tags_action'),
      icon: <TagsIcon className="size-4" />,
      subject: Subject.Product,
      form: (props) => (
        <TagPickerSheet
          {...props}
          title={t('admin.pages.products.bulk.tags_add_title')}
          description={t('admin.pages.products.bulk.tags_add_description')}
          submitLabel={t('admin.actions.add')}
        />
      ),
      run: ({ ids, formValues }) => bulkAddTags.mutateAsync({ ids, tags: formValues!.tags }),
      successMessage: t('admin.pages.products.bulk.tags_added'),
      errorMessage: t('admin.pages.products.bulk.tags_add_failed'),
    }

    const removeTags: BulkAction<TagsFormValues> = {
      key: 'remove-tags',
      label: t('admin.pages.products.bulk.remove_tags_action'),
      icon: <TagsIcon className="size-4" />,
      subject: Subject.Product,
      form: (props) => (
        <TagPickerSheet
          {...props}
          title={t('admin.pages.products.bulk.tags_remove_title')}
          description={t('admin.pages.products.bulk.tags_remove_description')}
          submitLabel={t('admin.actions.remove')}
        />
      ),
      run: ({ ids, formValues }) => bulkRemoveTags.mutateAsync({ ids, tags: formValues!.tags }),
      successMessage: t('admin.pages.products.bulk.tags_removed'),
      errorMessage: t('admin.pages.products.bulk.tags_remove_failed'),
    }

    const deleteAction: BulkAction<unknown> = {
      key: 'delete',
      label: t('admin.pages.products.bulk.delete_action'),
      icon: <Trash2Icon className="size-4" />,
      subject: Subject.Product,
      action: 'destroy',
      confirm: {
        title: t('admin.pages.products.bulk.delete_confirm.title'),
        message: t('admin.pages.products.bulk.delete_confirm.message'),
        confirmLabel: t('admin.actions.delete'),
        variant: 'destructive',
      },
      run: ({ ids }) => bulkDestroy.mutateAsync({ ids }),
      successMessage: t('admin.pages.products.bulk.deleted'),
      errorMessage: t('admin.pages.products.bulk.delete_failed'),
    }

    return [
      statusAction,
      addCategories,
      removeCategories,
      addTags,
      removeTags,
      deleteAction,
    ] as BulkAction<unknown>[]
  }, [
    t,
    bulkStatus,
    bulkAddCategories,
    bulkRemoveCategories,
    bulkAddTags,
    bulkRemoveTags,
    bulkDestroy,
  ])

  const renderRowActions = useCallback(
    (product: Product) => <ProductRowActions product={product} storeId={storeId} />,
    [storeId],
  )

  return (
    <ResourceTable
      tableKey="products"
      queryKey="products"
      queryFn={(params) => adminClient.products.list(params)}
      searchParams={searchParams}
      bulkActions={bulkActions}
      rowActions={renderRowActions}
      actions={(ctx) => (
        <>
          <ExportButton type="Spree::Exports::Products" {...ctx} />
          <Button size="sm" className="h-[2.125rem]">
            <PlusIcon className="size-4" />
            Add Product
          </Button>
        </>
      )}
    />
  )
}

function ProductRowActions({ product, storeId }: { product: Product; storeId: string }) {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const confirm = useConfirm()
  const cloneMutation = useCloneProduct()
  const deleteMutation = useDeleteProduct()
  const { permissions } = usePermissions()

  async function handleClone() {
    const cloned = await cloneMutation.mutateAsync(product.id).catch(() => null)
    if (!cloned) return
    navigate({
      to: '/$storeId/products/$productId',
      params: { storeId, productId: cloned.id },
    })
  }

  async function handleDelete() {
    const ok = await confirm({
      title: t('admin.products.delete_label'),
      message: t('admin.products.delete_confirm'),
      confirmLabel: t('admin.actions.delete'),
      variant: 'destructive',
    })
    if (!ok) return

    try {
      await deleteMutation.mutateAsync(product.id)
      toast.success(t('admin.pages.products.delete_succeeded'))
    } catch {
      toast.error(t('admin.pages.products.delete_failed'))
    }
  }

  return (
    <RowActions
      actions={[
        {
          key: 'edit',
          onSelect: () =>
            navigate({
              to: '/$storeId/products/$productId',
              params: { storeId, productId: product.id },
            }),
        },
        {
          key: 'clone',
          visible: permissions.can('create', Subject.Product),
          disabled: cloneMutation.isPending,
          onSelect: handleClone,
        },
        {
          key: 'delete',
          destructive: true,
          visible: permissions.can('destroy', Subject.Product),
          disabled: deleteMutation.isPending,
          onSelect: handleDelete,
        },
      ]}
    />
  )
}

function StatusPickerSheet({ onSubmit, onCancel }: BulkActionFormProps<StatusFormValues>) {
  const { t } = useTranslation()
  const [status, setStatus] = useState<ProductStatus>('active')

  return (
    <BulkDialog
      title={t('admin.pages.products.bulk.status_sheet_title')}
      description={t('admin.pages.products.bulk.status_sheet_description')}
      submitLabel={t('admin.actions.apply')}
      onCancel={onCancel}
      onSubmit={() => onSubmit({ status })}
    >
      <Field>
        <FieldLabel>{t('admin.fields.status.label')}</FieldLabel>
        <Select value={status} onValueChange={(v) => setStatus(v as ProductStatus)}>
          <SelectTrigger>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="draft">{t('admin.pages.products.status_options.draft')}</SelectItem>
            <SelectItem value="active">
              {t('admin.pages.products.status_options.active')}
            </SelectItem>
            <SelectItem value="archived">
              {t('admin.pages.products.status_options.archived')}
            </SelectItem>
          </SelectContent>
        </Select>
      </Field>
    </BulkDialog>
  )
}

interface CopyProps {
  title: string
  description: string
  submitLabel: string
}

function CategoryPickerSheet({
  onSubmit,
  onCancel,
  title,
  description,
  submitLabel,
}: BulkActionFormProps<CategoriesFormValues> & CopyProps) {
  const { t } = useTranslation()
  const [categoryIds, setCategoryIds] = useState<string[]>([])

  return (
    <BulkDialog
      title={title}
      description={description}
      submitLabel={submitLabel}
      submitDisabled={categoryIds.length === 0}
      onCancel={onCancel}
      onSubmit={() => onSubmit({ category_ids: categoryIds })}
    >
      <Field>
        <FieldLabel>{t('admin.fields.product.category_ids.label')}</FieldLabel>
        <ResourceMultiAutocomplete
          {...categoryAutocompleteProps('bulk-products-category-picker')}
          value={categoryIds}
          onChange={setCategoryIds}
        />
      </Field>
    </BulkDialog>
  )
}

function TagPickerSheet({
  onSubmit,
  onCancel,
  title,
  description,
  submitLabel,
}: BulkActionFormProps<TagsFormValues> & CopyProps) {
  const { t } = useTranslation()
  const [tags, setTags] = useState<string[]>([])

  return (
    <BulkDialog
      title={title}
      description={description}
      submitLabel={submitLabel}
      submitDisabled={tags.length === 0}
      onCancel={onCancel}
      onSubmit={() => onSubmit({ tags })}
    >
      <Field>
        <FieldLabel>{t('admin.fields.product.tags.label')}</FieldLabel>
        <TagCombobox taggableType="Spree::Product" value={tags} onChange={setTags} />
      </Field>
    </BulkDialog>
  )
}

import type { Product } from '@spree/admin-sdk'
import type { BulkAction, BulkActionFormProps, ColumnDef } from '@spree/dashboard-core'
import {
  adminClient,
  ExportButton,
  ImportButton,
  ResourceMultiAutocomplete,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  TagCombobox,
  useCustomFieldDefinitions,
  usePermissions,
} from '@spree/dashboard-core'
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
import {
  FolderMinusIcon,
  FolderPlusIcon,
  LayersIcon,
  PlusIcon,
  RadioTowerIcon,
  StoreIcon,
  TagIcon,
  TagsIcon,
  Trash2Icon,
} from '@spree/dashboard-ui/icons'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useCallback, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { ImportWizardDialog } from '../../../../components/spree/imports/import-wizard-dialog'
import { categoryAutocompleteProps, useCategories } from '../../../../hooks/use-categories'
import { channelAutocompleteProps, useChannels } from '../../../../hooks/use-channels'
import { collectionAutocompleteProps, useCollections } from '../../../../hooks/use-collections'
import { useDeleteProduct } from '../../../../hooks/use-product'
import {
  useBulkAddProductsToCategories,
  useBulkAddProductsToChannels,
  useBulkAddProductsToCollections,
  useBulkAddProductTags,
  useBulkCloseProductsToSellers,
  useBulkDestroyProducts,
  useBulkOpenProductsToSellers,
  useBulkProductStatusUpdate,
  useBulkRemoveProductsFromCategories,
  useBulkRemoveProductsFromChannels,
  useBulkRemoveProductsFromCollections,
  useBulkRemoveProductTags,
  useCloneProduct,
} from '../../../../hooks/use-products'
import { useSellers } from '../../../../hooks/use-sellers'
import '../../../../tables/products'
import { toastManager } from '@spree/dashboard-ui'

// `import` carries the prefixed id of the import whose wizard dialog is open
// over the table — deep-linkable and refresh-safe.
const productsSearchSchema = resourceSearchSchema.extend({
  import: z.string().optional(),
})

// Custom field type → filter operator set. Anything unmapped filters as text.
// Narrowed to the variants that need no companion field (`enum` needs
// `filterOptions`, `tags` needs `taggableType`, and so on).
const CUSTOM_FIELD_FILTER_TYPES: Record<string, 'string' | 'number' | 'boolean'> = {
  number: 'number',
  boolean: 'boolean',
}

export const Route = createFileRoute('/_authenticated/$storeId/products/')({
  validateSearch: productsSearchSchema,
  component: ProductsPage,
})

type ProductStatus = 'draft' | 'active' | 'archived'
type StatusFormValues = { status: ProductStatus }
type CategoriesFormValues = { category_ids: string[] }
type CollectionsFormValues = { collection_ids: string[] }
type ChannelsFormValues = { channel_ids: string[] }
type TagsFormValues = { tags: string[] }

function ProductsPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const searchParams = Route.useSearch() as z.infer<typeof productsSearchSchema>
  const navigate = useNavigate()

  const openImportWizard = (id: string) =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, import: id }) as never })

  const closeImportWizard = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { import: _i, ...rest } = prev
        return rest as never
      },
    })

  const bulkStatus = useBulkProductStatusUpdate()
  const bulkAddCategories = useBulkAddProductsToCategories()
  const bulkRemoveCategories = useBulkRemoveProductsFromCategories()
  const bulkAddCollections = useBulkAddProductsToCollections()
  const bulkRemoveCollections = useBulkRemoveProductsFromCollections()
  const bulkAddChannels = useBulkAddProductsToChannels()
  const bulkRemoveChannels = useBulkRemoveProductsFromChannels()
  const bulkAddTags = useBulkAddProductTags()
  const bulkRemoveTags = useBulkRemoveProductTags()
  const bulkDestroy = useBulkDestroyProducts()
  const bulkOpenToSellers = useBulkOpenProductsToSellers()
  const bulkCloseToSellers = useBulkCloseProductsToSellers()
  // Only whether the store has any sellers at all: the marketplace bulk
  // actions are hidden entirely on a store selling purely its own goods.
  const { data: sellers } = useSellers({ limit: 1 })
  const hasSellers = (sellers?.data.length ?? 0) > 0

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

    const addCollections: BulkAction<CollectionsFormValues> = {
      key: 'add-to-collections',
      label: t('admin.pages.products.bulk.add_collections_action'),
      icon: <LayersIcon className="size-4" />,
      subject: Subject.Product,
      form: (props) => (
        <CollectionPickerSheet
          {...props}
          title={t('admin.pages.products.bulk.collections_add_title')}
          description={t('admin.pages.products.bulk.collections_add_description')}
          submitLabel={t('admin.actions.add')}
        />
      ),
      run: ({ ids, formValues }) =>
        bulkAddCollections.mutateAsync({ ids, collection_ids: formValues!.collection_ids }),
      invalidate: [['collections']],
      successMessage: t('admin.pages.products.bulk.collections_added'),
      errorMessage: t('admin.pages.products.bulk.collections_add_failed'),
    }

    const removeCollections: BulkAction<CollectionsFormValues> = {
      key: 'remove-from-collections',
      label: t('admin.pages.products.bulk.remove_collections_action'),
      icon: <LayersIcon className="size-4" />,
      subject: Subject.Product,
      form: (props) => (
        <CollectionPickerSheet
          {...props}
          title={t('admin.pages.products.bulk.collections_remove_title')}
          description={t('admin.pages.products.bulk.collections_remove_description')}
          submitLabel={t('admin.actions.remove')}
        />
      ),
      run: ({ ids, formValues }) =>
        bulkRemoveCollections.mutateAsync({ ids, collection_ids: formValues!.collection_ids }),
      invalidate: [['collections']],
      successMessage: t('admin.pages.products.bulk.collections_removed'),
      errorMessage: t('admin.pages.products.bulk.collections_remove_failed'),
    }

    const addChannels: BulkAction<ChannelsFormValues> = {
      key: 'add-to-channels',
      label: t('admin.pages.products.bulk.add_channels_action'),
      icon: <RadioTowerIcon className="size-4" />,
      subject: Subject.Product,
      form: (props) => (
        <ChannelPickerSheet
          {...props}
          title={t('admin.pages.products.bulk.channels_add_title')}
          description={t('admin.pages.products.bulk.channels_add_description')}
          submitLabel={t('admin.actions.add')}
        />
      ),
      run: ({ ids, formValues }) =>
        bulkAddChannels.mutateAsync({ ids, channel_ids: formValues!.channel_ids }),
      invalidate: [['channels']],
      successMessage: t('admin.pages.products.bulk.channels_added'),
      errorMessage: t('admin.pages.products.bulk.channels_add_failed'),
    }

    const removeChannels: BulkAction<ChannelsFormValues> = {
      key: 'remove-from-channels',
      label: t('admin.pages.products.bulk.remove_channels_action'),
      icon: <RadioTowerIcon className="size-4" />,
      subject: Subject.Product,
      form: (props) => (
        <ChannelPickerSheet
          {...props}
          title={t('admin.pages.products.bulk.channels_remove_title')}
          description={t('admin.pages.products.bulk.channels_remove_description')}
          submitLabel={t('admin.actions.remove')}
        />
      ),
      run: ({ ids, formValues }) =>
        bulkRemoveChannels.mutateAsync({ ids, channel_ids: formValues!.channel_ids }),
      invalidate: [['channels']],
      successMessage: t('admin.pages.products.bulk.channels_removed'),
      errorMessage: t('admin.pages.products.bulk.channels_remove_failed'),
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
      label: t('admin.actions.delete'),
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

    // Opening the shared catalog, and closing it again. Only shown where it
    // can mean something — a store with no sellers has nothing to open to
    // (docs/plans/6.0-seller-master-catalog-listings.md, Decision 2).
    const openToSellers: BulkAction<unknown> = {
      key: 'open-to-sellers',
      label: t('admin.products.offers.bulk_open'),
      icon: <StoreIcon className="size-4" />,
      subject: Subject.Product,
      run: ({ ids }) => bulkOpenToSellers.mutateAsync({ ids }),
      successMessage: t('admin.products.offers.bulk_opened'),
      errorMessage: t('admin.products.offers.bulk_failed'),
    }

    const closeToSellers: BulkAction<unknown> = {
      key: 'close-to-sellers',
      label: t('admin.products.offers.bulk_close'),
      icon: <StoreIcon className="size-4" />,
      subject: Subject.Product,
      run: ({ ids }) => bulkCloseToSellers.mutateAsync({ ids }),
      successMessage: t('admin.products.offers.bulk_closed'),
      errorMessage: t('admin.products.offers.bulk_failed'),
    }

    return [
      statusAction,
      ...(hasSellers ? [openToSellers, closeToSellers] : []),
      addCategories,
      removeCategories,
      addCollections,
      removeCollections,
      addChannels,
      removeChannels,
      addTags,
      removeTags,
      deleteAction,
    ] as BulkAction<unknown>[]
  }, [
    t,
    bulkStatus,
    bulkAddCategories,
    bulkRemoveCategories,
    bulkAddCollections,
    bulkRemoveCollections,
    bulkAddChannels,
    bulkRemoveChannels,
    bulkAddTags,
    bulkRemoveTags,
    bulkDestroy,
    bulkOpenToSellers,
    bulkCloseToSellers,
    hasSellers,
  ])

  const renderRowActions = useCallback(
    (product: Product) => <ProductRowActions product={product} storeId={storeId} />,
    [storeId],
  )

  const { data: definitionsResponse } = useCustomFieldDefinitions('Spree::Product')
  // Searchable/sortable custom fields become full table columns: displayable
  // (opt-in via the column selector), sortable when the definition allows it,
  // and filterable with the operator set matching the field type.
  const customFieldColumns = useMemo<ColumnDef<Product>[]>(() => {
    const definitions = definitionsResponse?.data ?? []
    return definitions
      .filter(
        (definition) => (definition.searchable || definition.sortable) && definition.filter_key,
      )
      .map((definition) => ({
        key: definition.filter_key,
        label: definition.label,
        default: false,
        sortable: definition.sortable,
        filterable: true,
        filterType: CUSTOM_FIELD_FILTER_TYPES[definition.field_type] ?? 'string',
        expand: 'custom_fields',
        render: (product: Product) => {
          const value = product.custom_fields?.find(
            (field) => field.custom_field_definition_id === definition.id,
          )?.value
          return value == null || value === '' ? '—' : String(value)
        },
      }))
  }, [definitionsResponse])

  return (
    <>
      <ResourceTable
        tableKey="products"
        queryKey="products"
        queryFn={(params) => adminClient.products.list(params)}
        defaultParams={{ expand: ['channels'] }}
        searchParams={searchParams}
        bulkActions={bulkActions}
        rowActions={renderRowActions}
        customFieldColumns={customFieldColumns}
        actions={(ctx) => (
          <>
            <ImportButton
              type="products"
              subject={Subject.Product}
              onCreated={(imp) => openImportWizard(imp.id)}
            />
            <ExportButton type="products" {...ctx} />
            <Button
              size="sm"
              className="h-[2.125rem]"
              onClick={() => navigate({ to: '/$storeId/products/new', params: { storeId } })}
            >
              <PlusIcon className="size-4" />
              {t('admin.pages.products.add_cta')}
            </Button>
          </>
        )}
      />
      <ImportWizardDialog importId={searchParams.import ?? null} onClose={closeImportWizard} />
    </>
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
      toastManager.add({ type: 'success', title: t('admin.pages.products.delete_succeeded') })
    } catch {
      toastManager.add({ type: 'error', title: t('admin.pages.products.delete_failed') })
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

const PRODUCT_STATUSES: ProductStatus[] = ['draft', 'active', 'archived']

function StatusPickerSheet({ onSubmit, onCancel }: BulkActionFormProps<StatusFormValues>) {
  const { t } = useTranslation()
  const [status, setStatus] = useState<ProductStatus>('active')

  const statusItems = PRODUCT_STATUSES.map((value) => ({
    value,
    label: t(`admin.pages.products.status_options.${value}`),
  }))

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
        <Select
          items={statusItems}
          value={status}
          onValueChange={(v) => setStatus(v as ProductStatus)}
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
  // Surface the store's categories on focus so the merchant doesn't have to
  // type to discover them. The list is small and already cached by
  // +useCategories+ (5-min stale time).
  const { data: categoriesData } = useCategories()

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
          initialItems={categoriesData?.data}
          value={categoryIds}
          onChange={setCategoryIds}
        />
      </Field>
    </BulkDialog>
  )
}

function CollectionPickerSheet({
  onSubmit,
  onCancel,
  title,
  description,
  submitLabel,
}: BulkActionFormProps<CollectionsFormValues> & CopyProps) {
  const { t } = useTranslation()
  const [collectionIds, setCollectionIds] = useState<string[]>([])
  // Only manual collections are offered — an automatic collection's members
  // come from its rules, and the API skips it on a bulk add.
  const { data: collectionsData } = useCollections()
  const manualCollections = collectionsData?.data.filter((c) => !c.automatic)

  return (
    <BulkDialog
      title={title}
      description={description}
      submitLabel={submitLabel}
      submitDisabled={collectionIds.length === 0}
      onCancel={onCancel}
      onSubmit={() => onSubmit({ collection_ids: collectionIds })}
    >
      <Field>
        <FieldLabel>{t('admin.fields.product.collection_ids.label')}</FieldLabel>
        <ResourceMultiAutocomplete
          {...collectionAutocompleteProps('bulk-products-collection-picker')}
          initialItems={manualCollections}
          value={collectionIds}
          onChange={setCollectionIds}
        />
      </Field>
    </BulkDialog>
  )
}

function ChannelPickerSheet({
  onSubmit,
  onCancel,
  title,
  description,
  submitLabel,
}: BulkActionFormProps<ChannelsFormValues> & CopyProps) {
  const { t } = useTranslation()
  const [channelIds, setChannelIds] = useState<string[]>([])
  // Surface all channels on focus so the merchant doesn't have to type to
  // discover them. The list is small and already cached by +useChannels+.
  const { data: channelsData } = useChannels()

  return (
    <BulkDialog
      title={title}
      description={description}
      submitLabel={submitLabel}
      submitDisabled={channelIds.length === 0}
      onCancel={onCancel}
      onSubmit={() => onSubmit({ channel_ids: channelIds })}
    >
      <Field>
        <FieldLabel>{t('admin.fields.product.channels.label')}</FieldLabel>
        <ResourceMultiAutocomplete
          {...channelAutocompleteProps('bulk-products-channel-picker')}
          initialItems={channelsData?.data}
          value={channelIds}
          onChange={setChannelIds}
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

import { zodResolver } from '@hookform/resolvers/zod'
import { SpreeError } from '@spree/admin-sdk'
import {
  adminClient,
  extensionFormValues,
  extensionSubmitValues,
  mapSpreeErrorsToForm,
  PageHeader,
  Slot,
} from '@spree/dashboard-core'
import {
  ErrorState,
  FormActions,
  ResourceLayout,
  Skeleton,
  toastManager,
  useConfirm,
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { createFileRoute, useRouter } from '@tanstack/react-router'
import { useEffect } from 'react'
import { FormProvider, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  CollectionMain,
  CollectionSidebar,
} from '../../../../../components/spree/collections/collection-form'
import {
  useCollection,
  useDeleteCollection,
  useUpdateCollection,
} from '../../../../../hooks/use-collections'
import {
  COLLECTION_DEFAULTS,
  type CollectionFormValues,
  collectionFormSchema,
  collectionToForm,
  collectionToParams,
} from '../../../../../schemas/collection'

export const Route = createFileRoute('/_authenticated/$storeId/products/collections/$collectionId')(
  {
    component: CollectionDetailPage,
  },
)

function CollectionDetailPage() {
  const { t } = useTranslation()
  const { storeId, collectionId } = Route.useParams()
  const { data: collection, isLoading, error, refetch } = useCollection(collectionId)

  if (isLoading) return <CollectionSkeleton />
  if (error || !collection) {
    return (
      <ErrorState
        title={t('admin.collections.load_failed')}
        error={error as Error | undefined}
        onRetry={() => refetch()}
      />
    )
  }

  return <CollectionDetail key={collection.id} collectionId={collectionId} storeId={storeId} />
}

function CollectionDetail({ collectionId, storeId }: { collectionId: string; storeId: string }) {
  const { t } = useTranslation()
  const router = useRouter()
  const confirm = useConfirm()
  const { data: collection } = useCollection(collectionId)
  const updateCollection = useUpdateCollection(collectionId)
  const deleteCollection = useDeleteCollection()

  const form = useForm<CollectionFormValues>({
    resolver: zodResolver(collectionFormSchema),
    defaultValues: { ...COLLECTION_DEFAULTS, ...extensionFormValues('collection', null) },
  })

  // Hydrate (and re-baseline after save) from the source row, unless the
  // merchant has unsaved edits in flight.
  useEffect(() => {
    if (!collection || form.formState.isDirty) return
    form.reset({
      ...collectionToForm(collection),
      ...extensionFormValues('collection', collection),
    })
  }, [collection, form])

  const onSubmit = async (values: CollectionFormValues) => {
    // Read before any reset — extension values live in raw form state (the
    // Zod parse behind `values` strips keys the schema doesn't know).
    const extensionValues = extensionSubmitValues('collection', form)
    try {
      await updateCollection.mutateAsync({ ...collectionToParams(values), ...extensionValues })
      // Re-baseline so isDirty flips false before the refetch lands; drop the
      // consumed signed_ids + clear flags so a second save can't re-send a
      // stale upload/purge (the refetch hydrates the persisted image state).
      form.reset({
        ...values,
        ...extensionValues,
        image_signed_id: null,
        image_cleared: false,
        square_image_signed_id: null,
        square_image_cleared: false,
      })
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toastManager.add({ type: 'error', title: t('admin.errors.failed_to_save') })
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  const handleDelete = async () => {
    const confirmed = await confirm({
      message: t('admin.collections.delete_confirm.message', { name: collection?.name ?? '' }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!confirmed) return
    try {
      await deleteCollection.mutateAsync(collectionId)
      await router.navigate({ to: '/$storeId/products/collections', params: { storeId } })
    } catch {
      toastManager.add({ type: 'error', title: t('admin.errors.failed_to_delete') })
    }
  }

  return (
    <FormProvider {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        {form.formState.errors.root?.message && (
          <p className="text-sm text-destructive" role="alert">
            {form.formState.errors.root.message}
          </p>
        )}
        <ResourceLayout
          header={
            <PageHeader
              title={collection?.name ?? ''}
              backTo="products/collections"
              actions={<FormActions form={form} saveLabel={t('admin.actions.save')} />}
              resource={collection ? { id: collection.id } : undefined}
              onDelete={handleDelete}
              deleteLabel={t('admin.collections.delete_label')}
              jsonPreview={{
                title: `Collection ${collection?.name ?? ''}`,
                fetch: () => adminClient.collections.get(collectionId),
                endpoint: `/api/v3/admin/collections/${collectionId}`,
              }}
            />
          }
          main={<CollectionMain form={form} collection={collection} />}
          sidebar={
            <>
              <CollectionSidebar form={form} collection={collection} />
              <Slot name="collection.form_sidebar" context={{ collection }} />
            </>
          }
        />
      </form>
    </FormProvider>
  )
}

function CollectionSkeleton() {
  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center gap-3">
        <Skeleton className="size-8 rounded-lg" />
        <Skeleton className="h-8 w-48" />
        <div className="ml-auto flex items-center gap-2">
          <Skeleton className="h-8 w-16 rounded-lg" />
        </div>
      </div>
      <div className="grid grid-cols-12 gap-6">
        <div className="col-span-12 flex flex-col gap-6 lg:col-span-8">
          <Skeleton className="h-48 w-full rounded-xl" />
          <Skeleton className="h-72 w-full rounded-xl" />
        </div>
        <div className="col-span-12 flex flex-col gap-6 lg:col-span-4">
          <Skeleton className="h-56 w-full rounded-xl" />
          <Skeleton className="h-32 w-full rounded-xl" />
          <Skeleton className="h-52 w-full rounded-xl" />
        </div>
      </div>
    </div>
  )
}

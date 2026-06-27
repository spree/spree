import { zodResolver } from '@hookform/resolvers/zod'
import { SpreeError } from '@spree/admin-sdk'
import { adminClient, mapSpreeErrorsToForm, PageHeader } from '@spree/dashboard-core'
import {
  FormActions,
  ResourceLayout,
  Skeleton,
  useConfirm,
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { createFileRoute, useRouter } from '@tanstack/react-router'
import { useEffect } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { CategoryMain, CategorySidebar } from '@/components/spree/categories/category-form'
import { useCategory, useDeleteCategory, useUpdateCategory } from '@/hooks/use-categories'
import {
  CATEGORY_DEFAULTS,
  type CategoryFormValues,
  categoryFormSchema,
  categoryToForm,
  categoryToParams,
} from '@/schemas/category'

export const Route = createFileRoute('/_authenticated/$storeId/products/categories/$categoryId')({
  component: CategoryDetailPage,
})

function CategoryDetailPage() {
  const { storeId, categoryId } = Route.useParams()
  const { data: category, isLoading } = useCategory(categoryId)

  if (isLoading || !category) return <CategorySkeleton />

  return <CategoryDetail key={category.id} categoryId={categoryId} storeId={storeId} />
}

function CategoryDetail({ categoryId, storeId }: { categoryId: string; storeId: string }) {
  const { t } = useTranslation()
  const router = useRouter()
  const confirm = useConfirm()
  const { data: category } = useCategory(categoryId)
  const updateCategory = useUpdateCategory(categoryId)
  const deleteCategory = useDeleteCategory()

  const form = useForm<CategoryFormValues>({
    resolver: zodResolver(categoryFormSchema),
    defaultValues: CATEGORY_DEFAULTS,
  })

  // Hydrate (and re-baseline after save) from the source row, unless the
  // merchant has unsaved edits in flight.
  useEffect(() => {
    if (!category || form.formState.isDirty) return
    form.reset(categoryToForm(category))
  }, [category, form])

  const onSubmit = async (values: CategoryFormValues) => {
    try {
      await updateCategory.mutateAsync(categoryToParams(values))
      // Re-baseline so isDirty flips false before the refetch lands; drop the
      // consumed signed_ids + clear flags so a second save can't re-send a
      // stale upload/purge (the refetch hydrates the persisted image state).
      form.reset({
        ...values,
        image_signed_id: null,
        image_cleared: false,
        square_image_signed_id: null,
        square_image_cleared: false,
      })
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toast.error(t('admin.errors.failed_to_save'))
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  const handleDelete = async () => {
    const confirmed = await confirm({
      message: t('admin.categories.delete_confirm', { name: category?.name ?? '' }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!confirmed) return
    try {
      await deleteCategory.mutateAsync(categoryId)
      await router.navigate({ to: '/$storeId/products/categories', params: { storeId } })
    } catch {
      toast.error(t('admin.errors.failed_to_delete'))
    }
  }

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      {form.formState.errors.root?.message && (
        <p className="text-sm text-destructive" role="alert">
          {form.formState.errors.root.message}
        </p>
      )}
      <ResourceLayout
        header={
          <PageHeader
            title={category?.name ?? ''}
            backTo="products/categories"
            actions={<FormActions form={form} saveLabel={t('admin.actions.save')} />}
            resource={category ? { id: category.id } : undefined}
            onDelete={handleDelete}
            deleteLabel={t('admin.categories.delete_label')}
            jsonPreview={{
              title: `Category ${category?.name ?? ''}`,
              fetch: () => adminClient.categories.get(categoryId),
              endpoint: `/api/v3/admin/categories/${categoryId}`,
            }}
          />
        }
        main={<CategoryMain form={form} category={category} />}
        sidebar={<CategorySidebar form={form} category={category} />}
      />
    </form>
  )
}

function CategorySkeleton() {
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

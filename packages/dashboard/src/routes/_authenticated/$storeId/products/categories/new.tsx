import { zodResolver } from '@hookform/resolvers/zod'
import { SpreeError } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm, PageHeader } from '@spree/dashboard-core'
import { FormActions, ResourceLayout, useFormSubmitShortcut } from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { CategoryMain, CategorySidebar } from '@/components/spree/categories/category-form'
import { useCreateCategory } from '@/hooks/use-categories'
import {
  CATEGORY_DEFAULTS,
  type CategoryFormValues,
  categoryFormSchema,
  categoryToParams,
} from '@/schemas/category'

export const Route = createFileRoute('/_authenticated/$storeId/products/categories/new')({
  component: NewCategoryPage,
})

function NewCategoryPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const createCategory = useCreateCategory()

  const form = useForm<CategoryFormValues>({
    resolver: zodResolver(categoryFormSchema),
    defaultValues: CATEGORY_DEFAULTS,
  })

  const onSubmit = async (values: CategoryFormValues) => {
    try {
      const created = await createCategory.mutateAsync(categoryToParams(values))
      form.reset(values)
      // Land on the edit page so images + products can be managed next.
      await navigate({
        to: '/$storeId/products/categories/$categoryId',
        params: { storeId, categoryId: created.id },
      })
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toast.error(t('admin.errors.failed_to_create'))
    }
  }

  useFormSubmitShortcut(form, onSubmit)

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
            title={t('admin.categories.new_title')}
            backTo="products/categories"
            actions={<FormActions form={form} saveLabel={t('admin.actions.save')} />}
          />
        }
        main={<CategoryMain form={form} />}
        sidebar={<CategorySidebar form={form} />}
      />
    </form>
  )
}

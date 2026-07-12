import { zodResolver } from '@hookform/resolvers/zod'
import { SpreeError } from '@spree/admin-sdk'
import {
  extensionFormValues,
  extensionSubmitValues,
  mapSpreeErrorsToForm,
  PageHeader,
} from '@spree/dashboard-core'
import { FormActions, ResourceLayout, useFormSubmitShortcut } from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { FormProvider, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import {
  CategoryMain,
  CategorySidebar,
} from '../../../../../components/spree/categories/category-form'
import { useCreateCategory } from '../../../../../hooks/use-categories'
import {
  CATEGORY_DEFAULTS,
  type CategoryFormValues,
  categoryFormSchema,
  categoryToParams,
} from '../../../../../schemas/category'

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
    // Extension fields seed their blank value (`from(null)`) on create.
    defaultValues: { ...CATEGORY_DEFAULTS, ...extensionFormValues('category', null) },
  })

  const onSubmit = async (values: CategoryFormValues) => {
    try {
      const created = await createCategory.mutateAsync({
        ...categoryToParams(values),
        // Extension fields come from live form state — the Zod parse behind
        // `values` strips keys the first-party schema doesn't know.
        ...extensionSubmitValues('category', form),
      })
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
              title={t('admin.categories.new_title')}
              backTo="products/categories"
              actions={<FormActions form={form} saveLabel={t('admin.actions.save')} />}
            />
          }
          main={<CategoryMain form={form} />}
          sidebar={<CategorySidebar form={form} />}
        />
      </form>
    </FormProvider>
  )
}

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
  CollectionMain,
  CollectionSidebar,
} from '../../../../../components/spree/collections/collection-form'
import { useCreateCollection } from '../../../../../hooks/use-collections'
import {
  COLLECTION_DEFAULTS,
  type CollectionFormValues,
  collectionFormSchema,
  collectionToParams,
} from '../../../../../schemas/collection'

export const Route = createFileRoute('/_authenticated/$storeId/products/collections/new')({
  component: NewCollectionPage,
})

function NewCollectionPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const createCollection = useCreateCollection()

  const form = useForm<CollectionFormValues>({
    resolver: zodResolver(collectionFormSchema),
    // Extension fields seed their blank value (`from(null)`) on create.
    defaultValues: { ...COLLECTION_DEFAULTS, ...extensionFormValues('collection', null) },
  })

  const onSubmit = async (values: CollectionFormValues) => {
    try {
      const created = await createCollection.mutateAsync({
        ...collectionToParams(values),
        // Extension fields come from live form state — the Zod parse behind
        // `values` strips keys the first-party schema doesn't know.
        ...extensionSubmitValues('collection', form),
      })
      form.reset(values)
      // Land on the edit page so images + products can be managed next.
      await navigate({
        to: '/$storeId/products/collections/$collectionId',
        params: { storeId, collectionId: created.id },
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
              title={t('admin.collections.new_title')}
              backTo="products/collections"
              actions={<FormActions form={form} saveLabel={t('admin.actions.save')} />}
            />
          }
          main={<CollectionMain form={form} />}
          sidebar={<CollectionSidebar form={form} />}
        />
      </form>
    </FormProvider>
  )
}

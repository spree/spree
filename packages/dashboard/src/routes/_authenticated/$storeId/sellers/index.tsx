import { zodResolver } from '@hookform/resolvers/zod'
import type { Seller } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  mapSpreeErrorsToForm,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RowActions,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  useConfirm,
} from '@spree/dashboard-ui'
import { PlusIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { useCreateSeller, useDeleteSeller } from '../../../../hooks/use-sellers'
import {
  SELLER_DEFAULTS,
  type SellerFormValues,
  sellerFormSchema,
  sellerValuesToParams,
} from '../../../../schemas/seller'
import '../../../../tables/sellers'

const sellersSearchSchema = resourceSearchSchema.extend({
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/sellers/')({
  validateSearch: sellersSearchSchema,
  component: SellersPage,
})

function SellersPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof sellersSearchSchema>
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteSeller()
  const { permissions } = usePermissions()

  const isCreating = !!search.new

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { new: _n, ...rest } = prev
        return rest as never
      },
    })

  const openCreate = () =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })

  async function handleDelete(seller: Seller) {
    const ok = await confirm({
      title: t('admin.sellers.delete_confirm.title'),
      message: t('admin.sellers.delete_confirm.message', { name: seller.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(seller.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<Seller>
        tableKey="sellers"
        queryKey="sellers"
        queryFn={(params) => adminClient.sellers.list(params)}
        searchParams={search}
        rowActions={(seller) => (
          <RowActions
            actions={[
              {
                key: 'edit',
                onSelect: () =>
                  navigate({
                    to: '/$storeId/sellers/$sellerId',
                    params: { storeId, sellerId: seller.id },
                  }),
              },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.Seller),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(seller),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.Seller}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.sellers.add_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateSellerSheet open onOpenChange={(o) => !o && closeSheet()} />}
    </>
  )
}

function CreateSellerSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const createMutation = useCreateSeller()
  const form = useForm<SellerFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(sellerFormSchema) as any,
    defaultValues: SELLER_DEFAULTS,
  })

  // A new seller has no team, no catalog and no settlement setup yet, and all
  // of that lives on the detail page — so that is where the operator is
  // headed, most immediately to send the invitation.
  async function onSubmit(values: SellerFormValues) {
    try {
      const seller = await createMutation.mutateAsync(sellerValuesToParams(values))
      form.reset(SELLER_DEFAULTS)
      onOpenChange(false)
      navigate({
        to: '/$storeId/sellers/$sellerId',
        params: { storeId, sellerId: seller.id },
        replace: true,
      })
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const { errors } = form.formState

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(SELLER_DEFAULTS)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.sellers.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.sellers.create_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <FieldGroup>
              {errors.root?.message && (
                <p className="text-destructive text-sm" role="alert">
                  {errors.root.message}
                </p>
              )}
              <Field>
                <FieldLabel htmlFor="name">{t('admin.fields.name.label')}</FieldLabel>
                <Input
                  id="name"
                  autoFocus
                  placeholder={t('admin.fields.seller.name.placeholder')}
                  aria-invalid={!!errors.name || undefined}
                  {...form.register('name')}
                />
                <FieldError errors={[errors.name]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="contact_email">
                  {t('admin.fields.contact_email.label')}
                </FieldLabel>
                <Input
                  id="contact_email"
                  type="email"
                  placeholder={t('admin.fields.seller.contact_email.placeholder')}
                  aria-invalid={!!errors.contact_email || undefined}
                  {...form.register('contact_email')}
                />
                <FieldDescription>{t('admin.fields.seller.contact_email.help')}</FieldDescription>
                <FieldError errors={[errors.contact_email]} />
              </Field>
            </FieldGroup>
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting
                ? t('admin.actions.creating')
                : t('admin.sellers.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

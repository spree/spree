import { zodResolver } from '@hookform/resolvers/zod'
import type { Vendor } from '@spree/admin-sdk'
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
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { useCreateVendor, useDeleteVendor } from '../../../../hooks/use-vendors'
import {
  VENDOR_DEFAULTS,
  type VendorFormValues,
  vendorFormSchema,
  vendorValuesToParams,
} from '../../../../schemas/vendor'
import '../../../../tables/vendors'

const vendorsSearchSchema = resourceSearchSchema.extend({
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/vendors/')({
  validateSearch: vendorsSearchSchema,
  component: VendorsPage,
})

function VendorsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof vendorsSearchSchema>
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteVendor()
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

  async function handleDelete(vendor: Vendor) {
    const ok = await confirm({
      title: t('admin.vendors.delete_confirm.title'),
      message: t('admin.vendors.delete_confirm.message', { name: vendor.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(vendor.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<Vendor>
        tableKey="vendors"
        queryKey="vendors"
        queryFn={(params) => adminClient.vendors.list(params)}
        searchParams={search}
        rowActions={(vendor) => (
          <RowActions
            actions={[
              {
                key: 'edit',
                onSelect: () =>
                  navigate({
                    to: '/$storeId/vendors/$vendorId',
                    params: { storeId, vendorId: vendor.id },
                  }),
              },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.Vendor),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(vendor),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.Vendor}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.vendors.add_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateVendorSheet open onOpenChange={(o) => !o && closeSheet()} />}
    </>
  )
}

function CreateVendorSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const createMutation = useCreateVendor()
  const form = useForm<VendorFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(vendorFormSchema) as any,
    defaultValues: VENDOR_DEFAULTS,
  })

  // A new vendor has no team, no catalog and no settlement setup yet, and all
  // of that lives on the detail page — so that is where the operator is
  // headed, most immediately to send the invitation.
  async function onSubmit(values: VendorFormValues) {
    try {
      const vendor = await createMutation.mutateAsync(vendorValuesToParams(values))
      form.reset(VENDOR_DEFAULTS)
      onOpenChange(false)
      navigate({
        to: '/$storeId/vendors/$vendorId',
        params: { storeId, vendorId: vendor.id },
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
        if (!next) form.reset(VENDOR_DEFAULTS)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.vendors.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.vendors.create_description')}</SheetDescription>
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
                  placeholder={t('admin.fields.vendor.name.placeholder')}
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
                  placeholder={t('admin.fields.vendor.contact_email.placeholder')}
                  aria-invalid={!!errors.contact_email || undefined}
                  {...form.register('contact_email')}
                />
                <FieldDescription>{t('admin.fields.vendor.contact_email.help')}</FieldDescription>
                <FieldError errors={[errors.contact_email]} />
              </Field>
            </FieldGroup>
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting
                ? t('admin.actions.creating')
                : t('admin.vendors.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

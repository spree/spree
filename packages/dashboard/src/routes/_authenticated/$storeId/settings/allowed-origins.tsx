import { zodResolver } from '@hookform/resolvers/zod'
import type { AllowedOrigin, AllowedOriginCreateParams } from '@spree/admin-sdk'
import {
  adminClient,
  i18n,
  mapSpreeErrorsToForm,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RowActions,
  requiredMessage,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { Can } from '@/components/spree/can'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
import {
  useAllowedOrigin,
  useCreateAllowedOrigin,
  useDeleteAllowedOrigin,
  useUpdateAllowedOrigin,
} from '@/hooks/use-allowed-origins'
import '@/tables/allowed-origins'

// Block paths, queries, fragments, and trailing slashes — the backend rejects
// them with `:must_be_origin_only`. Catching them client-side gives an
// immediate inline error instead of waiting for a round trip.
const allowedOriginFormSchema = z.object({
  origin: z
    .string()
    .trim()
    .min(1, { error: requiredMessage('allowed_origin.origin') })
    .regex(/^https?:\/\/[^/?#\s]+$/i, {
      error: () => i18n.t('admin.allowed_origins.validation.bare_origin'),
    }),
})

type AllowedOriginFormValues = z.infer<typeof allowedOriginFormSchema>

const DEFAULT_VALUES: AllowedOriginFormValues = { origin: '' }

const allowedOriginsSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/allowed-origins')({
  validateSearch: allowedOriginsSearchSchema,
  component: AllowedOriginsPage,
})

function AllowedOriginsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof allowedOriginsSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteAllowedOrigin()
  const { permissions } = usePermissions()

  const isCreating = !!search.new
  // `new` wins over `edit` when both are present — prevents both sheets
  // rendering at once from a stale URL.
  const editId = isCreating ? undefined : search.edit

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { edit: _e, new: _n, ...rest } = prev
        return rest as never
      },
    })

  const openCreate = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { edit: _e, ...rest } = prev
        return { ...rest, new: true } as never
      },
    })

  const openEdit = (id: string) =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { new: _n, ...rest } = prev
        return { ...rest, edit: id } as never
      },
    })

  useRowClickBridge('data-allowed-origin-id', openEdit)

  async function handleDelete(origin: AllowedOrigin) {
    const ok = await confirm({
      title: t('admin.allowed_origins.delete_confirm.title'),
      message: t('admin.allowed_origins.delete_confirm.message', { origin: origin.origin }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(origin.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<AllowedOrigin>
        tableKey="allowed-origins"
        queryKey="allowed-origins"
        queryFn={(params) => adminClient.allowedOrigins.list(params)}
        searchParams={search}
        rowActions={(origin) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(origin.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.AllowedOrigin),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(origin),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.AllowedOrigin}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.allowed_origins.add_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateAllowedOriginSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && (
        <EditAllowedOriginSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />
      )}
    </>
  )
}

function CreateAllowedOriginSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateAllowedOrigin()
  const form = useForm<AllowedOriginFormValues>({
    resolver: zodResolver(allowedOriginFormSchema),
    defaultValues: DEFAULT_VALUES,
  })

  async function onSubmit(values: AllowedOriginFormValues) {
    try {
      await createMutation.mutateAsync(values as AllowedOriginCreateParams)
      form.reset(DEFAULT_VALUES)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(DEFAULT_VALUES)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.settings.allowed_origins.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.allowed_origins.create_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <AllowedOriginFormFields form={form} />
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
                : t('admin.allowed_origins.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditAllowedOriginSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: allowedOrigin, isLoading } = useAllowedOrigin(id)
  const updateMutation = useUpdateAllowedOrigin(id)

  // `values` + `keepDirtyValues` syncs server data into the form while
  // preserving any in-progress edits — protects against background refetches
  // wiping the user's input.
  const form = useForm<AllowedOriginFormValues>({
    resolver: zodResolver(allowedOriginFormSchema),
    defaultValues: DEFAULT_VALUES,
    values: allowedOrigin ? { origin: allowedOrigin.origin } : undefined,
    resetOptions: { keepDirtyValues: true },
  })

  async function onSubmit(values: AllowedOriginFormValues) {
    try {
      await updateMutation.mutateAsync(values)
      form.reset(values)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>
            {allowedOrigin?.origin ?? t('admin.pages.settings.allowed_origins.edit_sheet_title')}
          </SheetTitle>
          <SheetDescription>{t('admin.allowed_origins.edit_description')}</SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              <AllowedOriginFormFields form={form} />
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
              <Button
                type="submit"
                size="sm"
                disabled={form.formState.isSubmitting || !form.formState.isDirty}
              >
                {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
              </Button>
            </SheetFooter>
          </form>
        )}
      </SheetContent>
    </Sheet>
  )
}

function AllowedOriginFormFields({ form }: { form: UseFormReturn<AllowedOriginFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  return (
    <FieldGroup>
      {errors.root?.message && (
        <p className="text-sm text-destructive" role="alert">
          {errors.root.message}
        </p>
      )}
      <Field>
        <FieldLabel htmlFor="origin">{t('admin.fields.allowed_origin.origin.label')}</FieldLabel>
        <Input
          id="origin"
          autoFocus
          autoComplete="off"
          spellCheck={false}
          placeholder={t('admin.fields.allowed_origin.origin.placeholder')}
          aria-invalid={!!errors.origin || undefined}
          aria-describedby="origin-help"
          {...form.register('origin')}
        />
        <span id="origin-help" className="text-xs text-muted-foreground">
          {t('admin.fields.allowed_origin.origin.help')}
        </span>
        <FieldError errors={[errors.origin]} />
      </Field>
    </FieldGroup>
  )
}

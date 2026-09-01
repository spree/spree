import { zodResolver } from '@hookform/resolvers/zod'
import type { Policy, PolicyCreateParams } from '@spree/admin-sdk'
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
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { PlusIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useEffect } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { MediaRichTextEditor } from '../../../../components/spree/media-rich-text-editor'
import {
  useCreatePolicy,
  useDeletePolicy,
  usePolicy,
  useUpdatePolicy,
} from '../../../../hooks/use-policies'
import {
  POLICY_DEFAULTS,
  type PolicyFormValues,
  policyFormSchema,
  policyToFormValues,
  policyValuesToParams,
} from '../../../../schemas/policy'
import '../../../../tables/policies'

const policiesSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/policies')({
  validateSearch: policiesSearchSchema,
  component: PoliciesPage,
})

function PoliciesPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof policiesSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeletePolicy()
  const { permissions } = usePermissions()

  const editId = search.edit
  const isCreating = !!search.new

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { edit: _e, new: _n, ...rest } = prev
        return rest as never
      },
    })

  const openCreate = () =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })

  const openEdit = (id: string) =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, edit: id }) as never })

  useRowClickBridge('data-policy-id', openEdit)

  async function handleDelete(policy: Policy) {
    const ok = await confirm({
      title: t('admin.policies.delete_confirm.title'),
      message: t('admin.policies.delete_confirm.message', { name: policy.name ?? '' }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(policy.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<Policy>
        tableKey="policies"
        queryKey="policies"
        queryFn={(params) => adminClient.policies.list(params)}
        searchParams={search}
        rowActions={(policy) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(policy.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.Policy),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(policy),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.Policy}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.policies.add_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreatePolicySheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && <EditPolicySheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />}
    </>
  )
}

// A legal document needs more room than the default sheet gives a short form.
const POLICY_SHEET_WIDTH = 'data-[side=right]:max-w-[860px]'

function CreatePolicySheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreatePolicy()
  const form = useForm<PolicyFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(policyFormSchema) as any,
    defaultValues: POLICY_DEFAULTS,
  })

  async function onSubmit(values: PolicyFormValues) {
    try {
      await createMutation.mutateAsync(policyValuesToParams(values) as PolicyCreateParams)
      form.reset(POLICY_DEFAULTS)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(POLICY_DEFAULTS)
        onOpenChange(next)
      }}
    >
      <SheetContent className={POLICY_SHEET_WIDTH}>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.settings.policies.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.policies.create_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <PolicyFormFields form={form} />
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
                : t('admin.policies.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditPolicySheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: policy, isLoading } = usePolicy(id)
  const updateMutation = useUpdatePolicy(id)

  const form = useForm<PolicyFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(policyFormSchema) as any,
    defaultValues: POLICY_DEFAULTS,
  })

  useEffect(() => {
    if (policy) form.reset(policyToFormValues(policy))
  }, [policy, form])

  async function onSubmit(values: PolicyFormValues) {
    try {
      await updateMutation.mutateAsync(policyValuesToParams(values))
      form.reset(values)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className={POLICY_SHEET_WIDTH}>
        <SheetHeader>
          <SheetTitle>
            {policy?.name ?? t('admin.pages.settings.policies.edit_sheet_title')}
          </SheetTitle>
          <SheetDescription>{t('admin.policies.edit_description')}</SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              <PolicyFormFields form={form} />
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
              <Button
                type="submit"
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

function PolicyFormFields({ form }: { form: UseFormReturn<PolicyFormValues> }) {
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
        <FieldLabel htmlFor="policy-name">{t('admin.fields.name.label')}</FieldLabel>
        <Input
          id="policy-name"
          autoFocus
          placeholder={t('admin.fields.policy.name.placeholder')}
          aria-invalid={!!errors.name || undefined}
          {...form.register('name')}
        />
        <FieldError errors={[errors.name]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="policy-slug">{t('admin.fields.slug.label')}</FieldLabel>
        <Input
          id="policy-slug"
          placeholder={t('admin.fields.policy.slug.placeholder')}
          aria-invalid={!!errors.slug || undefined}
          {...form.register('slug')}
        />
        <p className="text-xs text-muted-foreground">{t('admin.fields.policy.slug.help')}</p>
        <FieldError errors={[errors.slug]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="policy-body">{t('admin.fields.policy.body.label')}</FieldLabel>
        <Controller
          control={form.control}
          name="body"
          render={({ field }) => (
            <MediaRichTextEditor
              id="policy-body"
              ariaLabel={t('admin.fields.policy.body.label')}
              value={field.value}
              onChange={field.onChange}
            />
          )}
        />
        <FieldError errors={[errors.body]} />
      </Field>
    </FieldGroup>
  )
}

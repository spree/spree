import { zodResolver } from '@hookform/resolvers/zod'
import type { Channel, ChannelCreateParams } from '@spree/admin-sdk'
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
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Switch,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useEffect } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import {
  useChannel,
  useCreateChannel,
  useDeleteChannel,
  useUpdateChannel,
} from '@/hooks/use-channels'
import {
  CHANNEL_DEFAULTS,
  type ChannelFormValues,
  channelFormSchema,
  channelValuesToParams,
  GUEST_CHECKOUT_VALUES,
  ORDER_ROUTING_STRATEGY_VALUES,
  STOREFRONT_ACCESS_VALUES,
} from '@/schemas/channel'
import '@/tables/channels'

const channelsSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/channels')({
  validateSearch: channelsSearchSchema,
  component: ChannelsPage,
})

function ChannelsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof channelsSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteChannel()
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

  useRowClickBridge('data-channel-id', openEdit)

  async function handleDelete(channel: Channel) {
    const ok = await confirm({
      title: t('admin.pages.channels.delete_confirm.title'),
      message: t('admin.pages.channels.delete_confirm.message', { name: channel.name ?? '' }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(channel.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<Channel>
        tableKey="channels"
        queryKey="channels"
        queryFn={(params) => adminClient.channels.list(params)}
        searchParams={search}
        rowActions={(channel) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(channel.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.Channel) && !channel.default,
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(channel),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.Channel}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.pages.channels.add_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateChannelSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && <EditChannelSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />}
    </>
  )
}

// Mirrors ActiveSupport's +String#parameterize+: lowercase, ASCII-friendly,
// hyphen-separated. Keeps the SPA preview in sync with what +normalizes :code+
// produces on the model so users see the final slug as they type.
function slugifyChannelCode(value: string): string {
  return value
    .normalize('NFKD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
}

function CreateChannelSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateChannel()
  const form = useForm<ChannelFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(channelFormSchema) as any,
    defaultValues: CHANNEL_DEFAULTS,
  })

  // Auto-derive +code+ from +name+ while the user hasn't touched +code+ yet.
  // The watch stops mirroring as soon as the user edits +code+ directly, so
  // we never clobber a deliberate value.
  const name = form.watch('name')
  useEffect(() => {
    if (form.getFieldState('code').isDirty) return
    form.setValue('code', slugifyChannelCode(name ?? ''))
  }, [name, form])

  async function onSubmit(values: ChannelFormValues) {
    try {
      await createMutation.mutateAsync(channelValuesToParams(values) as ChannelCreateParams)
      form.reset(CHANNEL_DEFAULTS)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(CHANNEL_DEFAULTS)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.channels.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.pages.channels.create_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <ChannelFormFields form={form} />
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
                : t('admin.pages.channels.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditChannelSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: channel, isLoading } = useChannel(id)
  const updateMutation = useUpdateChannel(id)

  const form = useForm<ChannelFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(channelFormSchema) as any,
    defaultValues: CHANNEL_DEFAULTS,
  })

  useEffect(() => {
    if (channel) {
      form.reset({
        name: channel.name,
        code: channel.code,
        active: channel.active,
        default: channel.default,
        preferred_order_routing_strategy: channel.preferred_order_routing_strategy ?? '',
        preferred_storefront_access: channel.preferred_storefront_access ?? '',
        preferred_guest_checkout:
          channel.preferred_guest_checkout == null ? '' : String(channel.preferred_guest_checkout),
      })
    }
  }, [channel, form])

  async function onSubmit(values: ChannelFormValues) {
    try {
      await updateMutation.mutateAsync(channelValuesToParams(values))
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
          <SheetTitle>{channel?.name ?? t('admin.pages.channels.edit_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.pages.channels.edit_description')}</SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              <ChannelFormFields form={form} />
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

type ChannelSelectFieldName =
  | 'preferred_order_routing_strategy'
  | 'preferred_storefront_access'
  | 'preferred_guest_checkout'

// One channel-preference <Select> that shares the "inherit from store" blank
// option. Builds its own option list from `values` + the i18n `scope`
// (`<scope>.label` / `.help` / `.inherit` / `.options.<value>`).
function InheritableSelectField({
  form,
  name,
  scope,
  values,
}: {
  form: UseFormReturn<ChannelFormValues>
  name: ChannelSelectFieldName
  scope: string
  values: readonly string[]
}) {
  const { t } = useTranslation()
  const error = form.formState.errors[name]
  const options = values.map((value) => ({
    value,
    label: value === '' ? t(`${scope}.inherit`) : t(`${scope}.options.${value}`),
  }))
  return (
    <Field>
      <FieldLabel htmlFor={name}>{t(`${scope}.label`)}</FieldLabel>
      <Controller
        name={name}
        control={form.control}
        render={({ field }) => (
          <Select items={options} value={field.value ?? ''} onValueChange={field.onChange}>
            <SelectTrigger id={name} className="w-full" aria-invalid={!!error || undefined}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {options.map((o) => (
                <SelectItem key={o.value || 'inherit'} value={o.value}>
                  {o.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        )}
      />
      <span className="text-xs text-muted-foreground">{t(`${scope}.help`)}</span>
      <FieldError errors={[error]} />
    </Field>
  )
}

function ChannelFormFields({ form }: { form: UseFormReturn<ChannelFormValues> }) {
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
        <FieldLabel htmlFor="name">{t('admin.fields.name.label')}</FieldLabel>
        <Input
          id="name"
          autoFocus
          placeholder={t('admin.fields.channel.name.placeholder')}
          aria-invalid={!!errors.name || undefined}
          {...form.register('name')}
        />
        <FieldError errors={[errors.name]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="code">{t('admin.fields.channel.code.label')}</FieldLabel>
        <Input
          id="code"
          placeholder={t('admin.fields.channel.code.placeholder')}
          aria-invalid={!!errors.code || undefined}
          {...form.register('code')}
        />
        <span className="text-xs text-muted-foreground">{t('admin.fields.channel.code.help')}</span>
        <FieldError errors={[errors.code]} />
      </Field>

      <Field>
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col">
            <FieldLabel htmlFor="active" className="cursor-pointer">
              {t('admin.fields.channel.active.label')}
            </FieldLabel>
            <span className="text-xs text-muted-foreground">
              {t('admin.fields.channel.active.help')}
            </span>
          </div>
          <Controller
            name="active"
            control={form.control}
            render={({ field }) => (
              <Switch id="active" checked={!!field.value} onCheckedChange={field.onChange} />
            )}
          />
        </div>
      </Field>

      <Field>
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col">
            <FieldLabel htmlFor="default" className="cursor-pointer">
              {t('admin.fields.channel.default.label')}
            </FieldLabel>
            <span className="text-xs text-muted-foreground">
              {t('admin.fields.channel.default.help')}
            </span>
          </div>
          <Controller
            name="default"
            control={form.control}
            render={({ field }) => (
              <Switch id="default" checked={!!field.value} onCheckedChange={field.onChange} />
            )}
          />
        </div>
      </Field>

      <InheritableSelectField
        form={form}
        name="preferred_order_routing_strategy"
        scope="admin.fields.channel.order_routing_strategy"
        values={ORDER_ROUTING_STRATEGY_VALUES}
      />

      <InheritableSelectField
        form={form}
        name="preferred_storefront_access"
        scope="admin.fields.channel.storefront_access"
        values={STOREFRONT_ACCESS_VALUES}
      />

      <InheritableSelectField
        form={form}
        name="preferred_guest_checkout"
        scope="admin.fields.channel.guest_checkout"
        values={GUEST_CHECKOUT_VALUES}
      />
    </FieldGroup>
  )
}

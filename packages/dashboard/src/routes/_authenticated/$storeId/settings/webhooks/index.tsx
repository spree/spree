import { zodResolver } from '@hookform/resolvers/zod'
import type { WebhookEndpoint, WebhookEndpointCreateParams } from '@spree/admin-sdk'
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
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  RowActions,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  useConfirm,
  useCopyToClipboard,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { AlertTriangleIcon, BanIcon, CheckIcon, CopyIcon, PlayIcon, PlusIcon } from 'lucide-react'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { z } from 'zod/v4'
import { WebhookEndpointFormFields } from '@/components/spree/webhook-endpoint-form'
import {
  useCreateWebhookEndpoint,
  useDeleteWebhookEndpoint,
  useSendTestWebhook,
  useToggleWebhookEndpoint,
} from '@/hooks/use-webhook-endpoints'
import {
  DEFAULT_WEBHOOK_ENDPOINT_VALUES,
  type WebhookEndpointFormValues,
  webhookEndpointFormSchema,
} from '@/schemas/webhook-endpoint'
import '@/tables/webhook-endpoints'

const webhooksSearchSchema = resourceSearchSchema.extend({
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/webhooks/')({
  validateSearch: webhooksSearchSchema,
  component: WebhooksPage,
})

function WebhooksPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const search = Route.useSearch() as z.infer<typeof webhooksSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteWebhookEndpoint()
  const toggleMutation = useToggleWebhookEndpoint()
  const sendTestMutation = useSendTestWebhook()
  const { permissions } = usePermissions()

  // The Create flow ends with a one-shot secret reveal — only `create`
  // returns `secret_key`, so we have to surface it before navigating away.
  const [secretReveal, setSecretReveal] = useState<WebhookEndpoint | null>(null)

  const isCreating = !!search.new

  const closeCreate = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { new: _n, ...rest } = prev
        return rest as never
      },
    })

  const openCreate = () =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })

  // Row click opens the dedicated detail page rather than a sheet — that page
  // owns the deliveries list, health summary, and edit form.
  useRowClickBridge('data-webhook-endpoint-id', (id: string) =>
    navigate({
      to: '/$storeId/settings/webhooks/$webhookEndpointId',
      params: { storeId, webhookEndpointId: id },
    }),
  )

  async function handleDelete(endpoint: WebhookEndpoint) {
    const ok = await confirm({
      title: t('admin.pages.settings.webhooks.delete_confirm.title'),
      message: t('admin.pages.settings.webhooks.delete_confirm.message', {
        name: endpoint.name || endpoint.url,
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(endpoint.id).catch(() => undefined)
  }

  async function handleSendTest(endpoint: WebhookEndpoint) {
    try {
      await sendTestMutation.mutateAsync(endpoint.id)
      toast.success(t('admin.pages.settings.webhooks.deliveries.test_sent'))
    } catch (err) {
      toast.error(
        err instanceof Error
          ? err.message
          : t('admin.pages.settings.webhooks.deliveries.test_failed'),
      )
    }
  }

  return (
    <>
      <ResourceTable<WebhookEndpoint>
        tableKey="webhook-endpoints"
        queryKey="webhook-endpoints"
        queryFn={(params) => adminClient.webhookEndpoints.list(params)}
        searchParams={search}
        rowActions={(endpoint) => (
          <RowActions
            actions={[
              {
                key: 'edit',
                label: t('admin.actions.edit'),
                onSelect: () =>
                  navigate({
                    to: '/$storeId/settings/webhooks/$webhookEndpointId',
                    params: { storeId, webhookEndpointId: endpoint.id },
                    // Land directly on the detail page with the Edit sheet open.
                    search: { edit: true } as never,
                  }),
              },
              {
                key: 'send_test',
                label: t('admin.pages.settings.webhooks.actions.send_test'),
                icon: <PlayIcon className="size-4" />,
                disabled: sendTestMutation.isPending || !!endpoint.disabled_at,
                onSelect: () => handleSendTest(endpoint),
              },
              {
                key: 'toggle',
                label: endpoint.active
                  ? t('admin.pages.settings.webhooks.actions.disable')
                  : t('admin.pages.settings.webhooks.actions.enable'),
                icon: <BanIcon className="size-4" />,
                disabled: toggleMutation.isPending,
                onSelect: () =>
                  toggleMutation
                    .mutateAsync({ id: endpoint.id, active: !endpoint.active })
                    .catch(() => undefined),
              },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.WebhookEndpoint),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(endpoint),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.WebhookEndpoint}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.pages.settings.webhooks.new_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && (
        <CreateEndpointSheet
          open
          onOpenChange={(o) => !o && closeCreate()}
          onCreated={(endpoint) => {
            closeCreate()
            if (endpoint.secret_key) setSecretReveal(endpoint)
          }}
        />
      )}

      <SecretRevealDialog
        endpoint={secretReveal}
        onOpenChange={(open) => {
          if (!open && secretReveal) {
            const id = secretReveal.id
            setSecretReveal(null)
            // Drop the admin straight onto the new endpoint's detail page —
            // they probably want to verify the subscription list, send a
            // test, etc.
            navigate({
              to: '/$storeId/settings/webhooks/$webhookEndpointId',
              params: { storeId, webhookEndpointId: id },
            })
          }
        }}
      />
    </>
  )
}

// ---------------------------------------------------------------------------
// Create sheet
// ---------------------------------------------------------------------------

function CreateEndpointSheet({
  open,
  onOpenChange,
  onCreated,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  onCreated: (endpoint: WebhookEndpoint) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateWebhookEndpoint()
  const form = useForm<WebhookEndpointFormValues>({
    resolver: zodResolver(webhookEndpointFormSchema),
    defaultValues: DEFAULT_WEBHOOK_ENDPOINT_VALUES,
  })

  async function onSubmit(values: WebhookEndpointFormValues) {
    const params: WebhookEndpointCreateParams = {
      name: values.name?.trim() || null,
      url: values.url,
      active: values.active,
      subscriptions: values.subscriptions,
    }
    try {
      const endpoint = await createMutation.mutateAsync(params)
      form.reset(DEFAULT_WEBHOOK_ENDPOINT_VALUES)
      onCreated(endpoint)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(DEFAULT_WEBHOOK_ENDPOINT_VALUES)
        onOpenChange(next)
      }}
    >
      <SheetContent className="sm:max-w-xl">
        <SheetHeader>
          <SheetTitle>{t('admin.pages.settings.webhooks.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.pages.settings.webhooks.subtitle')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <WebhookEndpointFormFields form={form} />
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
                : t('admin.actions.create')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

// ---------------------------------------------------------------------------
// Secret reveal dialog — one-shot, immediately after create.
// ---------------------------------------------------------------------------

function SecretRevealDialog({
  endpoint,
  onOpenChange,
}: {
  endpoint: WebhookEndpoint | null
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { copied, copy } = useCopyToClipboard()

  return (
    <Dialog open={!!endpoint} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.settings.webhooks.save_secret_title')}</DialogTitle>
          <DialogDescription>
            {t('admin.pages.settings.webhooks.save_secret_description')}
          </DialogDescription>
        </DialogHeader>
        <DialogBody className="flex flex-col gap-3">
          <div className="flex items-start gap-2 rounded-md border border-yellow-200 bg-yellow-50 p-3 text-sm text-yellow-900 dark:border-yellow-900/40 dark:bg-yellow-950/40 dark:text-yellow-200">
            <AlertTriangleIcon className="size-4 shrink-0" />
            <span>{t('admin.api_keys.warning_treat_like_password')}</span>
          </div>
          {endpoint?.secret_key && (
            <div className="flex items-center gap-2 rounded-md border border-border bg-muted/40 p-3">
              <code className="flex-1 truncate font-mono text-sm">{endpoint.secret_key}</code>
              <Button size="sm" variant="outline" onClick={() => copy(endpoint.secret_key ?? '')}>
                {copied ? <CheckIcon /> : <CopyIcon />}
                {copied ? t('admin.actions.copied') : t('admin.actions.copy')}
              </Button>
            </div>
          )}
        </DialogBody>
        <DialogFooter>
          <Button size="sm" onClick={() => onOpenChange(false)}>
            {t('admin.actions.done')}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

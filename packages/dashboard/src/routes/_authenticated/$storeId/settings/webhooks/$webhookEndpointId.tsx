import { zodResolver } from '@hookform/resolvers/zod'
import type {
  WebhookDelivery,
  WebhookEndpoint,
  WebhookEndpointUpdateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  mapSpreeErrorsToForm,
  PageHeader,
  type ResourceSearch,
  ResourceTable,
  resourceSearchSchema,
  Subject,
} from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  CopyToClipboardButton,
  cn,
  ErrorState,
  RelativeTime,
  ResourceLayout,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Skeleton,
  useConfirm,
  useFormSubmitShortcut,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { AlertTriangleIcon, PencilIcon, PlayIcon, RotateCcwIcon } from 'lucide-react'
import { lazy, Suspense } from 'react'
import { type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { z } from 'zod/v4'
import { WebhookEndpointFormFields } from '@/components/spree/webhook-endpoint-form'
import {
  useDeleteWebhookEndpoint,
  useRedeliverWebhookDelivery,
  useSendTestWebhook,
  useToggleWebhookEndpoint,
  useUpdateWebhookEndpoint,
  useWebhookDelivery,
  useWebhookEndpoint,
} from '@/hooks/use-webhook-endpoints'
import { webhookEndpointHealth, webhookHealthBadgeVariant } from '@/lib/webhook-health'
import {
  DEFAULT_WEBHOOK_ENDPOINT_VALUES,
  type WebhookEndpointFormValues,
  webhookEndpointFormSchema,
} from '@/schemas/webhook-endpoint'
import '@/tables/webhook-deliveries'

// `<JsonValueView>` pulls in `@uiw/react-json-view` (~30 KB gzip). Lazy-loading
// it keeps the route's entry chunk small — the renderer only matters when an
// admin opens a delivery detail.
const JsonValueView = lazy(() =>
  import('@spree/dashboard-ui/spree/json-value-view').then((m) => ({ default: m.JsonValueView })),
)

// The route shares its URL with the embedded deliveries `<ResourceTable>` —
// `page`/`sort`/`filters`/`search` come from `resourceSearchSchema`; `delivery`
// is the prefixed ID of the row whose detail sheet is open; `edit=1` opens
// the edit sheet so deep-links and back navigation behave predictably.
const detailSearchSchema = resourceSearchSchema.extend({
  delivery: z.string().optional(),
  edit: z.coerce.boolean().optional(),
})

export const Route = createFileRoute(
  '/_authenticated/$storeId/settings/webhooks/$webhookEndpointId',
)({
  validateSearch: detailSearchSchema,
  component: WebhookEndpointDetailPage,
})

function WebhookEndpointDetailPage() {
  const { t } = useTranslation()
  const { webhookEndpointId } = Route.useParams()
  const { data: endpoint, isLoading, error, refetch } = useWebhookEndpoint(webhookEndpointId)

  if (isLoading) {
    return <p className="text-muted-foreground">{t('admin.common.loading')}</p>
  }
  if (error || !endpoint) {
    return (
      <ErrorState
        title={t('admin.pages.settings.webhooks.detail.load_failed_title')}
        description={error instanceof Error ? error.message : undefined}
        onRetry={() => refetch()}
      />
    )
  }
  return <WebhookEndpointDetailBody endpoint={endpoint} />
}

function WebhookEndpointDetailBody({ endpoint }: { endpoint: WebhookEndpoint }) {
  const { t } = useTranslation()
  const { storeId, webhookEndpointId } = Route.useParams()
  const search = Route.useSearch() as z.infer<typeof detailSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()

  const updateMutation = useUpdateWebhookEndpoint(webhookEndpointId)
  const deleteMutation = useDeleteWebhookEndpoint()
  const toggleMutation = useToggleWebhookEndpoint()
  const sendTestMutation = useSendTestWebhook()

  // ---- Form (Edit card) -------------------------------------------------
  const form = useForm<WebhookEndpointFormValues>({
    resolver: zodResolver(webhookEndpointFormSchema),
    defaultValues: DEFAULT_WEBHOOK_ENDPOINT_VALUES,
    // `keepDirtyValues` so a background refetch doesn't wipe user edits.
    values: {
      name: endpoint.name,
      url: endpoint.url,
      active: endpoint.active,
      subscriptions: endpoint.subscriptions ?? [],
    },
    resetOptions: { keepDirtyValues: true },
  })

  async function onSubmit(values: WebhookEndpointFormValues) {
    try {
      await updateMutation.mutateAsync({
        name: values.name?.trim() || null,
        url: values.url,
        active: values.active,
        subscriptions: values.subscriptions,
      } satisfies WebhookEndpointUpdateParams)
      form.reset(values)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  // ---- Header actions ---------------------------------------------------
  async function handleDelete() {
    const ok = await confirm({
      title: t('admin.pages.settings.webhooks.delete_confirm.title'),
      message: t('admin.pages.settings.webhooks.delete_confirm.message', {
        name: endpoint.name || endpoint.url,
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(endpoint.id)
    navigate({ to: '/$storeId/settings/webhooks', params: { storeId } })
  }

  async function handleSendTest() {
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

  function handleReEnable() {
    toggleMutation.mutateAsync({ id: endpoint.id, active: true }).catch(() => undefined)
  }

  // ---- Sheet state -------------------------------------------------------
  // Sheet toggles use `replace: true` so opening/closing doesn't add history
  // entries — otherwise the page's back arrow (which calls
  // `router.history.back()`) would step back into the just-closed sheet
  // instead of leaving the page.
  const detailDeliveryId = search.delivery
  const editOpen = !!search.edit
  const openDelivery = (id: string) =>
    navigate({
      search: (prev: Record<string, unknown>) => ({ ...prev, delivery: id }) as never,
      replace: true,
    })
  const closeDelivery = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { delivery: _d, ...rest } = prev
        return rest as never
      },
      replace: true,
    })
  const openEdit = () =>
    navigate({
      search: (prev: Record<string, unknown>) => ({ ...prev, edit: true }) as never,
      replace: true,
    })
  const closeEdit = () => {
    // Drop any unsaved edits when the sheet closes — the values prop on
    // useForm will re-seed from the latest endpoint on the next open.
    form.reset()
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { edit: _e, ...rest } = prev
        return rest as never
      },
      replace: true,
    })
  }

  return (
    <>
      <ResourceLayout
        header={
          <PageHeader
            title={endpoint.name || endpoint.url}
            subtitle={endpoint.name ? <CopyableUrl url={endpoint.url} /> : undefined}
            backTo="settings/webhooks"
            resource={{ id: endpoint.id }}
            onDelete={handleDelete}
            deleteLabel={t('admin.pages.settings.webhooks.detail.delete_label')}
            actions={
              <Can I="update" a={Subject.WebhookEndpoint}>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={handleSendTest}
                  disabled={sendTestMutation.isPending || !!endpoint.disabled_at}
                >
                  <PlayIcon className="size-4" />
                  {t('admin.pages.settings.webhooks.actions.send_test')}
                </Button>
                <Button size="sm" variant="outline" onClick={openEdit}>
                  <PencilIcon className="size-4" />
                  {t('admin.actions.edit')}
                </Button>
              </Can>
            }
          />
        }
        main={
          <>
            {endpoint.disabled_at && (
              <AutoDisabledAlert
                endpoint={endpoint}
                onReEnable={handleReEnable}
                reEnabling={toggleMutation.isPending}
              />
            )}
            <HealthSummaryCard endpoint={endpoint} />
            <DeliveriesCard
              endpointId={endpoint.id}
              onSelect={openDelivery}
              searchParams={search}
            />
          </>
        }
        sidebar={<DetailsCard endpoint={endpoint} />}
      />
      <EditEndpointSheet
        endpoint={endpoint}
        form={form}
        open={editOpen}
        onOpenChange={(o) => (o ? openEdit() : closeEdit())}
        onSubmit={async (values) => {
          await onSubmit(values)
          closeEdit()
        }}
      />
      {detailDeliveryId && (
        <DeliveryDetailSheet
          endpointId={endpoint.id}
          deliveryId={detailDeliveryId}
          open
          onOpenChange={(o) => !o && closeDelivery()}
        />
      )}
    </>
  )
}

// ---------------------------------------------------------------------------
// Auto-disabled banner — matches the alert at the top of the legacy show view.
// ---------------------------------------------------------------------------

function AutoDisabledAlert({
  endpoint,
  onReEnable,
  reEnabling,
}: {
  endpoint: WebhookEndpoint
  onReEnable: () => void
  reEnabling: boolean
}) {
  const { t } = useTranslation()
  return (
    <div className="flex flex-col gap-2 rounded-md border border-destructive/40 bg-destructive/5 p-3 text-sm text-destructive sm:flex-row sm:items-center sm:justify-between">
      <span className="flex items-start gap-2">
        <AlertTriangleIcon className="size-4 shrink-0" />
        {endpoint.disabled_reason || t('admin.pages.settings.webhooks.health.auto_disabled_alert')}
      </span>
      <Button type="button" size="sm" variant="outline" onClick={onReEnable} disabled={reEnabling}>
        {t('admin.pages.settings.webhooks.health.re_enable_cta')}
      </Button>
    </div>
  )
}

// ---------------------------------------------------------------------------
// 4-tile health summary — Health badge / Deliveries / Successful / Failed.
// Mirrors `spree/admin/app/views/spree/admin/webhook_endpoints/_summary.html.erb`.
// ---------------------------------------------------------------------------

function HealthSummaryCard({ endpoint }: { endpoint: WebhookEndpoint }) {
  const { t } = useTranslation()

  const bucket = webhookEndpointHealth(endpoint)
  const variant = webhookHealthBadgeVariant(bucket)

  let healthLabel: string
  switch (bucket.kind) {
    case 'disabled':
      healthLabel = t('admin.pages.settings.webhooks.health.disabled')
      break
    case 'no_deliveries':
      healthLabel = t('admin.pages.settings.webhooks.health.no_deliveries')
      break
    case 'healthy':
      healthLabel = t('admin.pages.settings.webhooks.health.healthy', {
        percentage: bucket.percentage,
      })
      break
    case 'degraded':
      healthLabel = t('admin.pages.settings.webhooks.health.degraded', {
        percentage: bucket.percentage,
      })
      break
    case 'failing':
      healthLabel = t('admin.pages.settings.webhooks.health.failing', {
        percentage: bucket.percentage,
      })
      break
  }

  const total = endpoint.total_delivery_count ?? 0
  const successful = endpoint.successful_delivery_count ?? 0
  const failed = endpoint.failed_delivery_count ?? 0

  return (
    <Card>
      <CardContent>
        <div className="grid grid-cols-2 gap-6 sm:grid-cols-4">
          <HealthStat label={t('admin.pages.settings.webhooks.health.label')}>
            <Badge variant={variant}>{healthLabel}</Badge>
          </HealthStat>
          <HealthStat label={t('admin.pages.settings.webhooks.health.metric_total')}>
            <span className="text-lg font-semibold">{total}</span>
          </HealthStat>
          <HealthStat label={t('admin.pages.settings.webhooks.health.metric_successful')}>
            <span className="text-lg font-semibold">{successful}</span>
          </HealthStat>
          <HealthStat label={t('admin.pages.settings.webhooks.health.metric_failed')}>
            <span className={cn('text-lg font-semibold', failed > 0 && 'text-destructive')}>
              {failed}
            </span>
          </HealthStat>
        </div>
      </CardContent>
    </Card>
  )
}

function HealthStat({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-1.5">
      <span className="text-xs uppercase tracking-wide text-muted-foreground">{label}</span>
      {children}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Embedded deliveries list — the page's main content. Uses ResourceTable so
// pagination, sorting, and filters all flow through the URL.
// ---------------------------------------------------------------------------

function DeliveriesCard({
  endpointId,
  onSelect,
  searchParams,
}: {
  endpointId: string
  onSelect: (deliveryId: string) => void
  searchParams: ResourceSearch
}) {
  // The deliveries table's event-name cell carries `data-webhook-delivery-id`.
  // Bridging at the page level (rather than on the row) keeps cell rendering
  // identifier-free and survives ResourceTable's virtualisation/pagination.
  useRowClickBridge('data-webhook-delivery-id', onSelect)

  return (
    <ResourceTable<WebhookDelivery>
      tableKey="webhook-deliveries"
      // Mutation hooks invalidate +['webhook-deliveries', endpointId]+ —
      // ResourceTable auto-injects storeId between the two slots, so the
      // prefix-match still fires across remounts.
      queryKey={['webhook-deliveries', endpointId]}
      queryFn={(params) => adminClient.webhookEndpoints.deliveries.list(endpointId, params)}
      searchParams={searchParams}
    />
  )
}

// ---------------------------------------------------------------------------
// Right-column "Details" card. Mirrors `_details.html.erb`.
// ---------------------------------------------------------------------------

// Copyable URL rendered as the page subtitle — the destination URL is the
// most useful identifier after the name and used to live in a Details row
// where it overflowed. Inlining it next to the title removes the redundancy.
function CopyableUrl({ url }: { url: string }) {
  const { t } = useTranslation()
  return (
    <span className="inline-flex max-w-full items-center gap-1.5">
      <span className="truncate font-mono">{url}</span>
      <CopyToClipboardButton
        value={url}
        aria-label={t('admin.pages.settings.webhooks.table.copy_url_aria')}
      />
    </span>
  )
}

function DetailsCard({ endpoint }: { endpoint: WebhookEndpoint }) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.settings.webhooks.detail.details_title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col divide-y divide-border p-0">
        <DetailRow
          label={t('admin.pages.settings.webhooks.detail.subscriptions')}
          value={
            endpoint.subscriptions && endpoint.subscriptions.length > 0 ? (
              <div className="flex max-w-[16rem] flex-wrap justify-end gap-1">
                {endpoint.subscriptions.map((s) => (
                  <Badge key={s} variant="secondary" className="font-mono text-[10px]">
                    {s}
                  </Badge>
                ))}
              </div>
            ) : (
              <Badge variant="secondary">{t('admin.pages.settings.webhooks.events_all')}</Badge>
            )
          }
        />
        <DetailRow
          label={t('admin.pages.settings.webhooks.detail.created_at')}
          value={<RelativeTime iso={endpoint.created_at} />}
        />
        <DetailRow
          label={t('admin.pages.settings.webhooks.detail.updated_at')}
          value={<RelativeTime iso={endpoint.updated_at} />}
        />
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Edit endpoint sheet — opens via the header "Edit" button and the `?edit=1`
// URL param. Renders the same form fields as the Create flow.
// ---------------------------------------------------------------------------

function EditEndpointSheet({
  endpoint,
  form,
  open,
  onOpenChange,
  onSubmit,
}: {
  endpoint: WebhookEndpoint
  form: UseFormReturn<WebhookEndpointFormValues>
  open: boolean
  onOpenChange: (open: boolean) => void
  onSubmit: (values: WebhookEndpointFormValues) => Promise<void> | void
}) {
  const { t } = useTranslation()

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="sm:max-w-xl">
        <SheetHeader>
          <SheetTitle>
            {endpoint.name || endpoint.url || t('admin.pages.settings.webhooks.edit_sheet_title')}
          </SheetTitle>
          {endpoint.disabled_at && endpoint.disabled_reason && (
            <SheetDescription className="text-destructive">
              {t('admin.pages.settings.webhooks.status.disabled_reason', {
                reason: endpoint.disabled_reason,
              })}
            </SheetDescription>
          )}
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
            <Button
              type="submit"
              size="sm"
              disabled={form.formState.isSubmitting || !form.formState.isDirty}
            >
              {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

// ---------------------------------------------------------------------------
// Delivery detail sheet — mirrors the legacy admin's webhook_deliveries#show
// view (event, status, URL, code/time/error, request payload, response body,
// redeliver CTA on failures).
// ---------------------------------------------------------------------------

// Cap the response body at 2000 characters (matches the legacy view) so a
// misconfigured endpoint returning a multi-MB HTML error page doesn't blow
// up the sheet.
const RESPONSE_BODY_LIMIT = 2000

function DeliveryDetailSheet({
  endpointId,
  deliveryId,
  open,
  onOpenChange,
}: {
  endpointId: string
  deliveryId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: delivery, isLoading } = useWebhookDelivery(endpointId, deliveryId)
  const redeliver = useRedeliverWebhookDelivery(endpointId)

  const statusKey = delivery ? deliveryStatusKey(delivery) : null
  const failed = statusKey === 'failure' || statusKey === 'error'
  const truncatedResponse =
    delivery?.response_body && delivery.response_body.length > RESPONSE_BODY_LIMIT
      ? delivery.response_body.slice(0, RESPONSE_BODY_LIMIT)
      : (delivery?.response_body ?? '')

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="sm:max-w-2xl">
        <SheetHeader>
          <SheetTitle>
            {t('admin.pages.settings.webhooks.deliveries.detail_sheet_title')}
          </SheetTitle>
        </SheetHeader>
        <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4">
          {isLoading || !delivery ? (
            <Skeleton className="h-40 w-full" />
          ) : (
            <>
              <Card>
                <CardContent className="p-0">
                  <dl className="divide-y divide-border">
                    <DetailRow
                      label={t('admin.pages.settings.webhooks.deliveries.detail.event')}
                      value={<code className="font-mono text-xs">{delivery.event_name}</code>}
                    />
                    <DetailRow
                      label={t('admin.pages.settings.webhooks.deliveries.detail.status')}
                      value={
                        <Badge
                          variant={
                            statusKey === 'success'
                              ? 'default'
                              : failed
                                ? 'destructive'
                                : 'secondary'
                          }
                        >
                          {t(`admin.pages.settings.webhooks.deliveries.status.${statusKey}`)}
                        </Badge>
                      }
                    />
                    <DetailRow
                      label={t('admin.pages.settings.webhooks.deliveries.detail.url')}
                      value={
                        <a
                          href={delivery.webhook_endpoint_url}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="font-mono text-xs break-all text-foreground underline-offset-2 hover:underline"
                        >
                          {delivery.webhook_endpoint_url}
                        </a>
                      }
                    />
                    {delivery.delivered_at && (
                      <DetailRow
                        label={t('admin.pages.settings.webhooks.deliveries.detail.delivered_at')}
                        value={<RelativeTime iso={delivery.delivered_at} />}
                      />
                    )}
                    {delivery.response_code != null && (
                      <DetailRow
                        label={t('admin.pages.settings.webhooks.deliveries.detail.response_code')}
                        value={<code className="font-mono text-xs">{delivery.response_code}</code>}
                      />
                    )}
                    {delivery.execution_time != null && (
                      <DetailRow
                        label={t('admin.pages.settings.webhooks.deliveries.detail.execution_time')}
                        value={
                          <code className="font-mono text-xs">{delivery.execution_time}ms</code>
                        }
                      />
                    )}
                    {delivery.error_type && (
                      <DetailRow
                        label={t('admin.pages.settings.webhooks.deliveries.detail.error_type')}
                        value={<code className="font-mono text-xs">{delivery.error_type}</code>}
                      />
                    )}
                    {delivery.request_errors && (
                      <DetailRow
                        label={t('admin.pages.settings.webhooks.deliveries.detail.request_errors')}
                        value={
                          <code className="font-mono text-xs break-all whitespace-pre-wrap">
                            {delivery.request_errors}
                          </code>
                        }
                      />
                    )}
                  </dl>
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="flex flex-row items-center justify-between">
                  <CardTitle className="text-sm">
                    {t('admin.pages.settings.webhooks.deliveries.detail.request_payload')}
                  </CardTitle>
                  <CopyToClipboardButton
                    value={JSON.stringify(delivery.payload ?? {}, null, 2)}
                    aria-label={t(
                      'admin.pages.settings.webhooks.deliveries.detail.copy_payload_aria',
                    )}
                  />
                </CardHeader>
                <CardContent>
                  <Suspense fallback={<Skeleton className="h-40 w-full rounded-md" />}>
                    <JsonValueView value={delivery.payload ?? {}} />
                  </Suspense>
                </CardContent>
              </Card>

              {delivery.response_body && (
                <Card>
                  <CardHeader className="flex flex-row items-center justify-between">
                    <CardTitle className="text-sm">
                      {t('admin.pages.settings.webhooks.deliveries.detail.response_body')}
                    </CardTitle>
                    <CopyToClipboardButton
                      value={delivery.response_body}
                      aria-label={t(
                        'admin.pages.settings.webhooks.deliveries.detail.copy_response_aria',
                      )}
                    />
                  </CardHeader>
                  <CardContent className="flex flex-col gap-2">
                    <pre className="overflow-x-auto rounded-md border border-border bg-muted/40 p-3 font-mono text-xs break-all whitespace-pre-wrap">
                      {truncatedResponse}
                    </pre>
                    {delivery.response_body.length > RESPONSE_BODY_LIMIT && (
                      <span className="text-xs text-muted-foreground">
                        {t(
                          'admin.pages.settings.webhooks.deliveries.detail.response_body_truncated',
                          { limit: RESPONSE_BODY_LIMIT },
                        )}
                      </span>
                    )}
                  </CardContent>
                </Card>
              )}
            </>
          )}
        </div>
        {failed && (
          <SheetFooter>
            <Button
              type="button"
              size="sm"
              onClick={() =>
                redeliver
                  .mutateAsync(deliveryId)
                  .then(() =>
                    toast.success(t('admin.pages.settings.webhooks.deliveries.redeliver_queued')),
                  )
                  .catch(() => undefined)
              }
              disabled={redeliver.isPending}
            >
              <RotateCcwIcon className="size-4" />
              {t('admin.pages.settings.webhooks.actions.redeliver')}
            </Button>
          </SheetFooter>
        )}
      </SheetContent>
    </Sheet>
  )
}

function DetailRow({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex flex-row items-start justify-between gap-4 px-4 py-3">
      <dt className="text-sm text-muted-foreground">{label}</dt>
      <dd className="max-w-full text-right text-sm">{value}</dd>
    </div>
  )
}

function deliveryStatusKey(d: WebhookDelivery): 'pending' | 'success' | 'failure' | 'error' {
  if (d.delivered_at == null) return 'pending'
  if (d.success === true) return 'success'
  if (d.error_type) return 'error'
  return 'failure'
}

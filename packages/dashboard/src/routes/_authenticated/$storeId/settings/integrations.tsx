import type { Integration, IntegrationTypeDefinition } from '@spree/admin-sdk'
import {
  Can,
  defaultPreferences,
  PageHeader,
  PreferencesForm,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Switch,
  useConfirm,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlugIcon } from 'lucide-react'
import { useEffect, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import {
  useCreateIntegration,
  useDeleteIntegration,
  useIntegrations,
  useIntegrationTypes,
  useTestIntegration,
  useUpdateIntegration,
} from '../../../../hooks/use-integrations'

const integrationsSearchSchema = z.object({
  configure: z.string().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/integrations')({
  validateSearch: integrationsSearchSchema,
  component: IntegrationsPage,
})

function IntegrationsPage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const search = Route.useSearch()
  const { data: typesResponse, isLoading } = useIntegrationTypes()
  const { data: integrationsResponse } = useIntegrations()

  const types = useMemo(() => typesResponse?.data ?? [], [typesResponse])
  const integrations = useMemo(() => integrationsResponse?.data ?? [], [integrationsResponse])
  const integrationsByType = useMemo(
    () => new Map(integrations.map((integration) => [integration.type, integration])),
    [integrations],
  )

  // Gallery grouped by integration_group; groups arrive as open strings from
  // gems, so unknown ones fall back to a capitalized version of the token.
  const grouped = useMemo(() => {
    const map = new Map<string, IntegrationTypeDefinition[]>()
    for (const type of types) {
      const group = type.group ?? 'other'
      map.set(group, [...(map.get(group) ?? []), type])
    }
    return [...map.entries()]
  }, [types])

  const openConfigure = (type: string) =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, configure: type }) as never })

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { configure: _c, ...rest } = prev
        return rest as never
      },
    })

  const configuringType = types.find((type) => type.type === search.configure)

  return (
    <div className="flex flex-col gap-6 p-4">
      <PageHeader
        title={t('admin.integrations.title')}
        subtitle={t('admin.integrations.description')}
      />

      {!isLoading && types.length === 0 && (
        <Empty>
          <EmptyHeader>
            <EmptyMedia variant="icon">
              <PlugIcon />
            </EmptyMedia>
            <EmptyTitle>{t('admin.integrations.empty.title')}</EmptyTitle>
            <EmptyDescription>{t('admin.integrations.empty.description')}</EmptyDescription>
          </EmptyHeader>
        </Empty>
      )}

      {grouped.map(([group, groupTypes]) => (
        <section key={group} className="flex flex-col gap-3">
          <h2 className="font-medium text-muted-foreground text-sm">
            {t(`admin.integrations.groups.${group}`, {
              defaultValue: group.charAt(0).toUpperCase() + group.slice(1),
            })}
          </h2>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {groupTypes.map((type) => (
              <IntegrationCard
                key={type.type}
                type={type}
                integration={integrationsByType.get(type.type)}
                onConfigure={() => openConfigure(type.type)}
              />
            ))}
          </div>
        </section>
      ))}

      {configuringType && (
        <ConfigureIntegrationSheet
          type={configuringType}
          integration={integrationsByType.get(configuringType.type)}
          open
          onOpenChange={(open) => !open && closeSheet()}
        />
      )}
    </div>
  )
}

function IntegrationCard({
  type,
  integration,
  onConfigure,
}: {
  type: IntegrationTypeDefinition
  integration?: Integration
  onConfigure: () => void
}) {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const canWrite = permissions.can('update', Subject.Integration)

  return (
    <Card>
      <CardContent className="flex flex-col gap-3 p-4">
        <div className="flex items-center gap-3">
          <IntegrationLogo name={type.name} logoUrl={type.logo_url} />
          <div className="flex min-w-0 flex-1 flex-col gap-1">
            <span className="truncate font-medium text-sm">{type.name}</span>
            {integration ? (
              <Badge variant={integration.active ? 'default' : 'secondary'} className="w-fit">
                {integration.active
                  ? t('admin.integrations.status.active')
                  : t('admin.integrations.status.connected_inactive')}
              </Badge>
            ) : (
              <span className="text-muted-foreground text-xs">
                {t('admin.integrations.status.not_connected')}
              </span>
            )}
          </div>
          <Button size="sm" variant={integration ? 'outline' : 'default'} onClick={onConfigure}>
            {integration
              ? t('admin.integrations.configure_cta')
              : canWrite
                ? t('admin.integrations.connect_cta')
                : t('admin.integrations.view_cta')}
          </Button>
        </div>
        {type.description && (
          <p className="line-clamp-2 text-muted-foreground text-xs">{type.description}</p>
        )}
      </CardContent>
    </Card>
  )
}

// Gem-declared logo (hosted URL or data URI), falling back to an
// initial-letter avatar when none is declared — or when the URL fails to
// load (offline, vendor moved the file) — so cards never show a broken image.
function IntegrationLogo({ name, logoUrl }: { name: string; logoUrl: string | null }) {
  const [failed, setFailed] = useState(false)

  if (logoUrl && !failed) {
    return (
      <img
        src={logoUrl}
        alt=""
        onError={() => setFailed(true)}
        className="size-9 shrink-0 rounded-md object-contain"
      />
    )
  }

  return (
    <div className="flex size-9 shrink-0 items-center justify-center rounded-md bg-muted font-medium text-muted-foreground text-sm">
      {name.charAt(0).toUpperCase()}
    </div>
  )
}

function ConfigureIntegrationSheet({
  type,
  integration,
  open,
  onOpenChange,
}: {
  type: IntegrationTypeDefinition
  integration?: Integration
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const createMutation = useCreateIntegration()
  const updateMutation = useUpdateIntegration(integration?.id ?? '')
  const deleteMutation = useDeleteIntegration()
  const testMutation = useTestIntegration()

  const [preferences, setPreferences] = useState<Record<string, unknown>>({})
  const [active, setActive] = useState(false)
  const [submitError, setSubmitError] = useState<string | null>(null)
  const loadedIdRef = useRef<string | undefined>(undefined)

  useEffect(() => {
    if (integration) {
      if (integration.id === loadedIdRef.current) return
      setPreferences((integration.preferences as Record<string, unknown>) ?? {})
      setActive(integration.active)
      loadedIdRef.current = integration.id
    } else {
      setPreferences(defaultPreferences(type.preference_schema))
      setActive(false)
      loadedIdRef.current = undefined
    }
  }, [integration, type])

  const saving = createMutation.isPending || updateMutation.isPending

  async function handleSave() {
    setSubmitError(null)
    try {
      if (integration) {
        await updateMutation.mutateAsync({ active, preferences })
      } else {
        await createMutation.mutateAsync({ type: type.type, active, preferences })
      }
      onOpenChange(false)
    } catch (err) {
      // Activation failures come back as a 422 on `active` with the vendor's
      // message — surface it inline, where the admin can act on it.
      setSubmitError(err instanceof Error ? err.message : String(err))
    }
  }

  async function handleDisconnect() {
    if (!integration) return
    const ok = await confirm({
      title: t('admin.integrations.disconnect_confirm.title'),
      message: t('admin.integrations.disconnect_confirm.message', { name: type.name }),
      variant: 'destructive',
      confirmLabel: t('admin.integrations.disconnect'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(integration.id).catch(() => undefined)
    onOpenChange(false)
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{type.name}</SheetTitle>
          <SheetDescription>
            {integration
              ? t('admin.integrations.edit_description')
              : t('admin.integrations.connect_description')}
          </SheetDescription>
        </SheetHeader>
        <div className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            {submitError && (
              <p className="text-destructive text-sm" role="alert">
                {submitError}
              </p>
            )}

            <PreferencesForm
              schema={type.preference_schema}
              values={preferences}
              onChange={setPreferences}
            />

            <div className="flex items-center justify-between gap-3">
              <div className="flex flex-col">
                <span className="font-medium text-sm">
                  {t('admin.integrations.active_toggle.label')}
                </span>
                <span className="text-muted-foreground text-xs">
                  {t('admin.integrations.active_toggle.help')}
                </span>
              </div>
              <Switch checked={active} onCheckedChange={setActive} />
            </div>

            {integration && (
              <TestConnectionRow
                onTest={() => testMutation.mutateAsync(integration.id)}
                testing={testMutation.isPending}
                result={testMutation.data}
              />
            )}
          </div>
          <SheetFooter>
            {integration && (
              <Can I="destroy" a={Subject.Integration}>
                <Button
                  type="button"
                  variant="destructive"
                  size="sm"
                  onClick={handleDisconnect}
                  disabled={deleteMutation.isPending || saving}
                  className="mr-auto"
                >
                  {t('admin.integrations.disconnect')}
                </Button>
              </Can>
            )}
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => onOpenChange(false)}
              disabled={saving}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Can I={integration ? 'update' : 'create'} a={Subject.Integration}>
              <Button type="button" size="sm" onClick={handleSave} disabled={saving}>
                {saving
                  ? t('admin.actions.saving')
                  : integration
                    ? t('admin.actions.save')
                    : t('admin.integrations.connect_cta')}
              </Button>
            </Can>
          </SheetFooter>
        </div>
      </SheetContent>
    </Sheet>
  )
}

function TestConnectionRow({
  onTest,
  testing,
  result,
}: {
  onTest: () => Promise<unknown>
  testing: boolean
  result?: { connected: boolean; error_message: string | null }
}) {
  const { t } = useTranslation()

  return (
    <div className="flex flex-col gap-2 rounded-md border p-3">
      <div className="flex items-center justify-between gap-3">
        <span className="font-medium text-sm">{t('admin.integrations.test.label')}</span>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => onTest().catch(() => undefined)}
          disabled={testing}
        >
          {testing ? t('admin.integrations.test.testing') : t('admin.integrations.test.run')}
        </Button>
      </div>
      {result &&
        (result.connected ? (
          <p className="text-sm text-success">{t('admin.integrations.test.success')}</p>
        ) : (
          <p className="text-destructive text-sm" role="alert">
            {result.error_message ?? t('admin.integrations.test.failure')}
          </p>
        ))}
    </div>
  )
}

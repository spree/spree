import type { Integration, IntegrationTypeDefinition } from '@spree/admin-sdk'
import { PageHeader, Subject, usePermissions } from '@spree/dashboard-core'
import {
  Avatar,
  AvatarFallback,
  AvatarImage,
  Badge,
  Button,
  Card,
  CardContent,
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlugIcon } from 'lucide-react'
import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { ConfigureIntegrationSheet } from '../../../../components/spree/integrations/configure-integration-sheet'
import { useIntegrations, useIntegrationTypes } from '../../../../hooks/use-integrations'

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
    <div className="flex flex-col gap-6">
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
          key={`${configuringType.type}:${integrationsByType.get(configuringType.type)?.id ?? 'new'}`}
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

// Gem-declared logo (hosted URL or data URI); the Avatar compound shows the
// initial-letter fallback until the image loads, covering unset and
// unreachable URLs alike — same pattern as the store switcher.
function IntegrationLogo({ name, logoUrl }: { name: string; logoUrl: string | null }) {
  return (
    <Avatar className="size-9 shrink-0 rounded-md">
      {logoUrl && <AvatarImage src={logoUrl} className="object-contain" />}
      <AvatarFallback className="rounded-md">{name.charAt(0).toUpperCase()}</AvatarFallback>
    </Avatar>
  )
}

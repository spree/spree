import { PageHeader } from '@spree/dashboard-core'
import { Button, Empty, Skeleton } from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { AgentConnectionsCard } from '../../../../components/spree/agent-connections-card'
import { McpConnectSheet } from '../../../../components/spree/mcp-connect-sheet'
import { useOauthApplications } from '../../../../hooks/use-oauth'

export const Route = createFileRoute('/_authenticated/$storeId/settings/ai-agents')({
  component: AiAgentsSettingsPage,
})

function AiAgentsSettingsPage() {
  const { t } = useTranslation()
  const { data, isLoading } = useOauthApplications()
  const [connectOpen, setConnectOpen] = useState(false)

  const applications = data?.data ?? []

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={t('admin.pages.settings.ai_agents.title')}
        description={t('admin.pages.settings.ai_agents.subtitle')}
        actions={
          <Button size="sm" onClick={() => setConnectOpen(true)}>
            {t('admin.mcp_connect.open_cta')}
          </Button>
        }
      />

      <McpConnectSheet open={connectOpen} onOpenChange={setConnectOpen} />

      {isLoading && <Skeleton className="h-48 w-full" />}

      {!isLoading && applications.length === 0 && (
        <Empty>{t('admin.pages.settings.ai_agents.empty')}</Empty>
      )}

      {applications.map((application) => (
        <AgentConnectionsCard key={application.id} application={application} />
      ))}
    </div>
  )
}

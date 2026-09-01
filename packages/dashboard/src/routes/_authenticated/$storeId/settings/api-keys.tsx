import type { ApiKey } from '@spree/admin-sdk'
import { PageHeader } from '@spree/dashboard-core'
import { Button } from '@spree/dashboard-ui'
import { PlusIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { CreateApiKeyDialog } from '../../../../components/spree/api-keys/api-key-create-sheet'
import { EditApiKeyDialog } from '../../../../components/spree/api-keys/api-key-edit-sheet'
import {
  PublishableApiKeyTable,
  SecretApiKeyTable,
} from '../../../../components/spree/api-keys/api-key-table'
import { TokenRevealDialog } from '../../../../components/spree/api-keys/api-key-token-reveal-dialog'
import { useApiKeys } from '../../../../hooks/use-api-keys'
import { useChannels } from '../../../../hooks/use-channels'

export const Route = createFileRoute('/_authenticated/$storeId/settings/api-keys')({
  component: ApiKeysSettingsPage,
})

function ApiKeysSettingsPage() {
  const { t } = useTranslation()
  const { data, isLoading } = useApiKeys()
  const { data: channelsData } = useChannels()
  const [createOpen, setCreateOpen] = useState(false)
  const [tokenReveal, setTokenReveal] = useState<ApiKey | null>(null)
  const [editKey, setEditKey] = useState<ApiKey | null>(null)

  const keys = data?.data ?? []
  const publishable = keys.filter((k) => k.key_type === 'publishable')
  const secret = keys.filter((k) => k.key_type === 'secret')

  // Resolve `channel_id → name` for the bound-channel badge on publishable
  // rows. The list is already cached by `useChannels` (shared with the create
  // form), so this is a cheap in-memory lookup.
  const channelName = (channelId: string | null): string | undefined =>
    channelId ? channelsData?.data.find((c) => c.id === channelId)?.name : undefined

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={t('admin.pages.settings.api_keys.title')}
        subtitle={t('admin.pages.settings.api_keys.subtitle')}
        actions={
          <Button onClick={() => setCreateOpen(true)}>
            <PlusIcon className="size-4" />
            {t('admin.pages.settings.api_keys.new_cta')}
          </Button>
        }
      />

      <PublishableApiKeyTable
        keys={publishable}
        loading={isLoading}
        onEdit={setEditKey}
        channelName={channelName}
      />

      <SecretApiKeyTable keys={secret} loading={isLoading} onEdit={setEditKey} />

      <CreateApiKeyDialog
        open={createOpen}
        onOpenChange={setCreateOpen}
        onCreated={(key) => {
          setCreateOpen(false)
          // Surface the plaintext token modal only for secret keys — publishable
          // tokens are always readable from the row, so a one-shot reveal would
          // be confusing.
          if (key.key_type === 'secret' && key.plaintext_token) {
            setTokenReveal(key)
          }
        }}
      />

      <TokenRevealDialog
        apiKey={tokenReveal}
        onOpenChange={(open) => {
          if (!open) setTokenReveal(null)
        }}
      />

      <EditApiKeyDialog
        apiKey={editKey}
        onOpenChange={(open) => {
          if (!open) setEditKey(null)
        }}
      />
    </div>
  )
}

import { createFileRoute } from '@tanstack/react-router'
import { ConstructionIcon } from 'lucide-react'
import { EmptyState } from '@/components/spree/empty-state'
import { PageHeader } from '@/components/spree/page-header'
import { Card, CardContent } from '@/components/ui/card'

export const Route = createFileRoute('/_authenticated/$storeId/settings/api-keys')({
  component: ApiKeysSettingsPage,
})

// TODO: replace placeholder once the Admin API exposes CRUD for `Spree::ApiKey`
//   - controller: spree/api/app/controllers/spree/api/v3/admin/api_keys_controller.rb
//     (model exists, with KEY_TYPES, SCOPES, revoke!, plaintext_token surfacing)
//   - serializer: needs to be built. Mind: never serialize `token`/`token_digest`;
//     only the `token_prefix` (12 chars) for display. `plaintext_token` is one-shot
//     in the create response.
//   - sdk methods: client.apiKeys.{list,get,create,revoke}
//   - UX: scope picker on create (multiselect against ApiKey::SCOPES); show
//     plaintext token exactly once with a "copy and store securely" warning.
function ApiKeysSettingsPage() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="API keys"
        subtitle="Publishable and secret keys for the Storefront and Admin APIs."
      />
      <Card>
        <CardContent className="p-0">
          <EmptyState
            icon={<ConstructionIcon />}
            title="API key management is coming soon"
            description="Storefront and Admin keys are managed in the legacy Rails admin while the Admin API endpoints are being finalized."
          />
        </CardContent>
      </Card>
    </div>
  )
}

import { createFileRoute } from '@tanstack/react-router'
import { ConstructionIcon } from 'lucide-react'
import { EmptyState } from '@/components/spree/empty-state'
import { PageHeader } from '@/components/spree/page-header'
import { Card, CardContent } from '@/components/ui/card'

export const Route = createFileRoute('/_authenticated/$storeId/settings/staff')({
  component: StaffSettingsPage,
})

// TODO: replace placeholder once the Admin API exposes CRUD for `Spree.admin_user_class`
//   - controller: spree/api/app/controllers/spree/api/v3/admin/admin_users_controller.rb
//   - serializer already exists at spree/api/app/serializers/spree/api/v3/admin/admin_user_serializer.rb
//   - sdk methods: client.adminUsers.{list,get,create,update,delete}
//   - role assignment via Spree::RoleUser (scoped to current_store as resource)
function StaffSettingsPage() {
  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Staff"
        subtitle="Invite teammates and manage their access to this store."
      />
      <Card>
        <CardContent className="p-0">
          <EmptyState
            icon={<ConstructionIcon />}
            title="Staff management is coming soon"
            description="The Admin API endpoints for inviting and managing staff are next on the roadmap. In the meantime, manage staff via the legacy Rails admin."
          />
        </CardContent>
      </Card>
    </div>
  )
}

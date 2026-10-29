import { adminClient, InvitationAcceptance, usePermissions } from '@spree/dashboard-core'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { z } from 'zod/v4'
import { AuthShell } from '../components/spree/auth-shell'

const acceptSearchSchema = z.object({
  token: z.string().min(1).optional(),
})

export const Route = createFileRoute('/accept-invitation/$invitationId')({
  validateSearch: acceptSearchSchema,
  component: AcceptInvitationPage,
})

function AcceptInvitationPage() {
  const { invitationId } = Route.useParams()
  const { token } = Route.useSearch()
  const navigate = useNavigate()
  const { refresh: refreshPermissions } = usePermissions()

  return (
    <AuthShell>
      <InvitationAcceptance
        invitationId={invitationId}
        token={token}
        lookup={async (id, token) => {
          const invitation = await adminClient.auth.lookupInvitation(id, token)
          return { ...invitation, target: invitation.store }
        }}
        onAccepted={async (invitation) => {
          await navigate({
            to: '/$storeId',
            params: { storeId: invitation.target.id },
            replace: true,
          })
          // The session's permissions were loaded before it held a role here.
          // Refreshed once the store is entered, so they are fetched for it.
          await refreshPermissions()
        }}
      />
    </AuthShell>
  )
}

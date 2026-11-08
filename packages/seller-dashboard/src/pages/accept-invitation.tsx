import { InvitationAcceptance } from '@spree/dashboard-core'
import { useNavigate } from '@tanstack/react-router'
import { sellerClient } from '../api-client'

/**
 * Joining a seller's team from the emailed link.
 *
 * The screens are the framework's, shared with the operator's dashboard; what
 * is the panel's own is which API answers the lookup and where an accepted
 * member lands. That is the seller they joined: the layout under that route
 * loads the member's permissions for it.
 */
export function AcceptInvitationPage({
  invitationId,
  token,
}: {
  invitationId: string
  token?: string
}) {
  const navigate = useNavigate()

  return (
    <div className="flex min-h-screen items-center justify-center p-6">
      <div className="flex w-full max-w-sm flex-col gap-6">
        <InvitationAcceptance
          invitationId={invitationId}
          token={token}
          lookup={async (id, token) => {
            const invitation = await sellerClient().auth.lookupInvitation(id, token)
            // Carried by the lookup alone; the team listings leave it out.
            return {
              ...invitation,
              invitee_exists: invitation.invitee_exists ?? false,
              target: invitation.seller,
            }
          }}
          onAccepted={(invitation) =>
            navigate({
              to: '/$sellerId',
              params: { sellerId: invitation.target.id },
              replace: true,
            })
          }
        />
      </div>
    </div>
  )
}

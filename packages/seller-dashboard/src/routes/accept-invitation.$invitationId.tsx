import { createFileRoute } from '@tanstack/react-router'
import { z } from 'zod/v4'
import { AcceptInvitationPage } from '../pages/accept-invitation'

const acceptSearchSchema = z.object({
  token: z.string().min(1).optional(),
})

export const Route = createFileRoute('/accept-invitation/$invitationId')({
  validateSearch: acceptSearchSchema,
  component: AcceptInvitation,
})

function AcceptInvitation() {
  const { invitationId } = Route.useParams()
  const { token } = Route.useSearch()

  return <AcceptInvitationPage invitationId={invitationId} token={token} />
}

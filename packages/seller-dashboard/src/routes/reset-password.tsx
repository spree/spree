import { createFileRoute } from '@tanstack/react-router'
import { z } from 'zod/v4'
import { ResetPasswordPage } from '../pages/reset-password'

const resetSearchSchema = z.object({
  token: z.string().min(1).optional(),
})

export const Route = createFileRoute('/reset-password')({
  validateSearch: resetSearchSchema,
  component: ResetPassword,
})

function ResetPassword() {
  const { token } = Route.useSearch()

  // No redirect for a live session: someone following a reset link means to
  // change their password, and a stale session in the same browser must not
  // silently swallow the link.
  return <ResetPasswordPage token={token} />
}

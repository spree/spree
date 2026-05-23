import { zodResolver } from '@hookform/resolvers/zod'
import type { InvitationLookup, SpreeError } from '@spree/admin-sdk'
import { useQuery } from '@tanstack/react-query'
import { createFileRoute, Navigate, useNavigate } from '@tanstack/react-router'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { adminClient } from '@/client'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useAuth } from '@/hooks/use-auth'
import { mapSpreeErrorsToForm } from '@/lib/form-errors'

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
  const { isAuthenticated } = useAuth()

  if (isAuthenticated) return <Navigate to="/" replace />

  if (!token) {
    return (
      <Shell>
        <ErrorCard
          title="Missing invitation token"
          message="This link looks incomplete. Ask whoever invited you to send it again."
        />
      </Shell>
    )
  }

  return (
    <Shell>
      <InvitationLoader invitationId={invitationId} token={token} />
    </Shell>
  )
}

function InvitationLoader({ invitationId, token }: { invitationId: string; token: string }) {
  const lookup = useQuery({
    queryKey: ['invitation-lookup', invitationId, token],
    queryFn: () => adminClient.auth.lookupInvitation(invitationId, token),
    retry: false,
  })

  if (lookup.isPending) {
    return (
      <Card>
        <CardContent className="py-12 text-center text-muted-foreground">
          Loading invitation…
        </CardContent>
      </Card>
    )
  }

  if (lookup.isError) {
    const err = lookup.error as SpreeError
    return (
      <ErrorCard
        title={err.status === 404 ? 'Invitation not found' : 'Could not load invitation'}
        message={
          err.status === 404
            ? 'This invitation has expired, been revoked, or already been accepted. Ask the inviter to send a new one.'
            : err.message || 'Something went wrong. Please try again.'
        }
      />
    )
  }

  return <AcceptForm invitationId={invitationId} token={token} invitation={lookup.data} />
}

function AcceptForm({
  invitationId,
  token,
  invitation,
}: {
  invitationId: string
  token: string
  invitation: InvitationLookup
}) {
  return invitation.invitee_exists ? (
    <SignInForm invitationId={invitationId} token={token} invitation={invitation} />
  ) : (
    <SignUpForm invitationId={invitationId} token={token} invitation={invitation} />
  )
}

const signInSchema = z.object({
  password: z.string().min(1, 'Password is required'),
})
type SignInForm = z.infer<typeof signInSchema>

function SignInForm({
  invitationId,
  token,
  invitation,
}: {
  invitationId: string
  token: string
  invitation: InvitationLookup
}) {
  const { t } = useTranslation()
  const { acceptInvitation, isLoading } = useAuth()
  const navigate = useNavigate()

  const form = useForm<SignInForm>({
    resolver: zodResolver(signInSchema),
    defaultValues: { password: '' },
  })
  const { errors } = form.formState

  const onSubmit = async (data: SignInForm) => {
    try {
      await acceptInvitation(invitationId, token, { password: data.password })
      navigate({ to: '/', replace: true })
    } catch (err) {
      const e = err as SpreeError
      if (e?.status === 401) {
        form.setError('root', { message: 'Invalid password' })
        return
      }
      if (!mapSpreeErrorsToForm(err, form.setError)) {
        form.setError('root', { message: e?.message || 'Could not accept invitation' })
      }
    }
  }

  return (
    <Card>
      <CardHeader className="text-center">
        <CardTitle className="text-xl">Join {invitation.store.name ?? 'this store'}</CardTitle>
        <CardDescription>
          {invitation.inviter_email
            ? `${invitation.inviter_email} invited you`
            : 'You have been invited'}
          {invitation.role_name ? ` as ${invitation.role_name}` : null}. Sign in to accept.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={form.handleSubmit(onSubmit)} className="grid gap-6">
          {errors.root && (
            <p className="text-center text-sm text-destructive">{errors.root.message}</p>
          )}
          <div className="grid gap-2">
            <Label htmlFor="invitee-email">{t('admin.fields.email.label')}</Label>
            <Input id="invitee-email" value={invitation.email} disabled />
          </div>
          <div className="grid gap-2">
            <Label htmlFor="password">
              {t('admin.fields.invitation_acceptance.password.label')}
            </Label>
            <Input
              id="password"
              type="password"
              autoFocus
              aria-invalid={!!errors.password || undefined}
              {...form.register('password')}
            />
            {errors.password && (
              <p className="text-sm text-destructive">{errors.password.message}</p>
            )}
          </div>
          <Button type="submit" className="w-full" disabled={isLoading}>
            {isLoading ? 'Accepting…' : 'Sign in & accept'}
          </Button>
        </form>
      </CardContent>
    </Card>
  )
}

const signUpSchema = z
  .object({
    first_name: z.string().min(1, 'First name is required'),
    last_name: z.string().min(1, 'Last name is required'),
    password: z.string().min(8, 'Password must be at least 8 characters'),
    password_confirmation: z.string(),
  })
  .refine((data) => data.password === data.password_confirmation, {
    message: 'Passwords do not match',
    path: ['password_confirmation'],
  })
type SignUpForm = z.infer<typeof signUpSchema>

function SignUpForm({
  invitationId,
  token,
  invitation,
}: {
  invitationId: string
  token: string
  invitation: InvitationLookup
}) {
  const { t } = useTranslation()
  const { acceptInvitation, isLoading } = useAuth()
  const navigate = useNavigate()

  const form = useForm<SignUpForm>({
    resolver: zodResolver(signUpSchema),
    defaultValues: { first_name: '', last_name: '', password: '', password_confirmation: '' },
  })
  const { errors } = form.formState

  const onSubmit = async (data: SignUpForm) => {
    try {
      await acceptInvitation(invitationId, token, data)
      navigate({ to: '/', replace: true })
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) {
        const e = err as SpreeError
        form.setError('root', { message: e?.message || 'Could not accept invitation' })
      }
    }
  }

  return (
    <Card>
      <CardHeader className="text-center">
        <CardTitle className="text-xl">Join {invitation.store.name ?? 'this store'}</CardTitle>
        <CardDescription>
          {invitation.inviter_email
            ? `${invitation.inviter_email} invited you`
            : 'You have been invited'}
          {invitation.role_name ? ` as ${invitation.role_name}` : null}. Create your account to
          accept.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={form.handleSubmit(onSubmit)} className="grid gap-6">
          {errors.root && (
            <p className="text-center text-sm text-destructive">{errors.root.message}</p>
          )}
          <div className="grid gap-2">
            <Label htmlFor="invitee-email">{t('admin.fields.email.label')}</Label>
            <Input id="invitee-email" value={invitation.email} disabled />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div className="grid gap-2">
              <Label htmlFor="first_name">{t('admin.fields.first_name.label')}</Label>
              <Input
                id="first_name"
                autoFocus
                aria-invalid={!!errors.first_name || undefined}
                {...form.register('first_name')}
              />
              {errors.first_name && (
                <p className="text-sm text-destructive">{errors.first_name.message}</p>
              )}
            </div>
            <div className="grid gap-2">
              <Label htmlFor="last_name">{t('admin.fields.last_name.label')}</Label>
              <Input
                id="last_name"
                aria-invalid={!!errors.last_name || undefined}
                {...form.register('last_name')}
              />
              {errors.last_name && (
                <p className="text-sm text-destructive">{errors.last_name.message}</p>
              )}
            </div>
          </div>
          <div className="grid gap-2">
            <Label htmlFor="password">
              {t('admin.fields.invitation_acceptance.password.label')}
            </Label>
            <Input
              id="password"
              type="password"
              aria-invalid={!!errors.password || undefined}
              {...form.register('password')}
            />
            {errors.password && (
              <p className="text-sm text-destructive">{errors.password.message}</p>
            )}
          </div>
          <div className="grid gap-2">
            <Label htmlFor="password_confirmation">
              {t('admin.fields.invitation_acceptance.password_confirmation.label')}
            </Label>
            <Input
              id="password_confirmation"
              type="password"
              aria-invalid={!!errors.password_confirmation || undefined}
              {...form.register('password_confirmation')}
            />
            {errors.password_confirmation && (
              <p className="text-sm text-destructive">{errors.password_confirmation.message}</p>
            )}
          </div>
          <Button type="submit" className="w-full" disabled={isLoading}>
            {isLoading ? 'Creating account…' : 'Create account & accept'}
          </Button>
        </form>
      </CardContent>
    </Card>
  )
}

function ErrorCard({ title, message }: { title: string; message: string }) {
  return (
    <Card>
      <CardHeader className="text-center">
        <CardTitle className="text-xl">{title}</CardTitle>
        <CardDescription>{message}</CardDescription>
      </CardHeader>
    </Card>
  )
}

function Shell({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex min-h-svh flex-col items-center justify-center gap-6 bg-muted p-6 md:p-10">
      <div className="flex w-full max-w-sm flex-col gap-6">{children}</div>
    </div>
  )
}

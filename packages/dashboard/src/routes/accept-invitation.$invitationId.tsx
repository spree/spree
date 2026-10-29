import { zodResolver } from '@hookform/resolvers/zod'
import type { Invitation, SpreeError } from '@spree/admin-sdk'
import { adminClient, mapSpreeErrorsToForm, useAuth, usePermissions } from '@spree/dashboard-core'
import { Button, Input, Label } from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { AuthShell } from '../components/spree/auth-shell'
import {
  type AcceptInvitationSignInFormValues,
  type AcceptInvitationSignUpFormValues,
  acceptInvitationSignInFormSchema,
  acceptInvitationSignUpFormSchema,
} from '../schemas/auth'

const acceptSearchSchema = z.object({
  token: z.string().min(1).optional(),
})

export const Route = createFileRoute('/accept-invitation/$invitationId')({
  validateSearch: acceptSearchSchema,
  component: AcceptInvitationPage,
})

function AcceptInvitationPage() {
  const { t } = useTranslation()
  const { invitationId } = Route.useParams()
  const { token } = Route.useSearch()
  const { isInitializing } = useAuth()

  if (!token) {
    return (
      <AuthShell>
        <ErrorCard
          title={t('admin.invitation.missing_token_title')}
          message={t('admin.invitation.missing_token_message')}
        />
      </AuthShell>
    )
  }

  // Waits for the session check: it decides which form fits, and a failed one
  // clears the query cache mid-lookup.
  if (isInitializing) {
    return (
      <AuthShell>
        <div className="py-12 text-center text-muted-foreground">
          {t('admin.invitation.loading')}
        </div>
      </AuthShell>
    )
  }

  return (
    <AuthShell>
      <InvitationLoader invitationId={invitationId} token={token} />
    </AuthShell>
  )
}

function InvitationLoader({ invitationId, token }: { invitationId: string; token: string }) {
  const { t } = useTranslation()
  const lookup = useQuery({
    queryKey: ['invitation-lookup', invitationId, token],
    queryFn: () => adminClient.auth.lookupInvitation(invitationId, token),
    retry: false,
  })

  if (lookup.isPending) {
    return (
      <div className="py-12 text-center text-muted-foreground">{t('admin.invitation.loading')}</div>
    )
  }

  if (lookup.isError) {
    const err = lookup.error as SpreeError
    return (
      <ErrorCard
        title={
          err.status === 404
            ? t('admin.invitation.not_found_title')
            : t('admin.invitation.generic_error_title')
        }
        message={
          err.status === 404
            ? t('admin.invitation.not_found_message')
            : err.message || t('admin.invitation.generic_error_message')
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
  invitation: Invitation
}) {
  const { user } = useAuth()
  // Signing in through a form below sets `user` before the redirect lands;
  // a page opened signed out keeps showing that form until then.
  const [openedSignedOut] = useState(!user)
  if (user && !openedSignedOut) {
    // Accepting signs in as the invitee, so someone signed in as another
    // account signs out first rather than having their session swapped silently.
    return user.email.toLowerCase() === invitation.email.toLowerCase() ? (
      <AcceptAsSignedIn invitationId={invitationId} token={token} invitation={invitation} />
    ) : (
      <SignedInAsAnotherAccount invitation={invitation} />
    )
  }

  return invitation.invitee_exists ? (
    <SignInForm invitationId={invitationId} token={token} invitation={invitation} />
  ) : (
    <SignUpForm invitationId={invitationId} token={token} invitation={invitation} />
  )
}

function SignInForm({
  invitationId,
  token,
  invitation,
}: {
  invitationId: string
  token: string
  invitation: Invitation
}) {
  const { t } = useTranslation()
  const { acceptInvitation, isLoading } = useAuth()
  const navigate = useNavigate()

  const form = useForm<AcceptInvitationSignInFormValues>({
    resolver: zodResolver(acceptInvitationSignInFormSchema),
    defaultValues: { password: '' },
  })
  const { errors } = form.formState

  const onSubmit = async (data: AcceptInvitationSignInFormValues) => {
    try {
      await acceptInvitation(invitationId, token, { password: data.password })
      navigate({ to: '/$storeId', params: { storeId: invitation.store.id }, replace: true })
    } catch (err) {
      const e = err as SpreeError
      if (e?.status === 401) {
        form.setError('root', { message: t('admin.validation.invalid_password') })
        return
      }
      if (!mapSpreeErrorsToForm(err, form.setError)) {
        form.setError('root', { message: e?.message || t('admin.invitation.could_not_accept') })
      }
    }
  }

  return (
    <>
      <InvitationIntro invitation={invitation} action={t('admin.invitation.sign_in_to_accept')} />
      <form onSubmit={form.handleSubmit(onSubmit)} className="grid gap-6">
        {errors.root && <p className="text-sm text-destructive">{errors.root.message}</p>}
        <div className="grid gap-2">
          <Label htmlFor="invitee-email">{t('admin.fields.email.label')}</Label>
          <Input id="invitee-email" value={invitation.email} disabled />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="password">{t('admin.fields.invitation_acceptance.password.label')}</Label>
          <Input
            id="password"
            type="password"
            autoFocus
            aria-invalid={!!errors.password || undefined}
            {...form.register('password')}
          />
          {errors.password && <p className="text-sm text-destructive">{errors.password.message}</p>}
        </div>
        <Button type="submit" className="w-full" disabled={isLoading}>
          {isLoading ? t('admin.invitation.accepting') : t('admin.invitation.sign_in_and_accept')}
        </Button>
      </form>
    </>
  )
}

function SignUpForm({
  invitationId,
  token,
  invitation,
}: {
  invitationId: string
  token: string
  invitation: Invitation
}) {
  const { t } = useTranslation()
  const { acceptInvitation, isLoading } = useAuth()
  const navigate = useNavigate()

  const form = useForm<AcceptInvitationSignUpFormValues>({
    resolver: zodResolver(acceptInvitationSignUpFormSchema),
    defaultValues: { first_name: '', last_name: '', password: '', password_confirmation: '' },
  })
  const { errors } = form.formState

  const onSubmit = async (data: AcceptInvitationSignUpFormValues) => {
    try {
      await acceptInvitation(invitationId, token, data)
      navigate({ to: '/$storeId', params: { storeId: invitation.store.id }, replace: true })
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) {
        const e = err as SpreeError
        form.setError('root', { message: e?.message || t('admin.invitation.could_not_accept') })
      }
    }
  }

  return (
    <>
      <InvitationIntro invitation={invitation} action={t('admin.invitation.create_to_accept')} />
      <form onSubmit={form.handleSubmit(onSubmit)} className="grid gap-6">
        {errors.root && <p className="text-sm text-destructive">{errors.root.message}</p>}
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
          <Label htmlFor="password">{t('admin.fields.invitation_acceptance.password.label')}</Label>
          <Input
            id="password"
            type="password"
            aria-invalid={!!errors.password || undefined}
            {...form.register('password')}
          />
          {errors.password && <p className="text-sm text-destructive">{errors.password.message}</p>}
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
          {isLoading ? t('admin.invitation.accepting') : t('admin.invitation.create_and_accept')}
        </Button>
      </form>
    </>
  )
}

function AcceptAsSignedIn({
  invitationId,
  token,
  invitation,
}: {
  invitationId: string
  token: string
  invitation: Invitation
}) {
  const { t } = useTranslation()
  const { user, acceptInvitation, logout, isLoading } = useAuth()
  const { refresh: refreshPermissions } = usePermissions()
  const navigate = useNavigate()
  const [error, setError] = useState<string | null>(null)

  const onAccept = async () => {
    setError(null)
    try {
      await acceptInvitation(invitationId, token, {})
    } catch (err) {
      const e = err as SpreeError
      // The session lapsed (a laptop that slept, say): signing out brings up
      // the password form instead of an error with no way forward.
      if (e?.status === 401) return logout()
      setError(e?.message || t('admin.invitation.could_not_accept'))
      return
    }
    await navigate({ to: '/$storeId', params: { storeId: invitation.store.id }, replace: true })
    // The session's permissions were loaded before it held a role here.
    // Refreshed once the store is entered, so they are fetched for it.
    await refreshPermissions()
  }

  return (
    <>
      <InvitationIntro
        invitation={invitation}
        action={t('admin.invitation.signed_in_as_invitee', { email: user?.email })}
      />
      {error && <p className="text-sm text-destructive">{error}</p>}
      <Button className="w-full" disabled={isLoading} onClick={onAccept}>
        {isLoading ? t('admin.invitation.accepting') : t('admin.invitation.accept')}
      </Button>
    </>
  )
}

function SignedInAsAnotherAccount({ invitation }: { invitation: Invitation }) {
  const { t } = useTranslation()
  const { user, logout } = useAuth()

  return (
    <>
      <div className="flex flex-col gap-2">
        <h1 className="text-2xl font-bold">
          {t('admin.invitation.join_store', { store: invitation.store.name })}
        </h1>
        <p className="text-sm text-muted-foreground">
          {t('admin.invitation.signed_in_as_another_account', {
            email: user?.email,
            invitee: invitation.email,
          })}
        </p>
      </div>
      <Button variant="outline" className="w-full" onClick={() => logout()}>
        {t('admin.auth.logout')}
      </Button>
    </>
  )
}

function InvitationIntro({ invitation, action }: { invitation: Invitation; action: string }) {
  const { t } = useTranslation()
  const invitedPart = invitation.inviter_email
    ? t('admin.invitation.invited_by', { email: invitation.inviter_email })
    : t('admin.invitation.invited_generic')
  const rolePart = invitation.role_name
    ? t('admin.invitation.invited_as_role', { role: invitation.role_name })
    : ''

  return (
    <div className="flex flex-col gap-2">
      <h1 className="text-2xl font-bold">
        {t('admin.invitation.join_store', { store: invitation.store.name })}
      </h1>
      <p className="text-sm text-muted-foreground">{`${invitedPart}${rolePart}${action}`}</p>
    </div>
  )
}

function ErrorCard({ title, message }: { title: string; message: string }) {
  return (
    <div className="flex flex-col gap-2">
      <h1 className="text-2xl font-bold">{title}</h1>
      <p className="text-sm text-muted-foreground">{message}</p>
    </div>
  )
}

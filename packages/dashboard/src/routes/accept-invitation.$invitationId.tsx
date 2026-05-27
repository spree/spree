import { zodResolver } from '@hookform/resolvers/zod'
import type { Invitation, SpreeError } from '@spree/admin-sdk'
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Input,
  Label,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { createFileRoute, Navigate, useNavigate } from '@tanstack/react-router'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { adminClient } from '@/client'
import { useAuth } from '@/hooks/use-auth'
import { mapSpreeErrorsToForm } from '@/lib/form-errors'
import {
  type AcceptInvitationSignInFormValues,
  type AcceptInvitationSignUpFormValues,
  acceptInvitationSignInFormSchema,
  acceptInvitationSignUpFormSchema,
} from '@/schemas/auth'

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
  const { isAuthenticated } = useAuth()

  if (isAuthenticated) return <Navigate to="/" replace />

  if (!token) {
    return (
      <Shell>
        <ErrorCard
          title={t('admin.invitation.missing_token_title')}
          message={t('admin.invitation.missing_token_message')}
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
  const { t } = useTranslation()
  const lookup = useQuery({
    queryKey: ['invitation-lookup', invitationId, token],
    queryFn: () => adminClient.auth.lookupInvitation(invitationId, token),
    retry: false,
  })

  if (lookup.isPending) {
    return (
      <Card>
        <CardContent className="py-12 text-center text-muted-foreground">
          {t('admin.invitation.loading')}
        </CardContent>
      </Card>
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
      navigate({ to: '/', replace: true })
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

  const invitedPart = invitation.inviter_email
    ? t('admin.invitation.invited_by', { email: invitation.inviter_email })
    : t('admin.invitation.invited_generic')
  const rolePart = invitation.role_name
    ? t('admin.invitation.invited_as_role', { role: invitation.role_name })
    : ''
  const actionPart = t('admin.invitation.sign_in_to_accept')

  return (
    <Card>
      <CardHeader className="text-center">
        <CardTitle className="text-xl">
          {t('admin.invitation.join_store', { store: invitation.store.name })}
        </CardTitle>
        <CardDescription>{`${invitedPart}${rolePart}${actionPart}`}</CardDescription>
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
            {isLoading ? t('admin.invitation.accepting') : t('admin.invitation.sign_in_and_accept')}
          </Button>
        </form>
      </CardContent>
    </Card>
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
      navigate({ to: '/', replace: true })
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) {
        const e = err as SpreeError
        form.setError('root', { message: e?.message || t('admin.invitation.could_not_accept') })
      }
    }
  }

  const invitedPart = invitation.inviter_email
    ? t('admin.invitation.invited_by', { email: invitation.inviter_email })
    : t('admin.invitation.invited_generic')
  const rolePart = invitation.role_name
    ? t('admin.invitation.invited_as_role', { role: invitation.role_name })
    : ''
  const actionPart = t('admin.invitation.create_to_accept')

  return (
    <Card>
      <CardHeader className="text-center">
        <CardTitle className="text-xl">
          {t('admin.invitation.join_store', { store: invitation.store.name })}
        </CardTitle>
        <CardDescription>{`${invitedPart}${rolePart}${actionPart}`}</CardDescription>
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
            {isLoading ? t('admin.invitation.accepting') : t('admin.invitation.create_and_accept')}
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

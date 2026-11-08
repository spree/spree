import { zodResolver } from '@hookform/resolvers/zod'
import type { SpreeError } from '@spree/admin-sdk'
import { Button, Input, Label } from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { useAuth } from '../hooks/use-auth'
import { mapSpreeErrorsToForm } from '../lib/form-errors'
import { i18n } from '../lib/i18n'

/**
 * What the acceptance page needs to know about an invitation, as both the
 * Admin and the Seller API lookups answer it. `target` is what the invitee
 * joins: the store on the operator's dashboard, a seller on the seller panel.
 */
export interface InvitationSummary {
  email: string
  invitee_exists: boolean
  inviter_email?: string | null
  role_name?: string | null
  target: { id: string; name: string }
}

export interface InvitationAcceptanceProps {
  invitationId: string
  /** From the emailed link's query string; the page refuses to go on without it. */
  token?: string
  lookup: (invitationId: string, token: string) => Promise<InvitationSummary>
  /** Runs once the invitee's session is established, to take them into what they joined. */
  onAccepted: (invitation: InvitationSummary) => void | Promise<void>
}

// Lazy message factories: module-scope `i18n.t(...)` would lock the English
// string in at import time, breaking locale switches.
const passwordRequired = () => i18n.t('admin.validation.password_required')
const firstNameRequired = () => i18n.t('admin.validation.first_name_required')
const lastNameRequired = () => i18n.t('admin.validation.last_name_required')
const passwordsDontMatch = () => i18n.t('admin.validation.passwords_dont_match')
const passwordMinLength = () =>
  i18n.t('admin.validation.min_length', { field: i18n.t('admin.fields.password.label'), count: 8 })

/** Existing invitee confirming with their current password. */
const signInSchema = z.object({
  password: z.string().min(1, { error: passwordRequired }),
})
type SignInValues = z.infer<typeof signInSchema>

/** New invitee creating an account inline — mirrors the server's `AdminUser` validations. */
const signUpSchema = z
  .object({
    first_name: z.string().min(1, { error: firstNameRequired }),
    last_name: z.string().min(1, { error: lastNameRequired }),
    password: z.string().min(8, { error: passwordMinLength }),
    password_confirmation: z.string(),
  })
  .refine((data) => data.password === data.password_confirmation, {
    error: passwordsDontMatch,
    path: ['password_confirmation'],
  })
type SignUpValues = z.infer<typeof signUpSchema>

/**
 * The screens behind an invitation link, shared by both panels. The host
 * wraps it in its own page layout and decides where an accepted invitee goes.
 *
 * Someone signed out sets a password (new account) or confirms theirs
 * (existing account). Someone already signed in as the invitee accepts with
 * one click; signed in as anyone else, they are asked to sign out first
 * rather than having their session swapped silently.
 */
export function InvitationAcceptance({
  invitationId,
  token,
  lookup,
  onAccepted,
}: InvitationAcceptanceProps) {
  const { t } = useTranslation()
  const { isInitializing } = useAuth()

  if (!token) {
    return (
      <ErrorCard
        title={t('admin.invitation.missing_token_title')}
        message={t('admin.invitation.missing_token_message')}
      />
    )
  }

  // Waits for the session check: it decides which form fits, and a failed one
  // clears the query cache mid-lookup.
  if (isInitializing) return <Loading />

  return (
    <InvitationLoader
      invitationId={invitationId}
      token={token}
      lookup={lookup}
      onAccepted={onAccepted}
    />
  )
}

type LoadedProps = Required<InvitationAcceptanceProps>

function InvitationLoader({ invitationId, token, lookup, onAccepted }: LoadedProps) {
  const { t } = useTranslation()
  const query = useQuery({
    queryKey: ['invitation-lookup', invitationId, token],
    queryFn: () => lookup(invitationId, token),
    retry: false,
  })

  if (query.isPending) return <Loading />

  if (query.isError) {
    const err = query.error as SpreeError
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

  return (
    <AcceptForm
      invitationId={invitationId}
      token={token}
      invitation={query.data}
      onAccepted={onAccepted}
    />
  )
}

interface FormProps {
  invitationId: string
  token: string
  invitation: InvitationSummary
  onAccepted: LoadedProps['onAccepted']
}

function AcceptForm(props: FormProps) {
  const { user } = useAuth()
  const { invitation } = props
  // Signing in through a form below sets `user` before the redirect lands;
  // a page opened signed out keeps showing that form until then.
  const [openedSignedOut] = useState(!user)
  if (user && !openedSignedOut) {
    return user.email.toLowerCase() === invitation.email.toLowerCase() ? (
      <AcceptAsSignedIn {...props} />
    ) : (
      <SignedInAsAnotherAccount invitation={invitation} />
    )
  }

  return invitation.invitee_exists ? <SignInForm {...props} /> : <SignUpForm {...props} />
}

function SignInForm({ invitationId, token, invitation, onAccepted }: FormProps) {
  const { t } = useTranslation()
  const { acceptInvitation, isLoading } = useAuth()

  const form = useForm<SignInValues>({
    resolver: zodResolver(signInSchema),
    defaultValues: { password: '' },
  })
  const { errors } = form.formState

  const onSubmit = async (data: SignInValues) => {
    try {
      await acceptInvitation(invitationId, token, { password: data.password })
    } catch (err) {
      const e = err as SpreeError
      if (e?.status === 401) {
        form.setError('root', { message: t('admin.validation.invalid_password') })
        return
      }
      if (!mapSpreeErrorsToForm(err, form.setError)) {
        form.setError('root', { message: e?.message || t('admin.invitation.could_not_accept') })
      }
      return
    }
    await onAccepted(invitation)
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
          <Label htmlFor="password">{t('admin.fields.password.label')}</Label>
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

function SignUpForm({ invitationId, token, invitation, onAccepted }: FormProps) {
  const { t } = useTranslation()
  const { acceptInvitation, isLoading } = useAuth()

  const form = useForm<SignUpValues>({
    resolver: zodResolver(signUpSchema),
    defaultValues: { first_name: '', last_name: '', password: '', password_confirmation: '' },
  })
  const { errors } = form.formState

  const onSubmit = async (data: SignUpValues) => {
    try {
      await acceptInvitation(invitationId, token, data)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) {
        const e = err as SpreeError
        form.setError('root', { message: e?.message || t('admin.invitation.could_not_accept') })
      }
      return
    }
    await onAccepted(invitation)
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
          <Label htmlFor="password">{t('admin.fields.password.label')}</Label>
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
            {t('admin.invitation.password_confirmation')}
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

function AcceptAsSignedIn({ invitationId, token, invitation, onAccepted }: FormProps) {
  const { t } = useTranslation()
  const { user, acceptInvitation, logout, isLoading } = useAuth()
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
    await onAccepted(invitation)
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

function SignedInAsAnotherAccount({ invitation }: { invitation: InvitationSummary }) {
  const { t } = useTranslation()
  const { user, logout } = useAuth()

  return (
    <>
      <div className="flex flex-col gap-2">
        <h1 className="text-2xl font-bold">
          {t('admin.invitation.join_store', { store: invitation.target.name })}
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

/** "Join <target>" plus one sentence: who invited, as what, and what to do next. */
function InvitationIntro({
  invitation,
  action,
}: {
  invitation: InvitationSummary
  action: string
}) {
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
        {t('admin.invitation.join_store', { store: invitation.target.name })}
      </h1>
      <p className="text-sm text-muted-foreground">{`${invitedPart}${rolePart}${action}`}</p>
    </div>
  )
}

function Loading() {
  const { t } = useTranslation()
  return (
    <div className="py-12 text-center text-muted-foreground">{t('admin.invitation.loading')}</div>
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

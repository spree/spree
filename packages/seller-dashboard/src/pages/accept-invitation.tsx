import { useAuth } from '@spree/dashboard-core'
import { Button, Field, FieldError, FieldGroup, FieldLabel, Input } from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import { CenteredMessage } from '../components/centered-message'

interface AcceptValues {
  password: string
  password_confirmation: string
  first_name: string
  last_name: string
}

/**
 * Joining a seller's team from the emailed link.
 *
 * The invitation id and token in the URL are the whole credential — nobody is
 * signed in yet. Accepting returns a seller session, so the new member lands
 * in the panel rather than being bounced to a login form.
 */
export function AcceptInvitationPage({
  invitationId,
  token,
}: {
  invitationId: string
  token?: string
}) {
  const { t } = useTranslation()
  const { acceptInvitation } = useAuth()
  const [error, setError] = useState<string | null>(null)

  const {
    data: invitation,
    isLoading,
    error: lookupError,
  } = useQuery({
    queryKey: ['seller', 'invitation', invitationId],
    queryFn: () => sellerClient().auth.lookupInvitation(invitationId, token ?? ''),
    enabled: Boolean(token),
    retry: false,
  })

  const form = useForm<AcceptValues>({
    defaultValues: { password: '', password_confirmation: '', first_name: '', last_name: '' },
  })

  if (!token) return <CenteredMessage>{t('accept_invitation.invalid_link')}</CenteredMessage>
  if (isLoading) return <CenteredMessage>{t('common.loading')}</CenteredMessage>
  if (lookupError || !invitation) {
    return <CenteredMessage>{t('accept_invitation.not_found')}</CenteredMessage>
  }

  async function onSubmit(values: AcceptValues) {
    setError(null)
    try {
      await acceptInvitation(invitationId, token ?? '', values)
      // The index route decides where to go — it already knows how to skip
      // the picker for someone who runs exactly one seller.
    } catch {
      setError(t('accept_invitation.failed'))
    }
  }

  const { errors, isSubmitting } = form.formState

  return (
    <div className="flex min-h-screen items-center justify-center p-6">
      <div className="w-full max-w-sm">
        <h1 className="font-medium text-xl">{t('accept_invitation.title')}</h1>
        <p className="mt-1 mb-6 text-muted-foreground text-sm">
          {t('accept_invitation.subtitle', { email: invitation.email })}
        </p>

        <form onSubmit={form.handleSubmit(onSubmit)}>
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="first_name">{t('accept_invitation.first_name')}</FieldLabel>
              <Input id="first_name" {...form.register('first_name')} />
            </Field>

            <Field>
              <FieldLabel htmlFor="last_name">{t('accept_invitation.last_name')}</FieldLabel>
              <Input id="last_name" {...form.register('last_name')} />
            </Field>

            <Field>
              <FieldLabel htmlFor="password">{t('accept_invitation.password')}</FieldLabel>
              <Input
                id="password"
                type="password"
                aria-invalid={!!errors.password || undefined}
                {...form.register('password', { required: true })}
              />
              <FieldError errors={[errors.password]} />
            </Field>

            <Field>
              <FieldLabel htmlFor="password_confirmation">
                {t('accept_invitation.password_confirmation')}
              </FieldLabel>
              <Input
                id="password_confirmation"
                type="password"
                {...form.register('password_confirmation')}
              />
            </Field>

            {error && <p className="text-destructive text-sm">{error}</p>}

            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? t('accept_invitation.submitting') : t('accept_invitation.submit')}
            </Button>
          </FieldGroup>
        </form>
      </div>
    </div>
  )
}

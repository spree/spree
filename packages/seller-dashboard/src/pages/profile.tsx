import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  StatusBadge,
  Textarea,
} from '@spree/dashboard-ui'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useParams } from '@tanstack/react-router'
import { useEffect } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { sellerClient } from '../api-client'
import { CenteredMessage } from '../components/centered-message'

interface ProfileValues {
  name: string
  contact_email: string
  billing_email: string
  about: string
}

/**
 * The seller's own record.
 *
 * Split by who owns each fact: what the seller maintains is a form, what the
 * marketplace decides is shown read-only. Hiding the latter would leave a
 * seller unable to see they had been suspended, or on what terms they are
 * paid; making it editable would let them approve themselves.
 */
export function ProfilePage() {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })

  const {
    data: profile,
    isLoading,
    error,
  } = useQuery({
    queryKey: ['seller', sellerId, 'profile'],
    queryFn: () => sellerClient().profile.get(),
  })

  const form = useForm<ProfileValues>({
    defaultValues: { name: '', contact_email: '', billing_email: '', about: '' },
  })

  useEffect(() => {
    if (!profile) return

    form.reset({
      name: profile.name,
      contact_email: profile.contact_email ?? '',
      billing_email: profile.billing_email ?? '',
      about: profile.about_html ?? '',
    })
  }, [profile, form])

  const save = useMutation({
    mutationFn: (values: ProfileValues) =>
      sellerClient().profile.update({
        name: values.name,
        contact_email: values.contact_email || null,
        billing_email: values.billing_email || null,
        about: values.about || null,
      }),
    onSuccess: (updated) => {
      queryClient.setQueryData(['seller', sellerId, 'profile'], updated)
      toast.success(t('profile.saved'))
    },
    onError: () => toast.error(t('common.error')),
  })

  if (isLoading) return <CenteredMessage>{t('common.loading')}</CenteredMessage>
  if (error || !profile) return <CenteredMessage>{t('common.error')}</CenteredMessage>

  const { errors, isDirty } = form.formState

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-6">
      <div>
        <h1 className="font-medium text-2xl">{t('profile.title')}</h1>
        <p className="text-muted-foreground text-sm">{t('profile.subtitle')}</p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>{t('profile.section_presentation')}</CardTitle>
        </CardHeader>
        <CardContent>
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="name">{t('profile.name')}</FieldLabel>
              <Input
                id="name"
                aria-invalid={!!errors.name || undefined}
                {...form.register('name', { required: true })}
              />
              <FieldError errors={[errors.name]} />
            </Field>

            <Field>
              <FieldLabel htmlFor="about">{t('profile.about')}</FieldLabel>
              <Textarea id="about" rows={5} {...form.register('about')} />
            </Field>

            <Field>
              <FieldLabel htmlFor="contact_email">{t('profile.contact_email')}</FieldLabel>
              <Input id="contact_email" type="email" {...form.register('contact_email')} />
            </Field>

            <Field>
              <FieldLabel htmlFor="billing_email">{t('profile.billing_email')}</FieldLabel>
              <Input id="billing_email" type="email" {...form.register('billing_email')} />
            </Field>

            <div className="flex justify-end">
              <Button
                type="button"
                disabled={!isDirty || save.isPending}
                onClick={form.handleSubmit((values) => save.mutate(values))}
              >
                {save.isPending ? t('profile.saving') : t('profile.save')}
              </Button>
            </div>
          </FieldGroup>
        </CardContent>
      </Card>

      {/* Read-only: the marketplace decides these, and a seller who cannot see
          them cannot tell why their products stopped selling. */}
      <Card>
        <CardHeader>
          <CardTitle>{t('profile.section_standing')}</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-3">
          <ReadRow label={t('profile.status')}>
            <StatusBadge status={profile.status} />
          </ReadRow>
          <ReadRow label={t('profile.handle')}>/{profile.slug}</ReadRow>
          <ReadRow label={t('profile.products_count')}>{profile.products_count}</ReadRow>
          <ReadRow label={t('profile.sellable')}>
            {profile.sellable ? t('profile.sellable') : t('profile.not_sellable')}
          </ReadRow>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>{t('profile.section_settlement')}</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-3">
          <p className="text-muted-foreground text-xs">{t('profile.operator_managed')}</p>
          <ReadRow label={t('profile.tax_remittance')}>{profile.tax_remittance}</ReadRow>
          <ReadRow label={t('profile.payout_schedule')}>
            {profile.payouts_schedule_interval}
          </ReadRow>
          <ReadRow label={t('profile.minimum_payout')}>{profile.minimum_payout_amount}</ReadRow>
        </CardContent>
      </Card>
    </div>
  )
}

function ReadRow({ label, children }: { label: string; children: React.ReactNode }) {
  const { t } = useTranslation()

  return (
    <div className="flex items-start justify-between gap-3 text-sm">
      <span className="text-muted-foreground">{label}</span>
      <span className="text-right">
        {children ?? <span className="text-muted-foreground">{t('profile.not_provided')}</span>}
      </span>
    </div>
  )
}

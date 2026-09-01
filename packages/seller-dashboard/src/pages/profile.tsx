import { PageHeader } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RelativeTime,
  ResourceLayout,
  Sheet,
  SheetContent,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  StatusBadge,
  Textarea,
  toastManager,
} from '@spree/dashboard-ui'
import { PackageIcon, PencilIcon, StoreIcon, UsersIcon } from '@spree/dashboard-ui/icons'
import type { Profile } from '@spree/seller-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useParams } from '@tanstack/react-router'
import type { ReactNode } from 'react'
import { useEffect, useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import { CenteredMessage } from '../components/centered-message'
import { SellerAddressCard } from '../components/seller-address-card'
import { SellerBusinessCard } from '../components/seller-business-card'
import { SellerReturnsLocationCard } from '../components/seller-returns-location-card'
import { SellerTaxIdentifiersCard } from '../components/seller-tax-identifiers-card'

interface ProfileValues {
  name: string
  contact_email: string
  billing_email: string
  about: string
}

/**
 * The seller's own record, laid out as the operator sees it on their seller
 * page — brand hero, standing, contact — so the two views of one seller
 * describe the same thing in the same shape.
 *
 * What the operator's page has that this deliberately does not: the lifecycle
 * actions (approve, suspend, reject, delete), the settlement *editor*, and the
 * invite sheet. Those are the marketplace's decisions about this seller, not
 * the seller's own. Settlement terms are still shown, read-only: a seller who
 * cannot see how they are paid cannot query it.
 */
export function ProfilePage() {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const [editing, setEditing] = useState(false)

  const {
    data: profile,
    isLoading,
    error,
  } = useQuery({
    queryKey: ['seller', sellerId, 'profile'],
    queryFn: () => sellerClient().profile.get(),
  })

  // Only for the team count in "at a glance" — the profile payload does not
  // carry one, and a second small read beats widening the serializer for a
  // number the team page already fetches.
  const { data: team } = useQuery({
    queryKey: ['seller', sellerId, 'team'],
    queryFn: () => sellerClient().team.list(),
  })

  if (isLoading) return <CenteredMessage>{t('common.loading')}</CenteredMessage>
  if (error || !profile) return <CenteredMessage>{t('common.error')}</CenteredMessage>

  return (
    <>
      <ResourceLayout
        header={<PageHeader title={profile.name} subtitle={t('profile.subtitle')} />}
        main={<BrandCard profile={profile} onEdit={() => setEditing(true)} />}
        sidebar={
          <>
            <StandingCard profile={profile} />
            <AtAGlanceCard profile={profile} teamCount={team?.data?.length} />
            <ContactCard profile={profile} onEdit={() => setEditing(true)} />
            <SellerBusinessCard profile={profile} />
            <SellerTaxIdentifiersCard />
            <SellerAddressCard profile={profile} />
            <SellerReturnsLocationCard />
            <SettlementCard profile={profile} />
          </>
        }
      />

      <EditProfileSheet profile={profile} open={editing} onOpenChange={setEditing} />
    </>
  )
}

/**
 * The storefront face of the seller: cover, logo, handle and description.
 *
 * Copied from the operator's card, including why the empty states look as
 * they do — a seller with no cover gets a slim band rather than a tall empty
 * block, and the logo tile straddles it with its own z-index so the band's
 * edge does not cut across it.
 */
function BrandCard({ profile, onEdit }: { profile: Profile; onEdit: () => void }) {
  const { t } = useTranslation()

  return (
    <Card className="overflow-hidden">
      <div className="relative">
        {profile.cover_photo_url ? (
          <img
            src={profile.cover_photo_url}
            alt=""
            className="h-40 w-full bg-accent object-cover"
          />
        ) : (
          <div className="h-20 w-full border-border border-b bg-muted" />
        )}
        <Button size="sm" variant="outline" className="absolute top-3 right-3" onClick={onEdit}>
          <PencilIcon className="size-4" />
          {t('profile.edit')}
        </Button>
      </div>

      <CardContent className="flex flex-col gap-4 px-5 pb-5">
        <div className="-mt-10 relative z-10 flex size-20 items-center justify-center overflow-hidden rounded-xl border border-border bg-card shadow-sm">
          {/* The square logo is the one cropped for a tile like this; the main
              logo is the fallback, since a seller may have set only one. */}
          {profile.square_logo_url || profile.logo_url ? (
            <img
              src={profile.square_logo_url ?? profile.logo_url ?? undefined}
              alt=""
              className="size-full object-cover"
            />
          ) : (
            <StoreIcon className="size-7 text-muted-foreground" />
          )}
        </div>

        {/* The name is already the page title; the handle is what it lacks. */}
        <p className="text-muted-foreground text-sm">/{profile.slug}</p>

        {profile.about_html ? (
          // Server-sanitized on every write path (Spree::RichTextSanitizer),
          // which is what makes rendering it here safe.
          <div
            className="prose prose-sm dark:prose-invert max-w-none"
            // biome-ignore lint/security/noDangerouslySetInnerHtml: sanitized server-side
            dangerouslySetInnerHTML={{ __html: profile.about_html }}
          />
        ) : (
          <p className="text-muted-foreground text-sm">{t('profile.no_about')}</p>
        )}
      </CardContent>
    </Card>
  )
}

/** Where the seller stands with the marketplace, and what that means. */
function StandingCard({ profile }: { profile: Profile }) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('profile.section_standing')}</CardTitle>
        <CardAction>
          <StatusBadge status={profile.status} />
        </CardAction>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        <p className="text-muted-foreground text-sm">
          {t(`profile.status_help.${profile.status}`, {
            defaultValue: t('profile.status_help.pending'),
          })}
        </p>
        {profile.on_holiday && (
          <p className="text-muted-foreground text-sm">{t('profile.on_holiday_notice')}</p>
        )}
      </CardContent>
    </Card>
  )
}

function AtAGlanceCard({ profile, teamCount }: { profile: Profile; teamCount?: number }) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('profile.at_a_glance')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <div className="flex items-center justify-between text-sm">
          <span className="flex items-center gap-2 text-muted-foreground">
            <PackageIcon className="size-4" />
            {t('profile.products_count')}
          </span>
          <span>{profile.products_count}</span>
        </div>
        <div className="flex items-center justify-between text-sm">
          <span className="flex items-center gap-2 text-muted-foreground">
            <UsersIcon className="size-4" />
            {t('profile.team_count')}
          </span>
          <span>{teamCount ?? '—'}</span>
        </div>
        <ReadRow label={t('profile.joined')}>
          <RelativeTime iso={profile.created_at} />
        </ReadRow>
      </CardContent>
    </Card>
  )
}

function ContactCard({ profile, onEdit }: { profile: Profile; onEdit: () => void }) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('profile.section_contact')}</CardTitle>
        <CardAction>
          <Button variant="outline" size="sm" onClick={onEdit}>
            <PencilIcon className="size-4" />
            {t('profile.edit')}
          </Button>
        </CardAction>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <ReadRow label={t('profile.contact_email')}>
          {profile.contact_email ? (
            <a href={`mailto:${profile.contact_email}`}>{profile.contact_email}</a>
          ) : null}
        </ReadRow>
        <ReadRow label={t('profile.billing_email')}>
          {profile.billing_email ? (
            <a href={`mailto:${profile.billing_email}`}>{profile.billing_email}</a>
          ) : null}
        </ReadRow>
      </CardContent>
    </Card>
  )
}

/**
 * How and when this seller gets paid. Read-only on purpose: these are the
 * marketplace's terms, and the seller API refuses to write them — showing an
 * editor here would offer a control the server would reject.
 */
function SettlementCard({ profile }: { profile: Profile }) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('profile.section_settlement')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <p className="text-muted-foreground text-xs">{t('profile.operator_managed')}</p>
        <ReadRow label={t('profile.tax_remittance')}>{profile.tax_remittance}</ReadRow>
        <ReadRow label={t('profile.payout_schedule')}>{profile.payouts_schedule_interval}</ReadRow>
        <ReadRow label={t('profile.minimum_payout')}>{profile.minimum_payout_amount}</ReadRow>
      </CardContent>
    </Card>
  )
}

function EditProfileSheet({
  profile,
  open,
  onOpenChange,
}: {
  profile: Profile
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const queryClient = useQueryClient()

  const form = useForm<ProfileValues>({
    defaultValues: { name: '', contact_email: '', billing_email: '', about: '' },
  })

  // The sheet stays mounted across opens, so re-seed from the latest record
  // each time it opens rather than only on first mount.
  useEffect(() => {
    if (!open) return

    form.reset({
      name: profile.name,
      contact_email: profile.contact_email ?? '',
      billing_email: profile.billing_email ?? '',
      about: profile.about_html ?? '',
    })
  }, [open, profile, form])

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
      onOpenChange(false)
      toastManager.add({ type: 'success', title: t('profile.saved') })
    },
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
  })

  const { errors } = form.formState

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('profile.edit_title')}</SheetTitle>
        </SheetHeader>

        {/* `stopPropagation` after handleSubmit: this form is portalled and
            a parent form would otherwise see the bubbling submit. */}
        <form
          onSubmit={(event) => {
            form.handleSubmit((values) => save.mutate(values))(event)
            event.stopPropagation()
          }}
          className="flex min-h-0 flex-1 flex-col"
        >
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
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
                <Textarea id="about" rows={6} {...form.register('about')} />
              </Field>

              <Field>
                <FieldLabel htmlFor="contact_email">{t('profile.contact_email')}</FieldLabel>
                <Input id="contact_email" type="email" {...form.register('contact_email')} />
              </Field>

              <Field>
                <FieldLabel htmlFor="billing_email">{t('profile.billing_email')}</FieldLabel>
                <Input id="billing_email" type="email" {...form.register('billing_email')} />
              </Field>
            </FieldGroup>
          </div>

          <SheetFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={save.isPending}>
              {save.isPending ? t('profile.saving') : t('profile.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function ReadRow({ label, children }: { label: string; children: ReactNode }) {
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

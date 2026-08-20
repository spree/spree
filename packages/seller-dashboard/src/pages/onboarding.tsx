import {
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Progress,
  Textarea,
} from '@spree/dashboard-ui'
import type { RequirementStatus } from '@spree/seller-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, useParams } from '@tanstack/react-router'
import {
  CheckCircle2Icon,
  ChevronRightIcon,
  CircleIcon,
  ClockIcon,
  ExternalLinkIcon,
  XCircleIcon,
} from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { sellerClient } from '../api-client'
import { CenteredMessage } from '../components/centered-message'
import { SellerAddressCard, type SellerAddressKey } from '../components/seller-address-card'

/**
 * What the marketplace asks of this seller before admitting them.
 *
 * Deliberately one page rather than a wizard: the checklist is not ordered by
 * dependency, a seller can do these in any order, and several are things they
 * have to go away and come back for (a document to find, an account to open).
 * A wizard would trap them at step two.
 *
 * Every line and the progress bar render from `GET /seller/onboarding` and
 * nothing else — the same evaluator the operator reads, so the two can never
 * disagree about what is outstanding.
 */
export function OnboardingPage() {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const queryClient = useQueryClient()

  const { data, isLoading, error } = useQuery({
    queryKey: ['seller', sellerId, 'onboarding'],
    queryFn: () => sellerClient().onboarding.get(),
  })

  const submit = useMutation({
    mutationFn: () => sellerClient().onboarding.submitForReview(),
    onSuccess: (next) => {
      queryClient.setQueryData(['seller', sellerId, 'onboarding'], next)
      toast.success(t('onboarding.submitted'))
    },
    // The server names what is outstanding; showing our own wording instead
    // would tell the seller less than the API already knows.
    onError: (err) => toast.error(err instanceof Error ? err.message : t('common.error')),
  })

  if (isLoading) return <CenteredMessage>{t('common.loading')}</CenteredMessage>
  if (error || !data) return <CenteredMessage>{t('common.error')}</CenteredMessage>

  const { progress, requirements, status } = data
  const blocking = requirements.filter((requirement) => requirement.blocking)
  const submitted = status === 'ready_for_review'

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="font-medium text-2xl">{t('onboarding.title')}</h1>
        <p className="text-muted-foreground text-sm">{t('onboarding.subtitle')}</p>
      </div>

      <Card>
        <CardHeader className="flex-row items-center justify-between gap-4">
          <CardTitle>{t('onboarding.progress_title')}</CardTitle>
          <Badge variant={progress.percentage === 100 ? 'success' : 'secondary'}>
            {t('onboarding.progress_count', { done: progress.done, total: progress.total })}
          </Badge>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          <Progress value={progress.percentage} />

          {submitted ? (
            <p className="text-muted-foreground text-sm">{t('onboarding.under_review')}</p>
          ) : (
            <div className="flex items-center justify-between gap-4">
              <p className="text-muted-foreground text-sm">
                {blocking.length === 0
                  ? t('onboarding.ready')
                  : t('onboarding.remaining', { count: blocking.length })}
              </p>
              <Button
                size="sm"
                disabled={blocking.length > 0 || submit.isPending}
                onClick={() => submit.mutate()}
              >
                {submit.isPending ? t('onboarding.submitting') : t('onboarding.submit')}
              </Button>
            </div>
          )}
        </CardContent>
      </Card>

      {requirements.length > 0 && (
        <div className="flex flex-col gap-3">
          {requirements.map((requirement) => (
            <RequirementCard
              key={requirement.id}
              requirement={requirement}
              // Open the first outstanding line and collapse the rest: it
              // answers "what do I do next" without the seller hunting for it.
              defaultOpen={requirement.id === firstOutstanding(requirements)?.id}
            />
          ))}
        </div>
      )}
    </div>
  )
}

function firstOutstanding(requirements: RequirementStatus[]): RequirementStatus | undefined {
  return requirements.find((requirement) => requirement.status !== 'complete')
}

function RequirementCard({
  requirement,
  defaultOpen,
}: {
  requirement: RequirementStatus
  defaultOpen: boolean
}) {
  const { t } = useTranslation()
  const [open, setOpen] = useState(defaultOpen)

  return (
    <Card className="overflow-hidden">
      <button
        type="button"
        onClick={() => setOpen((previous) => !previous)}
        className="flex w-full cursor-pointer items-center gap-3 p-4 text-left hover:bg-muted/50"
      >
        <StatusIcon status={requirement.status} />
        <div className="flex min-w-0 flex-col">
          <span className="font-medium text-sm">{requirement.name}</span>
          {!requirement.required && (
            <span className="text-muted-foreground text-xs">{t('onboarding.optional')}</span>
          )}
        </div>
        <StatusBadge status={requirement.status} />
        <ChevronRightIcon
          className={`ml-auto size-4 shrink-0 text-muted-foreground transition-transform ${
            open ? 'rotate-90' : ''
          }`}
        />
      </button>

      {open && (
        <CardContent className="flex flex-col gap-3 border-t pt-4">
          {requirement.description && (
            <p className="text-muted-foreground text-sm">{requirement.description}</p>
          )}
          <RequirementAction requirement={requirement} />
        </CardContent>
      )}
    </Card>
  )
}

/**
 * What the seller does about one line, keyed off `kind`.
 *
 * The server decides which kinds exist and what each means; this only decides
 * how to ask. An unrecognised kind — one a provider gem added — still renders
 * its name, description and any `action_url`, so a new kind is useful here
 * before this file knows about it.
 */
function RequirementAction({ requirement }: { requirement: RequirementStatus }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const queryClient = useQueryClient()
  const [note, setNote] = useState('')

  // Only the address kinds need it, and it is already loaded by the profile
  // page and the sidebar switcher — this reads the same cache entry.
  const { data: profile } = useQuery({
    queryKey: ['seller', sellerId, 'profile'],
    queryFn: () => sellerClient().profile.get(),
    enabled: Boolean(addressKeyFor(requirement.kind)),
  })

  const invalidate = () =>
    queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'onboarding'] })

  const acceptTerms = useMutation({
    mutationFn: () => sellerClient().profile.update({ accept_terms: true }),
    onSuccess: () => {
      toast.success(t('onboarding.terms_accepted'))
      void invalidate()
    },
    onError: (err) => toast.error(err instanceof Error ? err.message : t('common.error')),
  })

  const attest = useMutation({
    mutationFn: () =>
      sellerClient().requirementSubmissions.create(requirement.id, { note: note || undefined }),
    onSuccess: () => {
      setNote('')
      toast.success(t('onboarding.submitted_requirement'))
      void invalidate()
    },
    onError: (err) => toast.error(err instanceof Error ? err.message : t('common.error')),
  })

  const submission = requirement.submission

  // A rejection the seller cannot read is a rejection they cannot act on.
  const rejection = submission?.status === 'rejected' && submission.review_note && (
    <p className="rounded-md bg-destructive/10 p-3 text-destructive text-sm">
      {submission.review_note}
    </p>
  )

  if (requirement.status === 'complete') {
    return (
      <>
        {rejection}
        <p className="text-muted-foreground text-sm">{t('onboarding.done')}</p>
      </>
    )
  }

  if (requirement.status === 'pending') {
    return (
      <>
        {rejection}
        <p className="text-muted-foreground text-sm">{t('onboarding.awaiting_review')}</p>
      </>
    )
  }

  return (
    <>
      {rejection}

      {requirement.kind === 'accept_terms' && (
        <div className="flex flex-wrap items-center gap-2">
          {/* The terms themselves, when the marketplace configured a link.
              Accepting something a seller cannot read is not consent. */}
          {requirement.action_url && (
            <Button size="sm" variant="outline" asChild>
              <a href={requirement.action_url} target="_blank" rel="noreferrer">
                {t('onboarding.read_terms')}
                <ExternalLinkIcon className="size-4" />
              </a>
            </Button>
          )}
          <Button size="sm" disabled={acceptTerms.isPending} onClick={() => acceptTerms.mutate()}>
            {t('onboarding.accept_terms')}
          </Button>
        </div>
      )}

      {requirement.kind === 'attestation' && (
        <div className="flex flex-col gap-2">
          <Textarea
            rows={2}
            value={note}
            placeholder={t('onboarding.note_placeholder')}
            onChange={(event) => setNote(event.target.value)}
          />
          <div className="flex justify-start">
            <Button size="sm" disabled={attest.isPending} onClick={() => attest.mutate()}>
              {t('onboarding.confirm')}
            </Button>
          </div>
        </div>
      )}

      {/* Addresses are filled in here rather than on the profile page: a
          seller working through setup should not be sent away and lose their
          place. Same card either way, so the two cannot diverge. */}
      {addressKeyFor(requirement.kind) && profile && (
        <SellerAddressCard
          profile={profile}
          addressKey={addressKeyFor(requirement.kind)!}
          headless
        />
      )}

      {/* Kinds whose work happens on a page this panel already has. The
          server cannot supply these: `action_url` is for somewhere it knows
          about (a provider's hosted flow), and it has no idea how this panel
          routes. Anything unmapped falls through to `action_url` below, so a
          kind added by a gem still gets a way in without this file changing. */}
      {panelRoute(requirement.kind) && (
        <div className="flex justify-start">
          <Button size="sm" asChild>
            <Link to={panelRoute(requirement.kind)!} params={{ sellerId }}>
              {t('onboarding.go')}
              <ChevronRightIcon className="size-4" />
            </Link>
          </Button>
        </div>
      )}

      {/* `accept_terms` renders its own link above, with different words. */}
      {requirement.action_url && requirement.kind !== 'accept_terms' && (
        <div className="flex justify-start">
          <Button size="sm" variant="outline" asChild>
            <a href={requirement.action_url} target="_blank" rel="noreferrer">
              {t('onboarding.go')}
              <ExternalLinkIcon className="size-4" />
            </a>
          </Button>
        </div>
      )}
    </>
  )
}

/**
 * Where in this panel a seller goes to satisfy a kind.
 *
 * Deliberately a short map rather than a per-kind component: these lines say
 * "go and fill that in", and the page that owns the form already exists. A
 * kind that is not here renders its description and any `action_url`, which
 * is what makes a provider's kind useful before this file knows it exists.
 */
/** Kinds the seller satisfies by filling an address, rendered inline. */
function addressKeyFor(kind: string): SellerAddressKey | undefined {
  if (kind === 'billing_address' || kind === 'returns_address') return kind
  return undefined
}

function panelRoute(kind: string): string | undefined {
  switch (kind) {
    case 'complete_profile':
    case 'required_custom_fields':
      return '/$sellerId/profile'
    // `minimum_products` belongs here too, once the panel has a products
    // page — until then it falls through and reads as a plain instruction
    // rather than a link to nowhere.
    default:
      return undefined
  }
}

function StatusIcon({ status }: { status: string }) {
  if (status === 'complete') {
    return <CheckCircle2Icon className="size-4 shrink-0 text-green-600" />
  }
  if (status === 'pending') {
    return <ClockIcon className="size-4 shrink-0 text-amber-600" />
  }
  if (status === 'rejected') {
    return <XCircleIcon className="size-4 shrink-0 text-destructive" />
  }
  return <CircleIcon className="size-4 shrink-0 text-muted-foreground" />
}

function StatusBadge({ status }: { status: string }) {
  const { t } = useTranslation()

  if (status === 'complete')
    return <Badge variant="success">{t('onboarding.status.complete')}</Badge>
  if (status === 'pending') return <Badge variant="warning">{t('onboarding.status.pending')}</Badge>
  if (status === 'rejected')
    return <Badge variant="destructive">{t('onboarding.status.rejected')}</Badge>
  return null
}

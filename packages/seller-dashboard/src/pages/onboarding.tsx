import {
  EMPTY_FILE_UPLOAD_VALUE,
  FileUploadField,
  type FileUploadValue,
  progressPercentage,
} from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldLabel,
  Input,
  Progress,
  Textarea,
  toastManager,
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
import { sellerClient } from '../api-client'
import { CenteredMessage } from '../components/centered-message'
import { SellerAddressCard } from '../components/seller-address-card'
import { SellerReturnsLocationCard } from '../components/seller-returns-location-card'

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
      toastManager.add({ type: 'success', title: t('onboarding.submitted') })
    },
    // The server names what is outstanding; showing our own wording instead
    // would tell the seller less than the API already knows.
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
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
          <Badge variant={progress.done >= progress.total ? 'success' : 'secondary'}>
            {t('onboarding.progress_count', { done: progress.done, total: progress.total })}
          </Badge>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          <Progress value={progressPercentage(progress)} />

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
  const [file, setFile] = useState<FileUploadValue>(EMPTY_FILE_UPLOAD_VALUE)
  const [fields, setFields] = useState<Record<string, string>>({})

  // Only the address kinds need it, and it is already loaded by the profile
  // page and the sidebar switcher — this reads the same cache entry.
  const { data: profile } = useQuery({
    queryKey: ['seller', sellerId, 'profile'],
    queryFn: () => sellerClient().profile.get(),
    enabled: isAddressKind(requirement.kind),
  })

  const invalidate = () =>
    queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'onboarding'] })

  const acceptTerms = useMutation({
    mutationFn: () => sellerClient().profile.update({ accept_terms: true }),
    onSuccess: () => {
      toastManager.add({ type: 'success', title: t('onboarding.terms_accepted') })
      void invalidate()
    },
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
  })

  // Asked for at the moment the seller clicks, never earlier: a provider's
  // hosted link is short-lived and single-use, so one fetched while drawing
  // this page would often be dead by the time it was used. The seller comes
  // back here — this page is where the checklist says what is outstanding.
  const connectPayoutAccount = useMutation({
    mutationFn: () => {
      const here = window.location.href.split('?')[0]

      return sellerClient().onboarding.payoutAccount({
        refresh_url: here,
        return_url: here,
      })
    },
    onSuccess: ({ url }) => {
      if (url) window.location.href = url
    },
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
  })

  // One submit for every kind that takes one — an attestation the seller
  // ticks, a document they upload, a manual check they say is ready. What
  // differs is which controls render above it, not what posting means.
  const submit = useMutation({
    mutationFn: () =>
      sellerClient().requirementSubmissions.create(requirement.id, {
        note: note || undefined,
        file: file.signedId || undefined,
      }),
    onSuccess: () => {
      setNote('')
      setFile(EMPTY_FILE_UPLOAD_VALUE)
      toastManager.add({ type: 'success', title: t('onboarding.submitted_requirement') })
      void invalidate()
    },
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
  })

  // Custom fields are the seller's own profile data, so they save through the
  // profile like the addresses do rather than as a submission.
  const saveFields = useMutation({
    mutationFn: () =>
      sellerClient().profile.update({
        custom_fields: Object.entries(fields).map(([id, value]) => ({
          custom_field_definition_id: id,
          value,
        })),
      }),
    onSuccess: () => {
      toastManager.add({ type: 'success', title: t('profile.saved') })
      void invalidate()
    },
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
  })

  const submission = requirement.submission

  // A rejection the seller cannot read is a rejection they cannot act on.
  const rejection = submission?.status === 'rejected' && submission.review_note && (
    <p className="rounded-md bg-destructive/10 p-3 text-destructive text-sm">
      {submission.review_note}
    </p>
  )

  // Nothing to do on a finished line. The header already carries the tick and
  // the Done badge, so a sentence saying the same thing a third time is noise.
  if (requirement.status === 'complete') {
    return rejection
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
            <Button variant="outline" asChild>
              <a href={requirement.action_url} target="_blank" rel="noreferrer">
                {t('onboarding.read_terms')}
                <ExternalLinkIcon className="size-4" />
              </a>
            </Button>
          )}
          <Button disabled={acceptTerms.isPending} onClick={() => acceptTerms.mutate()}>
            {t('onboarding.accept_terms')}
          </Button>
        </div>
      )}

      {/* Every kind that takes a submission gets the same form: a note, a
          file picker when the kind asks for one, and one button. Keyed off
          what the server says the kind accepts rather than off its name, so a
          kind a gem adds is usable without this file knowing about it. */}
      {requirement.accepts_submissions && requirement.kind !== 'accept_terms' && (
        <div className="flex flex-col gap-3">
          {requirement.requires_file && (
            <FileUploadField
              value={file}
              onChange={setFile}
              accept={requirement.accepted_content_types?.join(',')}
              label={t('onboarding.document_label')}
              help={t('onboarding.document_help')}
            />
          )}

          <Textarea
            rows={2}
            value={note}
            placeholder={t('onboarding.note_placeholder')}
            onChange={(event) => setNote(event.target.value)}
          />

          <div className="flex justify-start">
            <Button
              // A document requirement with nothing attached is an empty
              // submission the operator can only reject.
              disabled={submit.isPending || (requirement.requires_file && !file.signedId)}
              onClick={() => submit.mutate()}
            >
              {requirement.requires_file
                ? t('onboarding.submit_document')
                : t('onboarding.confirm')}
            </Button>
          </div>
        </div>
      )}

      {/* The fields the marketplace asks this seller to fill in, rendered
          here rather than behind a link: the checklist is where they were
          asked, so it is where they answer. */}
      {requirement.custom_fields && requirement.custom_fields.length > 0 && (
        <div className="flex flex-col gap-3">
          {requirement.custom_fields.map((field) => (
            <Field key={field.id}>
              <FieldLabel htmlFor={`cf-${field.id}`}>{field.label}</FieldLabel>
              <Input
                id={`cf-${field.id}`}
                value={fields[field.id] ?? (field.value == null ? '' : String(field.value))}
                onChange={(event) =>
                  setFields((current) => ({ ...current, [field.id]: event.target.value }))
                }
              />
            </Field>
          ))}
          <div className="flex justify-start">
            <Button
              disabled={saveFields.isPending || Object.keys(fields).length === 0}
              onClick={() => saveFields.mutate()}
            >
              {t('common.save')}
            </Button>
          </div>
        </div>
      )}

      {/* Addresses are filled in here rather than on the profile page: a
          seller working through setup should not be sent away and lose their
          place. Same card either way, so the two cannot diverge. */}
      {requirement.kind === 'billing_address' && profile && (
        <SellerAddressCard profile={profile} headless />
      )}

      {/* Returns go to a stock location rather than a loose address, so this
          one writes a different record — the seller still just sees an
          address form. */}
      {requirement.kind === 'returns_address' && <SellerReturnsLocationCard headless />}

      {/* The provider hosts the form, so this is a redirect rather than a
          page: the seller gives their bank and identity details to whoever
          is paying them, and the marketplace never handles either.

          Three outcomes, three different things to say. Waiting on the
          provider gets no button at all — offering one would invite the
          seller round a flow that cannot move, and they would click it
          repeatedly wondering why nothing changed. */}
      {requirement.kind === 'payout_account' && (
        <div className="flex flex-col items-start gap-2">
          {requirement.blocker?.message && (
            <p className="text-muted-foreground text-sm">{requirement.blocker.message}</p>
          )}

          {requirement.blocker?.state === 'pending' ? (
            <p className="text-muted-foreground text-sm">
              {t('onboarding.awaiting_payout_provider')}
            </p>
          ) : (
            <Button
              disabled={connectPayoutAccount.isPending}
              onClick={() => connectPayoutAccount.mutate()}
            >
              {requirement.blocker?.state === 'rejected'
                ? t('onboarding.payout_account_rejected')
                : t('onboarding.connect_payout_account')}
              <ExternalLinkIcon className="size-4" />
            </Button>
          )}
        </div>
      )}

      {/* Kinds whose work happens on a page this panel already has. The
          server cannot supply these: `action_url` is for somewhere it knows
          about (a provider's hosted flow), and it has no idea how this panel
          routes. Anything unmapped falls through to `action_url` below, so a
          kind added by a gem still gets a way in without this file changing. */}
      {panelRoute(requirement.kind) && (
        <div className="flex justify-start">
          <Button asChild>
            <Link to={panelRoute(requirement.kind)!} params={{ sellerId }}>
              {t('onboarding.go')}
              <ChevronRightIcon className="size-4" />
            </Link>
          </Button>
        </div>
      )}

      {/* Which documents are still owed. The generic link below says where to
          go; without this the seller would arrive not knowing what to write. */}
      {/* `accept_terms` renders its own link above, with different words. */}
      {requirement.action_url &&
        requirement.kind !== 'accept_terms' &&
        requirement.kind !== 'payout_account' && (
          <div className="flex justify-start">
            <Button variant="outline" asChild>
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

/** Kinds the seller satisfies by filling an address, rendered inline. */
function isAddressKind(kind: string): boolean {
  return kind === 'billing_address' || kind === 'returns_address'
}

/**
 * Where in this panel a seller goes to satisfy a kind.
 *
 * Deliberately a short map rather than a per-kind component: these lines say
 * "go and fill that in", and the page that owns the form already exists. A
 * kind that is not here renders its description and any `action_url`, which
 * is what makes a provider's kind useful before this file knows it exists.
 */
function panelRoute(kind: string): string | undefined {
  switch (kind) {
    case 'complete_profile':
      return '/$sellerId/profile'
    case 'policy':
      return '/$sellerId/settings/policies'
    // `required_custom_fields` is not here: it renders its own fields inline,
    // so a link away would offer a second, worse route to the same thing.
    //
    // `minimum_products` belongs here once the panel has a products page —
    // until then it falls through and reads as a plain instruction rather
    // than a link to nowhere.
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

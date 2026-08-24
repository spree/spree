import type { Seller, SellerRequirementStatus } from '@spree/admin-sdk'
import { progressPercentage } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardTitle,
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  Progress,
  useConfirm,
} from '@spree/dashboard-ui'
import {
  CheckCircle2Icon,
  ChevronDownIcon,
  CircleIcon,
  ClockIcon,
  DownloadIcon,
  EllipsisVerticalIcon,
  XCircleIcon,
} from 'lucide-react'
import { useTranslation } from 'react-i18next'
import {
  useAcceptSellerRequirementSubmission,
  useRejectSellerRequirementSubmission,
  useSellerOnboarding,
  useWaiveSellerRequirement,
} from '../../../hooks/use-seller-requirements'

/**
 * Where one seller stands against the marketplace's checklist, and the
 * operator's decisions on anything they submitted.
 *
 * The header reads the progress off the seller itself, so it renders with
 * the page and matches the list's column; the requirement rows come from
 * the heavier onboarding endpoint once the card is on screen. Everything is
 * evaluated server-side — the card never re-derives whether something is
 * done, so what the operator reads is exactly what the approval gate uses.
 */
export function SellerOnboardingCard({ seller, canEdit }: { seller: Seller; canEdit: boolean }) {
  const { t } = useTranslation()
  const { data } = useSellerOnboarding(seller.id)
  const progress = seller.onboarding_progress

  // A marketplace that asks for nothing has no checklist worth a card.
  if (progress.total === 0) return null

  return (
    <Card className="overflow-hidden py-0">
      {/* Open while there is something left to do; a finished checklist
          folds away so the page leads with what still needs the operator. */}
      <Collapsible defaultOpen={!seller.onboarding_complete}>
        <CollapsibleTrigger className="group flex w-full cursor-pointer items-center gap-3 p-4 text-left hover:bg-muted/50 border-border-subtle">
          <CardTitle>{t('admin.sellers.onboarding.title')}</CardTitle>
          {seller.onboarding_complete ? (
            <Badge variant="success">{t('admin.sellers.onboarding.all_done')}</Badge>
          ) : (
            <Badge variant="secondary">
              {t('admin.sellers.onboarding.progress', {
                done: progress.done,
                total: progress.total,
              })}
            </Badge>
          )}
          <ChevronDownIcon className="ml-auto size-4 shrink-0 text-muted-foreground transition-transform group-data-[panel-open]:rotate-180" />
        </CollapsibleTrigger>

        <CollapsibleContent>
          <div className="flex flex-col gap-4 border-t p-4">
            <Progress value={progressPercentage(progress)} />

            {data ? (
              <ul className="flex flex-col divide-y">
                {data.requirements.map((requirement) => (
                  <RequirementRow
                    key={requirement.id}
                    sellerId={seller.id}
                    requirement={requirement}
                    canEdit={canEdit}
                  />
                ))}
              </ul>
            ) : (
              <p className="text-muted-foreground text-sm">{t('admin.common.loading')}</p>
            )}
          </div>
        </CollapsibleContent>
      </Collapsible>
    </Card>
  )
}

function RequirementRow({
  sellerId,
  requirement,
  canEdit,
}: {
  sellerId: string
  requirement: SellerRequirementStatus
  canEdit: boolean
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const acceptMutation = useAcceptSellerRequirementSubmission(sellerId)
  const rejectMutation = useRejectSellerRequirementSubmission(sellerId)
  const waiveMutation = useWaiveSellerRequirement(sellerId)

  const submission = requirement.submission
  const busy = acceptMutation.isPending || rejectMutation.isPending || waiveMutation.isPending

  async function handleReject() {
    if (!submission) return

    const ok = await confirm({
      title: t('admin.sellers.onboarding.reject_confirm.title'),
      message: t('admin.sellers.onboarding.reject_confirm.message', { name: requirement.name }),
      variant: 'destructive',
      confirmLabel: t('admin.sellers.onboarding.actions.reject'),
    })
    if (!ok) return

    await rejectMutation.mutateAsync({ id: submission.id }).catch(() => undefined)
  }

  async function handleWaive() {
    const ok = await confirm({
      title: t('admin.sellers.onboarding.waive_confirm.title'),
      message: t('admin.sellers.onboarding.waive_confirm.message', { name: requirement.name }),
      confirmLabel: t('admin.sellers.onboarding.actions.waive'),
    })
    if (!ok) return

    await waiveMutation.mutateAsync({ requirement_id: requirement.id }).catch(() => undefined)
  }

  return (
    <li className="flex items-start justify-between gap-3 py-3 first:pt-0 last:pb-0">
      <div className="flex min-w-0 items-start gap-2">
        <StatusIcon status={requirement.status} />
        <div className="flex min-w-0 flex-col gap-0.5">
          <div className="flex flex-wrap items-center gap-2">
            <span className="font-medium text-sm">{requirement.name}</span>
            {!requirement.required && (
              <Badge variant="outline">{t('admin.seller_requirements.required.no')}</Badge>
            )}
          </div>
          {requirement.description && (
            <span className="text-muted-foreground text-xs">{requirement.description}</span>
          )}
          {submission?.note && (
            <span className="text-muted-foreground text-xs">
              {t('admin.sellers.onboarding.seller_note', { note: submission.note })}
            </span>
          )}
          {submission?.review_note && (
            <span className="text-muted-foreground text-xs">
              {t('admin.sellers.onboarding.review_note', { note: submission.review_note })}
            </span>
          )}
          {submission?.file_url && (
            <a
              href={submission.file_url}
              className="flex items-center gap-1 text-primary text-xs hover:underline"
            >
              <DownloadIcon className="size-3" />
              {submission.file_name ?? t('admin.sellers.onboarding.download')}
            </a>
          )}
        </div>
      </div>

      <div className="flex shrink-0 items-center gap-2">
        <StatusBadge status={requirement.status} waived={submission?.status === 'waived'} />

        {canEdit && submission?.status === 'pending' && (
          <>
            <Button
              size="sm"
              variant="outline"
              disabled={busy}
              onClick={() =>
                acceptMutation.mutateAsync({ id: submission.id }).catch(() => undefined)
              }
            >
              {t('admin.sellers.onboarding.actions.accept')}
            </Button>
            <Button size="sm" variant="ghost" disabled={busy} onClick={handleReject}>
              {t('admin.sellers.onboarding.actions.reject')}
            </Button>
          </>
        )}

        {canEdit && requirement.status !== 'complete' && (
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button size="icon-sm" variant="ghost" disabled={busy}>
                <EllipsisVerticalIcon className="size-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem onClick={handleWaive}>
                {t('admin.sellers.onboarding.actions.waive')}
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        )}
      </div>
    </li>
  )
}

/**
 * The legacy checklist showed Done / Pending; the four statuses here add
 * the two cases an operator has to act on differently — something waiting
 * on them, and something they sent back.
 *
 * A waiver is read from the status like everything else, and only changes
 * the wording — it is done, by the operator's decision rather than the
 * seller's doing. Deciding "waived" ahead of the status is what previously
 * let this badge disagree with the tick beside it.
 */
function StatusBadge({ status, waived }: { status: string; waived: boolean }) {
  const { t } = useTranslation()

  if (status === 'complete') {
    return (
      <Badge variant="success">
        {waived
          ? t('admin.sellers.onboarding.waived')
          : t('admin.sellers.onboarding.status.complete')}
      </Badge>
    )
  }
  if (status === 'pending') {
    return <Badge variant="secondary">{t('admin.sellers.onboarding.status.pending')}</Badge>
  }
  if (status === 'rejected') {
    return <Badge variant="destructive">{t('admin.sellers.onboarding.status.rejected')}</Badge>
  }
  return <Badge variant="outline">{t('admin.sellers.onboarding.status.incomplete')}</Badge>
}

function StatusIcon({ status }: { status: string }) {
  if (status === 'complete') {
    return <CheckCircle2Icon className="mt-0.5 size-4 shrink-0 text-green-600" />
  }

  if (status === 'pending') {
    return <ClockIcon className="mt-0.5 size-4 shrink-0 text-amber-600" />
  }
  if (status === 'rejected') {
    return <XCircleIcon className="mt-0.5 size-4 shrink-0 text-destructive" />
  }
  return <CircleIcon className="mt-0.5 size-4 shrink-0 text-muted-foreground" />
}

import type { Seller, SellerRequirementStatus } from '@spree/admin-sdk'
import { progressPercentage, useMetadataSheet, ViewMetadataMenuItem } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Collapsible,
  CollapsibleContent,
  cn,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  hasMetadata,
  Progress,
  StatusBadge as SharedStatusBadge,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  StepIcon,
  Tooltip,
  TooltipContent,
  TooltipTrigger,
  useConfirm,
} from '@spree/dashboard-ui'
import {
  ChevronRightIcon,
  DownloadIcon,
  EllipsisVerticalIcon,
  FileTextIcon,
  InfoIcon,
  SettingsIcon,
  XCircleIcon,
} from '@spree/dashboard-ui/icons'
import { Link } from '@tanstack/react-router'
import { useState } from 'react'
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
  // A finished checklist folds to its header: it would otherwise sit at the
  // top of the sidebar for the life of the seller.
  const [expandedByOperator, setExpanded] = useState(false)
  const expanded = expandedByOperator || !seller.onboarding_complete

  // A marketplace that asks for nothing has no checklist worth a card.
  if (progress.total === 0) return null

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          {t('admin.sellers.onboarding.title')}
          {seller.onboarding_complete ? (
            <SharedStatusBadge status="complete" label={t('admin.sellers.onboarding.all_done')} />
          ) : (
            <Badge variant="outline">
              {t('admin.sellers.onboarding.progress', {
                done: progress.done,
                total: progress.total,
              })}
            </Badge>
          )}
        </CardTitle>
        <CardAction className="flex gap-1">
          {canEdit && (
            <Button variant="ghost" size="icon-sm" asChild>
              <Link
                to={'/$storeId/settings/seller-requirements' as string}
                aria-label={t('admin.sellers.onboarding.manage_requirements')}
              >
                <SettingsIcon className="size-4" />
              </Link>
            </Button>
          )}
          {seller.onboarding_complete && (
            <Button
              variant="ghost"
              size="icon-sm"
              onClick={() => setExpanded(!expanded)}
              aria-expanded={expanded}
              aria-label={t('admin.sellers.onboarding.show_steps')}
            >
              <ChevronRightIcon
                className={cn(
                  'size-4 transition-transform duration-200 ease-out motion-reduce:transition-none',
                  expanded && 'rotate-90',
                )}
              />
            </Button>
          )}
        </CardAction>
      </CardHeader>

      {/* The progress stays when folded; only the steps slide away. */}
      <CardContent className="flex flex-col">
        <Progress value={progressPercentage(progress)} />

        <Collapsible open={expanded}>
          <CollapsibleContent>
            <div className="mt-4 border-border-subtle border-t pt-4">
              {data ? (
                <ul className="flex flex-col divide-y divide-border-subtle">
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
                <p className="text-muted-foreground text-base">{t('admin.common.loading')}</p>
              )}
            </div>
          </CollapsibleContent>
        </Collapsible>
      </CardContent>
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
  const [policyOpen, setPolicyOpen] = useState(false)
  const metadataSheet = useMetadataSheet()
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

  const policy = requirement.published_policy
  const canWaive = canEdit && requirement.status !== 'complete'
  const submissionHasMetadata = hasMetadata(submission?.metadata)

  return (
    <li className="flex flex-col gap-1 py-3 first:pt-0 last:pb-0">
      <div className="flex items-start gap-2">
        <StatusIcon status={requirement.status} waived={submission?.status === 'waived'} />
        <div className="flex min-w-0 flex-1 flex-wrap items-center gap-x-2 gap-y-1">
          <span className="font-medium text-base">{requirement.name}</span>
          {!requirement.required && (
            <Badge variant="outline">{t('admin.seller_requirements.required.no')}</Badge>
          )}
          {requirement.description && <DescriptionHint text={requirement.description} />}
        </div>

        {(canWaive || submissionHasMetadata) && (
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button
                size="icon-xs"
                variant="ghost"
                disabled={busy}
                aria-label={t('admin.actions.actions_menu')}
              >
                <EllipsisVerticalIcon className="size-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <ViewMetadataMenuItem
                metadata={submission?.metadata}
                onClick={() => metadataSheet.show(submission?.metadata, requirement.name)}
              />
              {canWaive && (
                <DropdownMenuItem onClick={handleWaive}>
                  {t('admin.sellers.onboarding.actions.waive')}
                </DropdownMenuItem>
              )}
            </DropdownMenuContent>
          </DropdownMenu>
        )}
      </div>

      {/* What the operator decides on stays in view; only the requirement's
          own description, which they wrote, moves into the hint above. */}
      <div className="flex flex-col gap-1 pl-6 empty:hidden">
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
        {requirement.published_policy && (
          <button
            type="button"
            className="flex cursor-pointer items-center gap-1 self-start text-link text-xs hover:text-link-hover"
            onClick={() => setPolicyOpen(true)}
          >
            <FileTextIcon className="size-3" />
            {t('admin.sellers.onboarding.view_policy')}
          </button>
        )}
        {submission?.file_url && (
          <a
            href={submission.file_url}
            className="flex min-w-0 items-center gap-1 self-start text-link text-xs hover:text-link-hover"
          >
            <DownloadIcon className="size-3 shrink-0" />
            <span className="truncate">
              {submission.file_name ?? t('admin.sellers.onboarding.download')}
            </span>
          </a>
        )}
        {canEdit && submission?.status === 'pending' && (
          <div className="flex gap-2 pt-1">
            <Button
              size="xs"
              variant="outline"
              disabled={busy}
              onClick={() =>
                acceptMutation.mutateAsync({ id: submission.id }).catch(() => undefined)
              }
            >
              {t('admin.sellers.onboarding.actions.accept')}
            </Button>
            <Button size="xs" variant="ghost" disabled={busy} onClick={handleReject}>
              {t('admin.sellers.onboarding.actions.reject')}
            </Button>
          </div>
        )}
      </div>

      {metadataSheet.sheet}

      {/* Read-only: the operator approves or sends back a seller, they do not
          rewrite the seller's legal text. Rendered as sanitized markup, the
          same way the storefront serves it. */}
      {policy && (
        <Sheet open={policyOpen} onOpenChange={setPolicyOpen}>
          <SheetContent className="data-[side=right]:max-w-[860px]">
            <SheetHeader>
              <SheetTitle>{policy.name}</SheetTitle>
              <SheetDescription>
                {t('admin.sellers.onboarding.policy_updated', {
                  date: new Date(policy.updated_at).toLocaleDateString(),
                })}
              </SheetDescription>
            </SheetHeader>
            <div className="min-h-0 flex-1 overflow-y-auto p-4">
              {policy.body_html ? (
                <div
                  className="prose prose-sm dark:prose-invert max-w-none"
                  // Sanitized server-side by Spree::RichTextSanitizer.
                  // biome-ignore lint/security/noDangerouslySetInnerHtml: sanitized on write
                  dangerouslySetInnerHTML={{ __html: policy.body_html }}
                />
              ) : (
                <p className="text-muted-foreground text-base">
                  {t('admin.sellers.onboarding.policy_empty')}
                </p>
              )}
            </div>
          </SheetContent>
        </Sheet>
      )}
    </li>
  )
}

/**
 * The step's state as an icon, named for screen readers and on hover. Four
 * states: done (or waived by the operator), waiting on the operator, sent
 * back, and not started. The icons are the ones the seller sees on their own
 * onboarding page.
 */
function StatusIcon({ status, waived }: { status: string; waived: boolean }) {
  const { t } = useTranslation()
  const label =
    status === 'complete' && waived
      ? t('admin.sellers.onboarding.waived')
      : t(`admin.sellers.onboarding.status.${status}`, {
          defaultValue: t('admin.sellers.onboarding.status.incomplete'),
        })

  const icon =
    status === 'complete' ? (
      <StepIcon status="done" />
    ) : status === 'pending' ? (
      <StepIcon status="in_progress" />
    ) : status === 'rejected' ? (
      <XCircleIcon className="size-4 shrink-0 text-destructive" />
    ) : (
      <StepIcon status="todo" />
    )

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <span role="img" aria-label={label} className="mt-0.5 flex shrink-0">
          {icon}
        </span>
      </TooltipTrigger>
      <TooltipContent>{label}</TooltipContent>
    </Tooltip>
  )
}

/**
 * The requirement's description, which the operator wrote in settings, as a
 * hint: focusable so keyboard users open it the same way pointer users do.
 */
function DescriptionHint({ text }: { text: string }) {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <button
          type="button"
          className="cursor-help rounded-sm text-muted-foreground focus-visible:outline-2 focus-visible:outline-ring focus-visible:outline-offset-2"
          aria-label={text}
        >
          <InfoIcon className="size-3.5" />
        </button>
      </TooltipTrigger>
      <TooltipContent className="max-w-xs">{text}</TooltipContent>
    </Tooltip>
  )
}

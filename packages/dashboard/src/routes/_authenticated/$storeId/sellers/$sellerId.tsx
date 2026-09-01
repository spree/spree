import type { Seller } from '@spree/admin-sdk'
import { adminClient, PageHeader, Slot, Subject, usePermissions } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  DropdownMenuItem,
  ErrorState,
  ResourceLayout,
  StatusBadge,
  useConfirm,
} from '@spree/dashboard-ui'
import { BanIcon, MailIcon, PauseIcon, UndoIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { ResourceDetailSkeleton } from '../../../../components/spree/route-pending'
import { SellerAddressCard } from '../../../../components/spree/sellers/seller-address-card'
import { SellerAtAGlanceCard } from '../../../../components/spree/sellers/seller-at-a-glance-card'
import { SellerBrandCard } from '../../../../components/spree/sellers/seller-brand-card'
import { SellerContactCard } from '../../../../components/spree/sellers/seller-contact-card'
import { SellerEditProfileSheet } from '../../../../components/spree/sellers/seller-edit-profile-sheet'
import { SellerEditSettlementSheet } from '../../../../components/spree/sellers/seller-edit-settlement-sheet'
import { SellerInviteSheet } from '../../../../components/spree/sellers/seller-invite-sheet'
import { SellerOnboardingCard } from '../../../../components/spree/sellers/seller-onboarding-card'
import { SellerSettlementCard } from '../../../../components/spree/sellers/seller-settlement-card'
import { SellerStatusCard } from '../../../../components/spree/sellers/seller-status-card'
import { SellerTeamCard } from '../../../../components/spree/sellers/seller-team-card'
import { useSellerOnboarding } from '../../../../hooks/use-seller-requirements'
import {
  useApproveSeller,
  useDeleteSeller,
  useRejectSeller,
  useReopenSellerOnboarding,
  useSeller,
  useSuspendSeller,
} from '../../../../hooks/use-sellers'
import { spreeJsonLinkResolver } from '../../../../lib/json-link-resolver'

export const Route = createFileRoute('/_authenticated/$storeId/sellers/$sellerId')({
  component: SellerDetailPage,
})

function SellerDetailPage() {
  const { t } = useTranslation()
  const { sellerId } = Route.useParams()
  const { data: seller, isLoading, error, refetch } = useSeller(sellerId)

  if (isLoading) return <ResourceDetailSkeleton />
  if (error || !seller) {
    return (
      <ErrorState
        title={t('admin.sellers.detail.load_error')}
        error={error as Error | undefined}
        onRetry={() => refetch()}
      />
    )
  }

  return <SellerBody seller={seller} />
}

/**
 * A seller's page is something you read first. The lifecycle sits in the
 * header, the profile below it, and every editable section opens its own
 * sheet — so arriving here shows you who the seller is rather than dropping
 * you into a form.
 */
function SellerBody({ seller }: { seller: Seller }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const { permissions } = usePermissions()
  const confirm = useConfirm()
  const deleteMutation = useDeleteSeller()

  const [editingProfile, setEditingProfile] = useState(false)
  const [editingSettlement, setEditingSettlement] = useState(false)
  const [inviting, setInviting] = useState(false)

  const approveMutation = useApproveSeller(seller.id)
  const reopenMutation = useReopenSellerOnboarding(seller.id)
  // Read here as well as in the card: approving has to know what is still
  // outstanding so it can say so before the operator overrides it.
  const { data: onboarding } = useSellerOnboarding(seller.id)
  const suspendMutation = useSuspendSeller(seller.id)
  const rejectMutation = useRejectSeller(seller.id)

  const canEdit = permissions.can('update', Subject.Seller)
  const status = seller.status

  // Mirrors the workflow guards, so the operator is never offered a move the
  // server would refuse.
  const canInvite = ['pending', 'invited', 'canceled'].includes(status)
  const canApprove = ['onboarding', 'ready_for_review', 'suspended', 'rejected'].includes(status)
  const canSuspend = ['approved', 'onboarding', 'ready_for_review'].includes(status)
  const canReject = ['pending', 'invited', 'onboarding', 'ready_for_review'].includes(status)

  const busy =
    approveMutation.isPending || suspendMutation.isPending || rejectMutation.isPending || !canEdit

  async function handleDelete() {
    await deleteMutation.mutateAsync(seller.id)
    navigate({ to: '/$storeId/sellers', params: { storeId } })
  }

  async function handleSuspend() {
    const ok = await confirm({
      title: t('admin.sellers.suspend_confirm.title'),
      message: t('admin.sellers.suspend_confirm.message', { name: seller.name }),
      variant: 'destructive',
      confirmLabel: t('admin.sellers.actions.suspend'),
    })
    if (!ok) return
    await suspendMutation.mutateAsync(undefined).catch(() => undefined)
  }

  async function handleReject() {
    const ok = await confirm({
      title: t('admin.sellers.reject_confirm.title'),
      message: t('admin.sellers.reject_confirm.message', { name: seller.name }),
      variant: 'destructive',
      confirmLabel: t('admin.sellers.actions.reject'),
    })
    if (!ok) return
    await rejectMutation.mutateAsync(undefined).catch(() => undefined)
  }

  // Admitting a seller whose checklist is unfinished is allowed, but never by
  // accident: the operator is shown exactly what is outstanding and has to
  // say they mean it. The server refuses without the override, so this dialog
  // is the only way past it.
  async function handleApprove() {
    if (!onboarding) return

    // `blocking` comes from the server, which is also what the approval gate
    // reads — deriving it here again would let the warning and the refusal
    // disagree.
    const blocking = onboarding.requirements.filter((requirement) => requirement.blocking)

    if (blocking.length > 0) {
      const ok = await confirm({
        title: t('admin.sellers.approve_override_confirm.title'),
        message: t('admin.sellers.approve_override_confirm.message', {
          names: blocking.map((requirement) => requirement.name).join(', '),
        }),
        variant: 'destructive',
        confirmLabel: t('admin.sellers.approve_override_confirm.action'),
      })
      if (!ok) return

      await approveMutation.mutateAsync({ override_requirements: true }).catch(() => undefined)
      return
    }

    await approveMutation.mutateAsync(undefined).catch(() => undefined)
  }

  async function handleReopenOnboarding() {
    const ok = await confirm({
      title: t('admin.sellers.reopen_onboarding_confirm.title'),
      message: t('admin.sellers.reopen_onboarding_confirm.message', { name: seller.name }),
      confirmLabel: t('admin.sellers.actions.reopen_onboarding'),
    })
    if (!ok) return

    await reopenMutation.mutateAsync(undefined).catch(() => undefined)
  }

  // Approving is the move an operator comes here to make, so it is the button;
  // the rest live in the dropdown beside it.
  const primaryAction = canEdit ? (
    <>
      {/* Without the checklist, approving cannot tell "nothing is blocking"
          from "we were never told", so the button waits for it — a failed
          query leaves `isPending` false with no data, which is why this gates
          on the data rather than the loading flag. */}
      {canApprove && (
        <Button disabled={busy || !onboarding} onClick={handleApprove}>
          {status === 'suspended'
            ? t('admin.sellers.actions.reinstate')
            : t('admin.sellers.actions.approve')}
        </Button>
      )}
      {canInvite && (
        <Button
          variant={canApprove ? 'outline' : 'default'}
          disabled={busy}
          onClick={() => setInviting(true)}
        >
          <MailIcon className="size-4" />
          {status === 'invited'
            ? t('admin.sellers.actions.reinvite')
            : t('admin.sellers.actions.invite')}
        </Button>
      )}
    </>
  ) : null

  const dropdownItems = canEdit ? (
    <>
      {status === 'ready_for_review' && (
        <DropdownMenuItem onClick={handleReopenOnboarding}>
          <UndoIcon className="size-4" />
          {t('admin.sellers.actions.reopen_onboarding')}
        </DropdownMenuItem>
      )}
    </>
  ) : null

  // Suspend and Reject both confirm destructively, so they read as destructive
  // in the menu too rather than as plain rows above the standard actions.
  const destructiveItems = canEdit ? (
    <>
      {canSuspend && (
        <DropdownMenuItem variant="destructive" onClick={handleSuspend}>
          <PauseIcon className="size-4" />
          {t('admin.sellers.actions.suspend')}
        </DropdownMenuItem>
      )}
      {canReject && (
        <DropdownMenuItem variant="destructive" onClick={handleReject}>
          <BanIcon className="size-4" />
          {t('admin.sellers.actions.reject')}
        </DropdownMenuItem>
      )}
    </>
  ) : null

  return (
    <>
      <ResourceLayout
        header={
          <PageHeader
            title={seller.name}
            subtitle={seller.contact_email ?? undefined}
            backTo="sellers"
            badges={
              <>
                <StatusBadge status={status} label={t(`admin.sellers.status.${status}`)} />
                {seller.onboarding_progress.total > 0 && !seller.onboarding_complete && (
                  <Badge variant="secondary">
                    {t('admin.sellers.onboarding.progress', {
                      done: seller.onboarding_progress.done,
                      total: seller.onboarding_progress.total,
                    })}
                  </Badge>
                )}
              </>
            }
            actions={primaryAction}
            dropdownItems={dropdownItems}
            destructiveItems={destructiveItems}
            resource={{ id: seller.id }}
            jsonPreview={{
              title: `Seller ${seller.name}`,
              fetch: () => adminClient.sellers.get(seller.id),
              endpoint: `/api/v3/admin/sellers/${seller.id}`,
              resolveLink: spreeJsonLinkResolver(storeId),
            }}
            onDelete={permissions.can('destroy', Subject.Seller) ? handleDelete : undefined}
            deleteLabel={t('admin.sellers.detail.delete_label')}
          />
        }
        main={
          <>
            <SellerBrandCard
              seller={seller}
              canEdit={canEdit}
              onEdit={() => setEditingProfile(true)}
            />
            <SellerOnboardingCard seller={seller} canEdit={canEdit} />
            <SellerTeamCard seller={seller} onInvite={() => setInviting(true)} />
            <Slot name="seller.form_main" context={{ seller, canEdit }} />
          </>
        }
        sidebar={
          <>
            <SellerStatusCard seller={seller} />
            <SellerAtAGlanceCard seller={seller} />
            <SellerContactCard
              seller={seller}
              canEdit={canEdit}
              onEdit={() => setEditingProfile(true)}
            />
            <SellerAddressCard seller={seller} addressKey="billing_address" canEdit={canEdit} />
            <SellerAddressCard seller={seller} addressKey="returns_address" canEdit={canEdit} />
            <SellerSettlementCard
              seller={seller}
              canEdit={canEdit}
              onEdit={() => setEditingSettlement(true)}
            />
            <Slot name="seller.form_sidebar" context={{ seller, canEdit }} />
          </>
        }
      />

      <SellerEditProfileSheet
        seller={seller}
        open={editingProfile}
        onOpenChange={setEditingProfile}
      />
      <SellerEditSettlementSheet
        seller={seller}
        open={editingSettlement}
        onOpenChange={setEditingSettlement}
      />
      {inviting && <SellerInviteSheet seller={seller} open onOpenChange={setInviting} />}
    </>
  )
}

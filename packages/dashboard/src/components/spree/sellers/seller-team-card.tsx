import type { Seller } from '@spree/admin-sdk'
import { Subject, usePermissions } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  RowActions,
  useConfirm,
} from '@spree/dashboard-ui'
import { UserPlusIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import {
  useRemoveSellerTeamMember,
  useResendSellerInvitation,
  useRevokeSellerInvitation,
  useSellerInvitations,
  useSellerTeam,
} from '../../../hooks/use-sellers'

/**
 * Who runs this seller, and the offers nobody has accepted yet.
 *
 * The operator's view of what a seller manages in their own panel. It earns
 * its place here because the operator is the only one who can repair a seller
 * that has locked itself out — the last member gone, or an invitation sent to
 * the wrong address — which a seller by definition cannot do from inside.
 */
export function SellerTeamCard({ seller, onInvite }: { seller: Seller; onInvite: () => void }) {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const confirm = useConfirm()

  const { data: team, isLoading: loadingTeam } = useSellerTeam(seller.id)
  const { data: invitations } = useSellerInvitations(seller.id)
  const removeMember = useRemoveSellerTeamMember(seller.id)
  const revokeInvitation = useRevokeSellerInvitation(seller.id)
  const resendInvitation = useResendSellerInvitation(seller.id)

  const canManage = permissions.can('update', Subject.Seller)
  const members = team?.data ?? []
  const pending = invitations?.data ?? []

  async function handleRemove(id: string, label: string) {
    const ok = await confirm({
      title: t('admin.sellers.team.remove_confirm.title'),
      message: t('admin.sellers.team.remove_confirm.message', { name: label }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.remove'),
    })
    if (!ok) return
    await removeMember.mutateAsync(id).catch(() => undefined)
  }

  async function handleRevoke(id: string, label: string) {
    const ok = await confirm({
      title: t('admin.sellers.team.revoke_confirm.title'),
      message: t('admin.sellers.team.revoke_confirm.message', { email: label }),
      variant: 'destructive',
      confirmLabel: t('admin.sellers.team.revoke'),
    })
    if (!ok) return
    await revokeInvitation.mutateAsync(id).catch(() => undefined)
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.sellers.team.title')}</CardTitle>
        {canManage && (
          <CardAction>
            <Button variant="outline" size="sm" onClick={onInvite}>
              <UserPlusIcon className="size-4" />
              {t('admin.sellers.team.invite')}
            </Button>
          </CardAction>
        )}
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        {loadingTeam ? (
          <p className="text-muted-foreground text-sm">{t('admin.common.loading')}</p>
        ) : members.length === 0 && pending.length === 0 ? (
          <p className="text-muted-foreground text-sm">{t('admin.sellers.team.empty')}</p>
        ) : null}

        {members.map((member) => (
          <div key={member.id} className="flex items-center justify-between gap-3">
            <div className="min-w-0">
              <div className="truncate text-sm font-medium">{member.full_name || member.email}</div>
              {member.full_name && (
                <div className="truncate text-muted-foreground text-xs">{member.email}</div>
              )}
            </div>
            {canManage && (
              <RowActions
                actions={[
                  {
                    key: 'remove',
                    label: t('admin.actions.remove'),
                    destructive: true,
                    disabled: removeMember.isPending,
                    onSelect: () => handleRemove(member.id, member.full_name || member.email),
                  },
                ]}
              />
            )}
          </div>
        ))}

        {pending.length > 0 && (
          <div className="flex flex-col gap-3 border-t border-border pt-4">
            <h3 className="text-muted-foreground text-xs font-medium">
              {t('admin.sellers.team.pending')}
            </h3>
            {pending.map((invitation) => (
              <div key={invitation.id} className="flex items-center justify-between gap-3">
                <div className="flex min-w-0 items-center gap-2">
                  <span className="truncate text-sm">{invitation.email}</span>
                  <Badge variant="secondary">{t('admin.sellers.team.invited')}</Badge>
                </div>
                {canManage && (
                  <RowActions
                    actions={[
                      {
                        key: 'resend',
                        label: t('admin.sellers.team.resend'),
                        disabled: resendInvitation.isPending,
                        onSelect: () =>
                          resendInvitation.mutateAsync(invitation.id).catch(() => undefined),
                      },
                      {
                        key: 'revoke',
                        label: t('admin.sellers.team.revoke'),
                        destructive: true,
                        disabled: revokeInvitation.isPending,
                        onSelect: () => handleRevoke(invitation.id, invitation.email),
                      },
                    ]}
                  />
                )}
              </div>
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  )
}

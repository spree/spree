import type { Seller } from '@spree/admin-sdk'
import { Subject, usePermissions } from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  Empty,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  RowActions,
  Section,
  SectionActions,
  SectionHeader,
  SectionTitle,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import { UserPlusIcon, UsersIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { useCopyInvitationLink } from '../../../hooks/use-copy-invitation-link'
import {
  useRemoveSellerTeamMember,
  useResendSellerInvitation,
  useRevokeSellerInvitation,
  useSellerInvitationAcceptanceLink,
  useSellerInvitations,
  useSellerTeam,
} from '../../../hooks/use-sellers'
import { PersonIdentity } from '../person-identity'

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
  const acceptanceLink = useSellerInvitationAcceptanceLink(seller.id)
  const copyInvitationLink = useCopyInvitationLink(acceptanceLink.mutateAsync)

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
    <Section>
      <SectionHeader>
        <SectionTitle>
          <UsersIcon />
          {t('admin.sellers.team.title')}
          {members.length > 0 && <Badge variant="outline">{members.length}</Badge>}
        </SectionTitle>
        {canManage && (
          <SectionActions>
            <Button variant="outline" size="sm" onClick={onInvite}>
              <UserPlusIcon className="size-4" />
              {t('admin.sellers.team.invite')}
            </Button>
          </SectionActions>
        )}
      </SectionHeader>

      {/* One card: the members as a table, then any pending invitations. */}
      <Card>
        {loadingTeam || (members.length === 0 && pending.length === 0) ? (
          <CardContent>
            {loadingTeam ? (
              <p className="text-muted-foreground text-base">{t('admin.common.loading')}</p>
            ) : (
              <Empty className="p-4">
                <EmptyHeader>
                  <EmptyMedia variant="icon">
                    <UsersIcon />
                  </EmptyMedia>
                  <EmptyTitle>{t('admin.sellers.team.empty')}</EmptyTitle>
                </EmptyHeader>
              </Empty>
            )}
          </CardContent>
        ) : null}

        {members.length > 0 && (
          <Table roundedTop>
            <TableHeader>
              <TableRow>
                <TableHead>{t('admin.company_memberships.columns.member')}</TableHead>
                {canManage && <TableHead className="w-10" />}
              </TableRow>
            </TableHeader>
            <TableBody>
              {members.map((member) => (
                <TableRow key={member.id}>
                  <TableCell>
                    <PersonIdentity name={member.full_name} email={member.email} />
                  </TableCell>
                  {canManage && (
                    <TableCell className="w-10 text-right">
                      <RowActions
                        actions={[
                          {
                            key: 'remove',
                            label: t('admin.actions.remove'),
                            destructive: true,
                            disabled: removeMember.isPending,
                            onSelect: () =>
                              handleRemove(member.id, member.full_name || member.email),
                          },
                        ]}
                      />
                    </TableCell>
                  )}
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}

        {pending.length > 0 && (
          <div className={members.length > 0 ? 'border-border-subtle border-t' : undefined}>
            <p className="px-3.5 pt-3 pb-1 font-medium text-muted-foreground text-xs">
              {t('admin.sellers.team.pending')}
            </p>
            <Table>
              <TableBody>
                {pending.map((invitation) => (
                  <TableRow key={invitation.id}>
                    <TableCell>
                      <PersonIdentity email={invitation.email} />
                    </TableCell>
                    <TableCell className="w-px whitespace-nowrap text-right">
                      <span className="inline-flex items-center gap-2">
                        <Badge variant="secondary">{t('admin.sellers.team.invited')}</Badge>
                        {canManage && (
                          <RowActions
                            actions={[
                              {
                                key: 'resend',
                                label: t('admin.sellers.team.resend'),
                                disabled: resendInvitation.isPending,
                                onSelect: () =>
                                  resendInvitation
                                    .mutateAsync(invitation.id)
                                    .catch(() => undefined),
                              },
                              {
                                key: 'copy-link',
                                label: t('admin.staff.actions.copy_invitation_link'),
                                disabled: acceptanceLink.isPending,
                                onSelect: () => copyInvitationLink(invitation.id),
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
                      </span>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        )}
      </Card>
    </Section>
  )
}

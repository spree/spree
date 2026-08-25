import { Can, getInitials, Slot } from '@spree/dashboard-core'
import {
  Avatar,
  AvatarFallback,
  AvatarImage,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  Field,
  FieldError,
  FieldLabel,
  Input,
  RelativeTime,
  RowActions,
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  toastManager,
  useConfirm,
  useCopyToClipboard,
} from '@spree/dashboard-ui'
import type { Invitation, TeamMember } from '@spree/seller-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useParams } from '@tanstack/react-router'
import {
  ClockIcon,
  LinkIcon,
  MailIcon,
  PlusIcon,
  SendIcon,
  UserMinusIcon,
  UsersRoundIcon,
  XIcon,
} from 'lucide-react'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'

/**
 * Who can sign in and run this seller.
 *
 * Deliberately the same shape as the marketplace operator's staff page —
 * members in a table, pending offers in their own card — because it is the
 * same job seen from the other side, and someone who has used one should not
 * have to learn the other.
 *
 * Everyone holds the seller's own seeded role, which carries the whole seller
 * vocabulary, so inviting asks only for an address. Narrower seller roles are
 * a design of their own.
 */
export function TeamPage() {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const [inviteOpen, setInviteOpen] = useState(false)

  const members = useQuery({
    queryKey: ['seller', sellerId, 'team'],
    queryFn: () => sellerClient().team.list(),
  })

  const invitations = useQuery({
    queryKey: ['seller', sellerId, 'invitations'],
    queryFn: () => sellerClient().invitations.list(),
  })

  const pending = invitations.data?.data ?? []

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="font-medium text-2xl">{t('team.title')}</h1>
          <p className="text-muted-foreground text-sm">{t('team.subtitle')}</p>
        </div>
        {/* Purely a UX gate — the API refuses the write regardless. Same
            `<Can>` the operator's dashboard uses, reading the CanCanCan rules
            the seller `/me` serializes. */}
        <div className="flex items-center gap-2">
          {/* A marketplace adds its own actions here via
              `defineDashboardPlugin({ slots: { 'seller.team.actions': [...] } })`. */}
          <Slot name="seller.team.actions" context={{ sellerId }} />
          <Can I="update" a="seller_profile">
            <Button size="sm" onClick={() => setInviteOpen(true)}>
              <PlusIcon className="size-4" />
              {t('team.invite_cta')}
            </Button>
          </Can>
        </div>
      </div>

      <MembersCard members={members.data?.data ?? []} loading={members.isLoading} />

      {/* Hidden entirely when there is nothing outstanding — an empty card
          would imply something is wrong. */}
      {(invitations.isLoading || pending.length > 0) && (
        <PendingInvitationsCard invitations={pending} loading={invitations.isLoading} />
      )}

      {/* Extra cards below the built-ins — a marketplace's own team-related
          content (roles they add, an audit trail) lands here. */}
      <Slot name="seller.team.after" context={{ sellerId }} />

      <InviteDialog open={inviteOpen} onOpenChange={setInviteOpen} />
    </div>
  )
}

function MembersCard({ members, loading }: { members: TeamMember[]; loading: boolean }) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('team.members_section')}</CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        {loading ? (
          <div className="flex flex-col gap-3 p-4">
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
          </div>
        ) : members.length === 0 ? (
          <Empty>
            <EmptyHeader>
              <EmptyMedia variant="icon">
                <UsersRoundIcon />
              </EmptyMedia>
              <EmptyTitle>{t('team.empty')}</EmptyTitle>
              <EmptyDescription>{t('team.empty_description')}</EmptyDescription>
            </EmptyHeader>
          </Empty>
        ) : (
          <Table roundedBottom>
            <TableHeader>
              <TableRow>
                <TableHead>{t('team.table.member')}</TableHead>
                <TableHead className="w-12" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {members.map((member) => (
                <MemberRow key={member.id} member={member} lastOne={members.length === 1} />
              ))}
            </TableBody>
          </Table>
        )}
      </CardContent>
    </Card>
  )
}

function MemberRow({ member, lastOne }: { member: TeamMember; lastOne: boolean }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const queryClient = useQueryClient()
  const confirm = useConfirm()

  const remove = useMutation({
    mutationFn: (id: string) => sellerClient().team.remove(id),
    onSuccess: () => {
      toastManager.add({ type: 'success', title: t('team.messages.removed') })
      void queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'team'] })
    },
    // Read the server's own message rather than assuming which rule was hit —
    // "last member" is one refusal among several the API may grow.
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
  })

  async function handleRemove() {
    const ok = await confirm({
      title: t('team.confirm.remove_title'),
      message: t('team.confirm.remove_message', { name: member.full_name || member.email }),
      variant: 'destructive',
      confirmLabel: t('team.actions.remove'),
    })
    if (ok) remove.mutate(member.id)
  }

  return (
    <TableRow>
      <TableCell>
        <div className="flex items-center gap-3">
          <Avatar className="size-8">
            {member.avatar_url && <AvatarImage src={member.avatar_url} alt="" />}
            <AvatarFallback className="bg-muted text-xs">
              {getInitials(member.full_name, member.email)}
            </AvatarFallback>
          </Avatar>
          <div className="flex flex-col leading-tight">
            <span className="font-medium text-foreground">{member.full_name || member.email}</span>
            {member.full_name && (
              <span className="text-muted-foreground text-xs">{member.email}</span>
            )}
          </div>
        </div>
      </TableCell>
      <TableCell className="text-right">
        <RowActions
          actions={[
            {
              key: 'remove',
              label: t('team.actions.remove'),
              icon: <UserMinusIcon className="size-4" />,
              destructive: true,
              // A seller nobody can sign in to can only be reopened by the
              // marketplace operator, so the server refuses this too.
              disabled: lastOne || remove.isPending,
              onSelect: handleRemove,
            },
          ]}
        />
      </TableCell>
    </TableRow>
  )
}

function PendingInvitationsCard({
  invitations,
  loading,
}: {
  invitations: Invitation[]
  loading: boolean
}) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('team.invitations_section')}</CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        {loading ? (
          <div className="p-4">
            <Skeleton className="h-10 w-full" />
          </div>
        ) : (
          <Table roundedBottom>
            <TableHeader>
              <TableRow>
                <TableHead>{t('team.table.email')}</TableHead>
                <TableHead>{t('team.table.expires')}</TableHead>
                <TableHead className="w-12" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {invitations.map((invitation) => (
                <InvitationRow key={invitation.id} invitation={invitation} />
              ))}
            </TableBody>
          </Table>
        )}
      </CardContent>
    </Card>
  )
}

function InvitationRow({ invitation }: { invitation: Invitation }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const queryClient = useQueryClient()
  const confirm = useConfirm()
  const { copy } = useCopyToClipboard()

  const invalidate = () =>
    queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'invitations'] })

  const resend = useMutation({
    mutationFn: (id: string) => sellerClient().invitations.resend(id),
    onSuccess: () => {
      toastManager.add({ type: 'success', title: t('team.messages.resent') })
      void invalidate()
    },
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
  })

  const revoke = useMutation({
    mutationFn: (id: string) => sellerClient().invitations.revoke(id),
    onSuccess: () => {
      toastManager.add({ type: 'success', title: t('team.messages.revoked') })
      void invalidate()
    },
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
  })

  async function handleCopyLink() {
    // Path-only when no panel origin is configured; resolve against wherever
    // this panel is actually mounted. `BASE_URL` matters: served at /sellers
    // (the single-node topology), origin alone would produce a link that
    // misses the mount and 404s.
    const url = invitation.acceptance_url.startsWith('/')
      ? new URL(
          `.${invitation.acceptance_url}`,
          `${window.location.origin}${import.meta.env.BASE_URL}`,
        ).toString()
      : invitation.acceptance_url

    await copy(url)
    toastManager.add({ type: 'success', title: t('team.messages.link_copied') })
  }

  async function handleRevoke() {
    const ok = await confirm({
      title: t('team.confirm.revoke_title'),
      message: t('team.confirm.revoke_message', { email: invitation.email }),
      variant: 'destructive',
      confirmLabel: t('team.actions.revoke'),
    })
    if (ok) revoke.mutate(invitation.id)
  }

  return (
    <TableRow>
      <TableCell>
        <div className="flex items-center gap-2">
          <MailIcon className="size-4 text-muted-foreground" />
          <span className="font-medium">{invitation.email}</span>
        </div>
      </TableCell>
      <TableCell className="text-muted-foreground text-sm">
        {invitation.expires_at ? (
          <span className="inline-flex items-center gap-1">
            <ClockIcon className="size-3.5" />
            <RelativeTime iso={invitation.expires_at} />
          </span>
        ) : (
          '—'
        )}
      </TableCell>
      <TableCell className="text-right">
        <RowActions
          actions={[
            {
              key: 'resend',
              label: t('team.actions.resend'),
              icon: <SendIcon className="size-4" />,
              disabled: resend.isPending,
              onSelect: () => resend.mutate(invitation.id),
            },
            {
              key: 'copy',
              label: t('team.actions.copy_link'),
              icon: <LinkIcon className="size-4" />,
              onSelect: handleCopyLink,
            },
            {
              key: 'revoke',
              label: t('team.actions.revoke'),
              icon: <XIcon className="size-4" />,
              destructive: true,
              disabled: revoke.isPending,
              onSelect: handleRevoke,
            },
          ]}
        />
      </TableCell>
    </TableRow>
  )
}

function InviteDialog({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const queryClient = useQueryClient()
  const form = useForm<{ email: string }>({ defaultValues: { email: '' } })

  const invite = useMutation({
    mutationFn: (email: string) => sellerClient().team.invite({ email }),
    onSuccess: () => {
      form.reset({ email: '' })
      onOpenChange(false)
      toastManager.add({ type: 'success', title: t('team.messages.invited') })
      // The new row lands in pending invitations, not in members — they are
      // not a member until they accept.
      void queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'invitations'] })
    },
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
  })

  const { errors } = form.formState

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        // Clear a half-typed address on dismiss, so reopening starts fresh
        // rather than showing what was abandoned.
        if (!next) form.reset({ email: '' })
        onOpenChange(next)
      }}
    >
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('team.invite_title')}</DialogTitle>
          <DialogDescription>{t('team.invite_description')}</DialogDescription>
        </DialogHeader>

        <form onSubmit={form.handleSubmit((values) => invite.mutate(values.email))}>
          {/* DialogBody owns the padding and the scroll region; the footer
              sits outside it so its divider spans the dialog. */}
          <DialogBody>
            <Field>
              <FieldLabel htmlFor="invite-email">{t('team.invite_email')}</FieldLabel>
              <Input
                id="invite-email"
                type="email"
                autoFocus
                placeholder={t('team.invite_email_placeholder')}
                aria-invalid={!!errors.email || undefined}
                {...form.register('email', { required: true })}
              />
              <FieldError errors={[errors.email]} />
            </Field>
          </DialogBody>

          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" disabled={invite.isPending}>
              {invite.isPending ? t('team.invite_sending') : t('team.invite_submit')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

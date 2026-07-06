import { zodResolver } from '@hookform/resolvers/zod'
import { type AdminUser, type Invitation, type Role, SpreeError } from '@spree/admin-sdk'
import { getInitials, mapSpreeErrorsToForm, PageHeader } from '@spree/dashboard-core'
import {
  Avatar,
  AvatarFallback,
  AvatarImage,
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Checkbox,
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
  requiredMessage,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
  useCopyToClipboard,
} from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import i18n from 'i18next'
import {
  BanIcon,
  ClockIcon,
  LinkIcon,
  MailIcon,
  PlusIcon,
  UserMinusIcon,
  UsersRoundIcon,
} from 'lucide-react'
import { useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { z } from 'zod/v4'
import {
  useCreateInvitation,
  useDeleteInvitation,
  useInvitations,
  useRemoveStaff,
  useResendInvitation,
  useRoles,
  useStaff,
  useUpdateStaff,
} from '../../../../hooks/use-staff'

export const Route = createFileRoute('/_authenticated/$storeId/settings/staff')({
  component: StaffSettingsPage,
})

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

function StaffSettingsPage() {
  const { t } = useTranslation()
  const { data: staff, isLoading: staffLoading } = useStaff()
  const { data: invitations, isLoading: invitationsLoading } = useInvitations()
  const [inviteOpen, setInviteOpen] = useState(false)

  const pendingInvitations = invitations?.data.filter((i) => i.status === 'pending') ?? []

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={t('admin.pages.staff.title')}
        subtitle={t('admin.pages.staff.subtitle')}
        actions={
          <Button size="sm" onClick={() => setInviteOpen(true)}>
            <PlusIcon className="size-4" />
            {t('admin.pages.staff.invite_cta')}
          </Button>
        }
      />

      <StaffCard staff={staff?.data ?? []} loading={staffLoading} />

      {(invitationsLoading || pendingInvitations.length > 0) && (
        <PendingInvitationsCard invitations={pendingInvitations} loading={invitationsLoading} />
      )}

      <InviteDialog open={inviteOpen} onOpenChange={setInviteOpen} />
    </div>
  )
}

// ---------------------------------------------------------------------------
// Active staff card
// ---------------------------------------------------------------------------

function StaffCard({ staff, loading }: { staff: AdminUser[]; loading: boolean }) {
  const { t } = useTranslation()
  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.staff.members_section')}</CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        {loading ? (
          <div className="flex flex-col gap-3 p-4">
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
          </div>
        ) : staff.length === 0 ? (
          <Empty>
            <EmptyHeader>
              <EmptyMedia variant="icon">
                <UsersRoundIcon />
              </EmptyMedia>
              <EmptyTitle>{t('admin.pages.staff.empty')}</EmptyTitle>
              <EmptyDescription>{t('admin.pages.staff.empty_description')}</EmptyDescription>
            </EmptyHeader>
          </Empty>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('admin.pages.staff.table.member')}</TableHead>
                <TableHead>{t('admin.pages.staff.table.roles')}</TableHead>
                <TableHead className="w-12" />
              </TableRow>
            </TableHeader>
            <TableBody>
              {staff.map((member) => (
                <StaffRow key={member.id} member={member} />
              ))}
            </TableBody>
          </Table>
        )}
      </CardContent>
    </Card>
  )
}

function StaffRow({ member }: { member: AdminUser }) {
  const { t } = useTranslation()
  const [editOpen, setEditOpen] = useState(false)
  const removeMutation = useRemoveStaff()
  const confirm = useConfirm()

  const initials = getInitials(member.full_name, member.email)

  async function handleRemove() {
    const ok = await confirm({
      title: t('admin.staff.confirm.remove_title'),
      message: t('admin.staff.confirm.remove_message', {
        name: member.full_name || member.email,
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.remove'),
    })
    if (!ok) return

    try {
      await removeMutation.mutateAsync(member.id)
      toast.success(t('admin.pages.staff.messages.removed'))
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t('admin.staff.errors.failed_to_remove'))
    }
  }

  return (
    <>
      <TableRow>
        <TableCell>
          <div className="flex items-center gap-3">
            <Avatar className="size-8">
              {member.avatar_url && <AvatarImage src={member.avatar_url} alt="" />}
              <AvatarFallback className="bg-muted text-xs">{initials}</AvatarFallback>
            </Avatar>
            <div className="flex flex-col leading-tight">
              <span className="font-medium text-foreground">
                {member.full_name || member.email}
              </span>
              {member.full_name && (
                <span className="text-xs text-muted-foreground">{member.email}</span>
              )}
            </div>
          </div>
        </TableCell>
        <TableCell>
          {member.roles.length === 0 ? (
            <span className="text-sm text-muted-foreground">—</span>
          ) : (
            <div className="flex flex-wrap gap-1">
              {member.roles.map((role) => (
                <Badge key={role.id} className="capitalize">
                  {role.name}
                </Badge>
              ))}
            </div>
          )}
        </TableCell>
        <TableCell className="text-right">
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => setEditOpen(true) },
              {
                key: 'remove',
                label: t('admin.pages.staff.actions.remove'),
                icon: <UserMinusIcon className="size-4" />,
                destructive: true,
                disabled: removeMutation.isPending,
                onSelect: handleRemove,
              },
            ]}
          />
        </TableCell>
      </TableRow>

      <EditStaffSheet open={editOpen} onOpenChange={setEditOpen} member={member} />
    </>
  )
}

// ---------------------------------------------------------------------------
// Pending invitations card
// ---------------------------------------------------------------------------

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
        <CardTitle>{t('admin.pages.staff.invitations_section')}</CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        {loading ? (
          <div className="p-4">
            <Skeleton className="h-10 w-full" />
          </div>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>{t('admin.fields.email.label')}</TableHead>
                <TableHead>{t('admin.pages.staff.table.role')}</TableHead>
                <TableHead>{t('admin.fields.expires_at.label')}</TableHead>
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
  const resendMutation = useResendInvitation()
  const deleteMutation = useDeleteInvitation()
  const confirm = useConfirm()
  const { copy } = useCopyToClipboard()

  async function handleCopyLink() {
    // Path-only when `Spree::Config[:admin_url]` is unset; resolve against the SPA's origin.
    const url = invitation.acceptance_url.startsWith('/')
      ? `${window.location.origin}${invitation.acceptance_url}`
      : invitation.acceptance_url
    await copy(url)
    toast.success(t('admin.staff.actions.invitation_link_copied'))
  }

  async function handleResend() {
    try {
      await resendMutation.mutateAsync(invitation.id)
      toast.success(t('admin.messages.invitation_resent'))
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t('admin.staff.errors.failed_to_resend'))
    }
  }

  async function handleDelete() {
    const ok = await confirm({
      title: t('admin.staff.confirm.revoke_title'),
      message: t('admin.staff.confirm.revoke_message', { email: invitation.email }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.revoke'),
    })
    if (!ok) return

    try {
      await deleteMutation.mutateAsync(invitation.id)
      toast.success(t('admin.pages.staff.messages.revoked'))
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t('admin.staff.errors.failed_to_revoke'))
    }
  }

  return (
    <TableRow>
      <TableCell>
        <div className="flex items-center gap-2">
          <MailIcon className="size-4 text-muted-foreground" />
          <span className="font-medium">{invitation.email}</span>
        </div>
      </TableCell>
      <TableCell>
        {invitation.role_name ? (
          <Badge className="capitalize">{invitation.role_name}</Badge>
        ) : (
          <span className="text-sm text-muted-foreground">—</span>
        )}
      </TableCell>
      <TableCell className="text-sm text-muted-foreground">
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
              label: t('admin.pages.staff.actions.resend'),
              icon: <MailIcon className="size-4" />,
              disabled: resendMutation.isPending,
              onSelect: handleResend,
            },
            {
              key: 'copy-link',
              label: t('admin.staff.actions.copy_invitation_link'),
              icon: <LinkIcon className="size-4" />,
              onSelect: handleCopyLink,
            },
            {
              key: 'revoke',
              label: t('admin.actions.revoke'),
              icon: <BanIcon className="size-4" />,
              destructive: true,
              disabled: deleteMutation.isPending,
              onSelect: handleDelete,
            },
          ]}
        />
      </TableCell>
    </TableRow>
  )
}

// ---------------------------------------------------------------------------
// Invite dialog
// ---------------------------------------------------------------------------

const inviteSchema = z.object({
  email: z
    .string()
    .min(1, { error: requiredMessage('email') })
    .email({ error: () => i18n.t('admin.validation.invalid_email') }),
  role_id: z.string().min(1, { error: () => i18n.t('admin.staff.validation.role_required') }),
})

type InviteFormValues = z.infer<typeof inviteSchema>

function InviteDialog({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: roles, isLoading: rolesLoading } = useRoles()
  const createMutation = useCreateInvitation()

  const form = useForm<InviteFormValues>({
    resolver: zodResolver(inviteSchema),
    defaultValues: { email: '', role_id: '' },
  })

  async function onSubmit(values: InviteFormValues) {
    try {
      await createMutation.mutateAsync(values)
      toast.success(t('admin.messages.invitation_sent'))
      form.reset({ email: '', role_id: '' })
      onOpenChange(false)
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toast.error(err instanceof Error ? err.message : t('admin.errors.failed_to_send_invitation'))
    }
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset({ email: '', role_id: '' })
        onOpenChange(next)
      }}
    >
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.staff.invite_sheet.title')}</DialogTitle>
          <DialogDescription>{t('admin.pages.staff.invite_sheet.description')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={form.handleSubmit(onSubmit)}>
          <DialogBody className="flex flex-col gap-4">
            {form.formState.errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {form.formState.errors.root.message}
              </p>
            )}
            <Field>
              <FieldLabel htmlFor="invite-email">{t('admin.fields.email.label')}</FieldLabel>
              <Input
                id="invite-email"
                type="email"
                autoFocus
                placeholder={t('admin.staff.invite.email_placeholder')}
                aria-invalid={!!form.formState.errors.email || undefined}
                {...form.register('email')}
              />
              <FieldError errors={[form.formState.errors.email]} />
            </Field>
            <Field>
              <FieldLabel htmlFor="invite-role">{t('admin.fields.role_id.label')}</FieldLabel>
              <Controller
                name="role_id"
                control={form.control}
                render={({ field }) => {
                  const roleList = roles?.data ?? []
                  return (
                    <Select value={field.value} onValueChange={field.onChange}>
                      <SelectTrigger id="invite-role">
                        {/* Base UI's SelectValue defaults to rendering the raw
                            `value` (a prefixed role ID). Use the children
                            render-prop to map ID → name. */}
                        <SelectValue
                          placeholder={
                            rolesLoading
                              ? t('admin.staff.invite.roles_loading')
                              : t('admin.staff.invite.roles_placeholder')
                          }
                        >
                          {(value) => {
                            const role = roleList.find((r) => r.id === value)
                            return role ? (
                              <span className="capitalize">{role.name}</span>
                            ) : (
                              (value as string)
                            )
                          }}
                        </SelectValue>
                      </SelectTrigger>
                      <SelectContent>
                        {roleList.map((role) => (
                          <SelectItem key={role.id} value={role.id} className="capitalize">
                            {role.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )
                }}
              />
              <FieldError errors={[form.formState.errors.role_id]} />
            </Field>
          </DialogBody>
          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting
                ? t('admin.actions.sending')
                : t('admin.actions.send_invitation')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

// ---------------------------------------------------------------------------
// Edit staff dialog
// ---------------------------------------------------------------------------

const editSchema = z.object({
  first_name: z.string().optional(),
  last_name: z.string().optional(),
  role_ids: z
    .array(z.string())
    .min(1, { error: () => i18n.t('admin.staff.validation.roles_required') }),
})

type EditFormValues = z.infer<typeof editSchema>

function EditStaffSheet({
  open,
  onOpenChange,
  member,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  member: AdminUser
}) {
  const { t } = useTranslation()
  const { data: roles } = useRoles()
  const updateMutation = useUpdateStaff()

  const form = useForm<EditFormValues>({
    resolver: zodResolver(editSchema),
    defaultValues: {
      first_name: member.first_name ?? '',
      last_name: member.last_name ?? '',
      role_ids: member.roles.map((r) => r.id),
    },
  })

  async function onSubmit(values: EditFormValues) {
    try {
      await updateMutation.mutateAsync({
        id: member.id,
        params: {
          first_name: values.first_name || undefined,
          last_name: values.last_name || undefined,
          role_ids: values.role_ids,
        },
      })
      toast.success(t('admin.pages.staff.messages.updated'))
      onOpenChange(false)
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toast.error(err instanceof Error ? err.message : t('admin.errors.failed_to_update_staff'))
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) {
          form.reset({
            first_name: member.first_name ?? '',
            last_name: member.last_name ?? '',
            role_ids: member.roles.map((r) => r.id),
          })
        }
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{member.full_name || member.email}</SheetTitle>
          <SheetDescription>{t('admin.staff.edit_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            {form.formState.errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {form.formState.errors.root.message}
              </p>
            )}
            <div className="grid grid-cols-2 gap-3">
              <Field>
                <FieldLabel htmlFor="staff-first-name">
                  {t('admin.fields.first_name.label')}
                </FieldLabel>
                <Input
                  id="staff-first-name"
                  aria-invalid={!!form.formState.errors.first_name || undefined}
                  {...form.register('first_name')}
                />
                <FieldError errors={[form.formState.errors.first_name]} />
              </Field>
              <Field>
                <FieldLabel htmlFor="staff-last-name">
                  {t('admin.fields.last_name.label')}
                </FieldLabel>
                <Input
                  id="staff-last-name"
                  aria-invalid={!!form.formState.errors.last_name || undefined}
                  {...form.register('last_name')}
                />
                <FieldError errors={[form.formState.errors.last_name]} />
              </Field>
            </div>
            <Field>
              <FieldLabel>{t('admin.staff.edit.roles_label')}</FieldLabel>
              <Controller
                name="role_ids"
                control={form.control}
                render={({ field }) => (
                  <RoleCheckboxGroup
                    roles={roles?.data ?? []}
                    value={field.value}
                    onChange={field.onChange}
                  />
                )}
              />
              <FieldError errors={[form.formState.errors.role_ids]} />
            </Field>
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button
              type="submit"
              size="sm"
              disabled={form.formState.isSubmitting || !form.formState.isDirty}
            >
              {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

// Minimal multi-select for roles. Spree core only ships `admin` today, so a
// vertical checkbox list is plenty; we'll graduate to a richer picker once
// roles diversify.
function RoleCheckboxGroup({
  roles,
  value,
  onChange,
}: {
  roles: Role[]
  value: string[]
  onChange: (next: string[]) => void
}) {
  const { t } = useTranslation()

  function toggle(id: string) {
    onChange(value.includes(id) ? value.filter((v) => v !== id) : [...value, id])
  }

  if (roles.length === 0) {
    return <p className="text-sm text-muted-foreground">{t('admin.staff.invite.no_roles')}</p>
  }

  return (
    <div className="flex flex-col gap-1.5 rounded-md border border-border p-3">
      {roles.map((role) => {
        const checked = value.includes(role.id)
        const id = `role-${role.id}`
        return (
          <label
            key={role.id}
            htmlFor={id}
            className="flex cursor-pointer items-center gap-2 text-sm capitalize"
          >
            <Checkbox id={id} checked={checked} onCheckedChange={() => toggle(role.id)} />
            {role.name}
          </label>
        )
      })}
    </div>
  )
}

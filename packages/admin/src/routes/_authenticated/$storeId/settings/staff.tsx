import { zodResolver } from '@hookform/resolvers/zod'
import { type AdminUser, type Invitation, type Role, SpreeError } from '@spree/admin-sdk'
import { createFileRoute } from '@tanstack/react-router'
import {
  ClockIcon,
  LinkIcon,
  MailIcon,
  MoreHorizontalIcon,
  PlusIcon,
  ShieldIcon,
  UsersRoundIcon,
} from 'lucide-react'
import { useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { z } from 'zod/v4'
import { useConfirm } from '@/components/spree/confirm-dialog'
import { PageHeader } from '@/components/spree/page-header'
import { RelativeTime } from '@/components/spree/relative-time'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Checkbox } from '@/components/ui/checkbox'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/data-table'
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Empty, EmptyDescription, EmptyHeader, EmptyMedia, EmptyTitle } from '@/components/ui/empty'
import { Field, FieldError, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Skeleton } from '@/components/ui/skeleton'
import { useCopyToClipboard } from '@/hooks/use-copy-to-clipboard'
import {
  useCreateInvitation,
  useDeleteInvitation,
  useInvitations,
  useRemoveStaff,
  useResendInvitation,
  useRoles,
  useStaff,
  useUpdateStaff,
} from '@/hooks/use-staff'
import { mapSpreeErrorsToForm } from '@/lib/form-errors'
import { getInitials } from '@/lib/formatters'

export const Route = createFileRoute('/_authenticated/$storeId/settings/staff')({
  component: StaffSettingsPage,
})

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

function StaffSettingsPage() {
  const { data: staff, isLoading: staffLoading } = useStaff()
  const { data: invitations, isLoading: invitationsLoading } = useInvitations()
  const [inviteOpen, setInviteOpen] = useState(false)

  const pendingInvitations = invitations?.data.filter((i) => i.status === 'pending') ?? []

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title="Staff"
        subtitle="Invite teammates and manage their access to this store."
        actions={
          <Button size="sm" onClick={() => setInviteOpen(true)}>
            <PlusIcon className="size-4" />
            Invite teammate
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
  return (
    <Card>
      <CardHeader>
        <CardTitle>Members</CardTitle>
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
              <EmptyTitle>No staff yet</EmptyTitle>
              <EmptyDescription>
                Invite a teammate to give them access to this store.
              </EmptyDescription>
            </EmptyHeader>
          </Empty>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Member</TableHead>
                <TableHead>Roles</TableHead>
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
  const [editOpen, setEditOpen] = useState(false)
  const removeMutation = useRemoveStaff()
  const confirm = useConfirm()

  const initials = getInitials(member.full_name, member.email)

  async function handleRemove() {
    const ok = await confirm({
      title: 'Remove from store?',
      message: `${member.full_name || member.email} will lose access to this store. Their account stays — they keep access to any other stores they belong to.`,
      variant: 'destructive',
      confirmLabel: 'Remove',
    })
    if (!ok) return

    try {
      await removeMutation.mutateAsync(member.id)
      toast.success('Removed from store')
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to remove staff')
    }
  }

  return (
    <>
      <TableRow>
        <TableCell>
          <div className="flex items-center gap-3">
            <Avatar className="size-8">
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
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button size="icon-sm" variant="ghost" aria-label="Actions">
                <MoreHorizontalIcon className="size-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem onClick={() => setEditOpen(true)}>
                <ShieldIcon className="size-4" />
                Edit roles
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem variant="destructive" onClick={handleRemove}>
                Remove from store
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </TableCell>
      </TableRow>

      <EditStaffDialog open={editOpen} onOpenChange={setEditOpen} member={member} />
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
  return (
    <Card>
      <CardHeader>
        <CardTitle>Pending invitations</CardTitle>
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
                <TableHead>Email</TableHead>
                <TableHead>Role</TableHead>
                <TableHead>Expires</TableHead>
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
    toast.success('Invitation link copied')
  }

  async function handleResend() {
    try {
      await resendMutation.mutateAsync(invitation.id)
      toast.success('Invitation resent')
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to resend invitation')
    }
  }

  async function handleDelete() {
    const ok = await confirm({
      title: 'Revoke invitation?',
      message: `${invitation.email} won't be able to accept this invitation. You can invite them again later.`,
      variant: 'destructive',
      confirmLabel: 'Revoke',
    })
    if (!ok) return

    try {
      await deleteMutation.mutateAsync(invitation.id)
      toast.success('Invitation revoked')
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to revoke invitation')
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
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button size="icon-sm" variant="ghost" aria-label="Actions">
              <MoreHorizontalIcon className="size-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onClick={handleResend}>
              <MailIcon className="size-4" />
              Resend invitation
            </DropdownMenuItem>
            <DropdownMenuItem onClick={handleCopyLink}>
              <LinkIcon className="size-4" />
              Copy invitation link
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem variant="destructive" onClick={handleDelete}>
              Revoke invitation
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </TableCell>
    </TableRow>
  )
}

// ---------------------------------------------------------------------------
// Invite dialog
// ---------------------------------------------------------------------------

const inviteSchema = z.object({
  email: z.string().min(1, 'Email is required').email('Enter a valid email'),
  role_id: z.string().min(1, 'Pick a role'),
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
      toast.success('Invitation sent')
      form.reset({ email: '', role_id: '' })
      onOpenChange(false)
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toast.error(err instanceof Error ? err.message : 'Failed to send invitation')
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
          <DialogTitle>Invite teammate</DialogTitle>
          <DialogDescription>
            We'll email them a sign-up link. They'll get the role you pick here for this store only.
          </DialogDescription>
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
                placeholder="teammate@example.com"
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
                          placeholder={rolesLoading ? 'Loading roles…' : 'Select a role'}
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
              {form.formState.errors.role_id && (
                <p className="text-sm text-destructive">{form.formState.errors.role_id.message}</p>
              )}
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
              Cancel
            </Button>
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting ? 'Sending…' : 'Send invitation'}
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
  role_ids: z.array(z.string()).min(1, 'Pick at least one role'),
})

type EditFormValues = z.infer<typeof editSchema>

function EditStaffDialog({
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
      toast.success('Staff updated')
      onOpenChange(false)
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toast.error(err instanceof Error ? err.message : 'Failed to update staff')
    }
  }

  return (
    <Dialog
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
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Edit staff member</DialogTitle>
          <DialogDescription>{member.email}</DialogDescription>
        </DialogHeader>
        <form onSubmit={form.handleSubmit(onSubmit)}>
          <DialogBody className="flex flex-col gap-4">
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
              <FieldLabel>Roles for this store</FieldLabel>
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
              {form.formState.errors.role_ids && (
                <p className="text-sm text-destructive">{form.formState.errors.role_ids.message}</p>
              )}
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
              Cancel
            </Button>
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting ? 'Saving…' : 'Save'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
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
  function toggle(id: string) {
    onChange(value.includes(id) ? value.filter((v) => v !== id) : [...value, id])
  }

  if (roles.length === 0) {
    return <p className="text-sm text-muted-foreground">No roles available.</p>
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

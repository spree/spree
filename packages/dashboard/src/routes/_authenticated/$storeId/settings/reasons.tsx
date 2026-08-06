import { zodResolver } from '@hookform/resolvers/zod'
import {
  Can,
  mapSpreeErrorsToForm,
  PageHeader,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  ActiveBadge,
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Empty,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RowActions,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Skeleton,
  Switch,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { PlusIcon, RotateCcwIcon, TriangleAlertIcon } from 'lucide-react'
import { useState } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  type Reason,
  type ReasonKind,
  useCreateReason,
  useDeleteReason,
  useReasons,
  useUpdateReason,
} from '../../../../hooks/use-reasons'
import {
  REASON_DEFAULTS,
  type ReasonFormValues,
  reasonFormSchema,
} from '../../../../schemas/reason'

export const Route = createFileRoute('/_authenticated/$storeId/settings/reasons')({
  component: ReasonsPage,
})

/**
 * The three reason lists live on one page rather than three: each is a handful
 * of short rows, and a merchant setting up returns wants to see the whole
 * vocabulary at once. They stay separate lists because they answer different
 * questions — why a customer sent something back, what the merchant got wrong,
 * and why money moved.
 */
const SECTIONS: Array<{ kind: ReasonKind; subject: string; titleKey: string; helpKey: string }> = [
  {
    kind: 'return-reasons',
    subject: Subject.ReturnReason,
    titleKey: 'admin.reasons.return.title',
    helpKey: 'admin.reasons.return.help',
  },
  {
    kind: 'claim-reasons',
    subject: Subject.ClaimReason,
    titleKey: 'admin.reasons.claim.title',
    helpKey: 'admin.reasons.claim.help',
  },
  {
    kind: 'refund-reasons',
    subject: Subject.RefundReason,
    titleKey: 'admin.reasons.refund.title',
    helpKey: 'admin.reasons.refund.help',
  },
]

function ReasonsPage() {
  const { t } = useTranslation()

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title={t('admin.reasons.title')} subtitle={t('admin.reasons.description')} />

      {SECTIONS.map((section) => (
        <ReasonSection key={section.kind} {...section} />
      ))}
    </div>
  )
}

function ReasonSection({
  kind,
  subject,
  titleKey,
  helpKey,
}: {
  kind: ReasonKind
  subject: string
  titleKey: string
  helpKey: string
}) {
  const { t } = useTranslation()
  const { data, isLoading, isError } = useReasons(kind)

  const [creating, setCreating] = useState(false)
  const [editing, setEditing] = useState<Reason | null>(null)

  const reasons = data?.data ?? []

  return (
    <>
      <Card>
        <CardHeader className="flex flex-row items-start justify-between gap-3 space-y-0">
          <div>
            <CardTitle>{t(titleKey)}</CardTitle>
            <p className="mt-1 text-sm text-muted-foreground">{t(helpKey)}</p>
          </div>
          <Can I="create" a={subject}>
            <Button size="sm" onClick={() => setCreating(true)}>
              <PlusIcon className="size-4" />
              {t('admin.reasons.add_cta')}
            </Button>
          </Can>
        </CardHeader>
        <CardContent className="p-0">
          {isLoading ? (
            <div className="p-4">
              <Skeleton className="h-10 w-full" />
            </div>
          ) : isError ? (
            // Distinct from the empty state: "no reasons yet" would tell an
            // admin the list is empty when the request actually failed.
            <Empty>
              <EmptyHeader>
                <EmptyMedia variant="icon">
                  <TriangleAlertIcon />
                </EmptyMedia>
                <EmptyTitle>{t('admin.errors.failed_to_load')}</EmptyTitle>
              </EmptyHeader>
            </Empty>
          ) : reasons.length === 0 ? (
            <Empty>
              <EmptyHeader>
                <EmptyMedia variant="icon">
                  <RotateCcwIcon />
                </EmptyMedia>
                <EmptyTitle>{t('admin.reasons.empty')}</EmptyTitle>
              </EmptyHeader>
            </Empty>
          ) : (
            <Table>
              <TableHeader className="border-b">
                <TableRow>
                  <TableHead>{t('admin.fields.name.label')}</TableHead>
                  <TableHead>{t('admin.fields.status.label')}</TableHead>
                  <TableHead className="w-12" />
                </TableRow>
              </TableHeader>
              <TableBody>
                {reasons.map((reason) => (
                  <ReasonRow
                    key={reason.id}
                    kind={kind}
                    subject={subject}
                    reason={reason}
                    onEdit={setEditing}
                  />
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {creating && <CreateReasonSheet kind={kind} onClose={() => setCreating(false)} />}
      {editing && <EditReasonSheet kind={kind} reason={editing} onClose={() => setEditing(null)} />}
    </>
  )
}

function ReasonRow({
  kind,
  subject,
  reason,
  onEdit,
}: {
  kind: ReasonKind
  subject: string
  reason: Reason
  onEdit: (reason: Reason) => void
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { permissions } = usePermissions()
  const deleteMutation = useDeleteReason(kind)

  async function handleDelete() {
    const ok = await confirm({
      title: t('admin.reasons.delete_confirm.title'),
      message: t('admin.reasons.delete_confirm.message', { name: reason.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(reason.id).catch(() => undefined)
  }

  return (
    <TableRow>
      <TableCell>
        <span className="flex items-center gap-2 font-medium">
          {reason.name}
          {!reason.can_be_deleted && (
            <Badge variant="outline" title={t('admin.reasons.in_use_help')}>
              {t('admin.reasons.in_use')}
            </Badge>
          )}
        </span>
      </TableCell>
      <TableCell>
        <ActiveBadge
          active={reason.active}
          activeLabel={t('admin.fields.active.label')}
          inactiveLabel={t('admin.reasons.inactive')}
        />
      </TableCell>
      <TableCell>
        <RowActions
          actions={[
            {
              key: 'edit',
              visible: permissions.can('update', subject),
              onSelect: () => onEdit(reason),
            },
            {
              key: 'delete',
              destructive: true,
              visible: permissions.can('destroy', subject) && reason.can_be_deleted,
              disabled: deleteMutation.isPending,
              onSelect: handleDelete,
            },
          ]}
        />
      </TableCell>
    </TableRow>
  )
}

function CreateReasonSheet({ kind, onClose }: { kind: ReasonKind; onClose: () => void }) {
  const { t } = useTranslation()
  const createMutation = useCreateReason(kind)
  const form = useForm<ReasonFormValues>({
    resolver: zodResolver(reasonFormSchema),
    defaultValues: REASON_DEFAULTS,
  })

  async function onSubmit(values: ReasonFormValues) {
    try {
      await createMutation.mutateAsync(values)
      onClose()
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet open onOpenChange={(next) => !next && onClose()}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.reasons.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.reasons.create_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <ReasonFormFields form={form} />
          </div>
          <SheetFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={createMutation.isPending}>
              {t('admin.actions.create')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditReasonSheet({
  kind,
  reason,
  onClose,
}: {
  kind: ReasonKind
  reason: Reason
  onClose: () => void
}) {
  const { t } = useTranslation()
  const updateMutation = useUpdateReason(kind, reason.id)
  const form = useForm<ReasonFormValues>({
    resolver: zodResolver(reasonFormSchema),
    defaultValues: { name: reason.name, active: reason.active },
  })

  async function onSubmit(values: ReasonFormValues) {
    try {
      await updateMutation.mutateAsync(values)
      onClose()
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet open onOpenChange={(next) => !next && onClose()}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.reasons.edit_sheet_title')}</SheetTitle>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <ReasonFormFields form={form} />
          </div>
          <SheetFooter>
            <Button type="button" variant="outline" onClick={onClose}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={updateMutation.isPending}>
              {t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function ReasonFormFields({ form }: { form: UseFormReturn<ReasonFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState

  return (
    <FieldGroup>
      {errors.root?.message && (
        <p className="text-sm text-destructive" role="alert">
          {errors.root.message}
        </p>
      )}

      <Field>
        <FieldLabel htmlFor="reason-name">{t('admin.fields.name.label')}</FieldLabel>
        <Input
          id="reason-name"
          aria-invalid={!!errors.name}
          placeholder={t('admin.reasons.name_placeholder')}
          {...form.register('name')}
        />
        {errors.name && <FieldError>{errors.name.message}</FieldError>}
      </Field>

      <Field orientation="horizontal">
        <FieldLabel htmlFor="reason-active">{t('admin.reasons.active_label')}</FieldLabel>
        <Controller
          control={form.control}
          name="active"
          render={({ field }) => (
            <Switch id="reason-active" checked={field.value} onCheckedChange={field.onChange} />
          )}
        />
      </Field>
    </FieldGroup>
  )
}

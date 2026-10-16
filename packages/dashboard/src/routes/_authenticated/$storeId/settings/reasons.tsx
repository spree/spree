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
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RowActions,
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
  Switch,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import { PlusIcon, RotateCcwIcon, TriangleAlertIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute } from '@tanstack/react-router'
import { useState } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  type Reason,
  type ReasonKind,
  type ReasonParams,
  useCreateReason,
  useDeleteReason,
  useReasons,
  useUpdateReason,
} from '../../../../hooks/use-reasons'
import { useTaxProviders } from '../../../../hooks/use-tax-rates'
import {
  REASON_DEFAULTS,
  type ReasonFormValues,
  reasonFormSchema,
  taxExemptionReasonFormSchema,
} from '../../../../schemas/reason'

export const Route = createFileRoute('/_authenticated/$storeId/settings/reasons')({
  component: ReasonsPage,
})

/**
 * The reason lists live on one page rather than four: each is a handful of
 * short rows, and a merchant setting up returns wants to see the whole
 * vocabulary at once. They stay separate lists because they answer different
 * questions — why a customer sent something back, what the merchant got wrong,
 * why money moved, and why an order never shipped at all.
 */
interface SectionConfig {
  kind: ReasonKind
  subject: string
  titleKey: string
  helpKey: string
  /** Tax exemption reasons carry the code a tax engine reads beside their name. */
  withCode?: boolean
}

const SECTIONS: SectionConfig[] = [
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
  {
    kind: 'order-cancellation-reasons',
    subject: Subject.OrderCancellationReason,
    titleKey: 'admin.reasons.order_cancellation.title',
    helpKey: 'admin.reasons.order_cancellation.help',
  },
  {
    kind: 'tax-exemption-reasons',
    subject: Subject.TaxExemptionReason,
    titleKey: 'admin.reasons.tax_exemption.title',
    helpKey: 'admin.reasons.tax_exemption.help',
    withCode: true,
  },
]

/** A reason's code only when its list carries one, so the others send what they accept. */
function reasonParams(values: ReasonFormValues, withCode: boolean): ReasonParams {
  const { code, ...rest } = values
  return withCode ? { ...rest, code: code?.trim() } : rest
}

/** The code a reason in the table shows, for the one list that has them. */
function reasonCode(reason: Reason): string | undefined {
  return 'code' in reason ? reason.code : undefined
}

function ReasonsPage() {
  const { t } = useTranslation()

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={t('admin.reasons.title')}
        description={t('admin.reasons.description')}
        docsPath="settings/returns-configuration"
      />

      {SECTIONS.map((section) => (
        <ReasonSection key={section.kind} {...section} />
      ))}
    </div>
  )
}

function ReasonSection({ kind, subject, titleKey, helpKey, withCode = false }: SectionConfig) {
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
              <TableHeader>
                <TableRow>
                  <TableHead>{t('admin.fields.name.label')}</TableHead>
                  {withCode && <TableHead>{t('admin.fields.code.label')}</TableHead>}
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
                    withCode={withCode}
                    onEdit={setEditing}
                  />
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {creating && (
        <CreateReasonSheet kind={kind} withCode={withCode} onClose={() => setCreating(false)} />
      )}
      {editing && (
        <EditReasonSheet
          kind={kind}
          reason={editing}
          withCode={withCode}
          onClose={() => setEditing(null)}
        />
      )}
    </>
  )
}

function ReasonRow({
  kind,
  subject,
  reason,
  withCode,
  onEdit,
}: {
  kind: ReasonKind
  subject: string
  reason: Reason
  withCode: boolean
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
      {withCode && (
        <TableCell>
          <code className="text-sm">{reasonCode(reason)}</code>
        </TableCell>
      )}
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

function CreateReasonSheet({
  kind,
  withCode,
  onClose,
}: {
  kind: ReasonKind
  withCode: boolean
  onClose: () => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateReason(kind)
  const form = useForm<ReasonFormValues>({
    resolver: zodResolver(withCode ? taxExemptionReasonFormSchema : reasonFormSchema),
    defaultValues: REASON_DEFAULTS,
  })

  async function onSubmit(values: ReasonFormValues) {
    try {
      await createMutation.mutateAsync(reasonParams(values, withCode))
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
            <ReasonFormFields form={form} withCode={withCode} />
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
  withCode,
  onClose,
}: {
  kind: ReasonKind
  reason: Reason
  withCode: boolean
  onClose: () => void
}) {
  const { t } = useTranslation()
  const updateMutation = useUpdateReason(kind, reason.id)
  const form = useForm<ReasonFormValues>({
    resolver: zodResolver(withCode ? taxExemptionReasonFormSchema : reasonFormSchema),
    defaultValues: { name: reason.name, active: reason.active, code: reasonCode(reason) ?? '' },
  })

  async function onSubmit(values: ReasonFormValues) {
    try {
      await updateMutation.mutateAsync(reasonParams(values, withCode))
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
            <ReasonFormFields
              form={form}
              withCode={withCode}
              // Certificates hold the code itself, so one in use cannot change.
              codeLocked={!reason.can_be_deleted}
            />
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

function ReasonFormFields({
  form,
  withCode,
  codeLocked = false,
}: {
  form: UseFormReturn<ReasonFormValues>
  withCode: boolean
  codeLocked?: boolean
}) {
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

      {withCode && <ReasonCodeField form={form} locked={codeLocked} />}

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

/**
 * The code a tax exemption reason records. Where a connected tax engine reads
 * codes (Avalara's entity use codes), the merchant picks one of those, since
 * any other is sent as a catch-all; otherwise the code is the merchant's own.
 */
function ReasonCodeField({
  form,
  locked,
}: {
  form: UseFormReturn<ReasonFormValues>
  locked: boolean
}) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const { data } = useTaxProviders()

  const engineCodes = (data?.data ?? [])
    .filter((provider) => provider.available && provider.exemption_reason_codes?.length)
    .flatMap((provider) => provider.exemption_reason_codes ?? [])
  const help = locked
    ? t('admin.reasons.code_locked_help')
    : engineCodes.length
      ? t('admin.reasons.code_engine_help')
      : t('admin.reasons.code_help')

  return (
    <Field>
      <FieldLabel htmlFor="reason-code">{t('admin.fields.code.label')}</FieldLabel>
      {engineCodes.length ? (
        <Controller
          control={form.control}
          name="code"
          render={({ field }) => {
            // A code recorded before the engine was connected stays selectable
            // rather than being silently replaced by the first option.
            const items = engineCodes.some((code) => code.value === field.value)
              ? engineCodes
              : field.value
                ? [{ value: field.value, label: field.value }, ...engineCodes]
                : engineCodes
            const options = items.map((code) => ({
              value: code.value,
              label: code.value === code.label ? code.value : `${code.value} — ${code.label}`,
            }))
            return (
              <Select
                items={options}
                value={field.value ?? ''}
                onValueChange={(next) => field.onChange(next ?? '')}
                disabled={locked}
              >
                <SelectTrigger id="reason-code" aria-invalid={!!errors.code}>
                  <SelectValue placeholder={t('admin.reasons.code_placeholder')} />
                </SelectTrigger>
                <SelectContent>
                  {options.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )
          }}
        />
      ) : (
        <Input
          id="reason-code"
          aria-invalid={!!errors.code}
          disabled={locked}
          placeholder={t('admin.reasons.code_placeholder')}
          {...form.register('code')}
        />
      )}
      <FieldDescription>{help}</FieldDescription>
      {errors.code && <FieldError>{errors.code.message}</FieldError>}
    </Field>
  )
}

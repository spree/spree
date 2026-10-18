import { zodResolver } from '@hookform/resolvers/zod'
import { Can, mapSpreeErrorsToForm, Subject, usePermissions } from '@spree/dashboard-core'
import {
  ActiveBadge,
  Badge,
  Button,
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
  Switch,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import { PlusIcon, RotateCcwIcon } from '@spree/dashboard-ui/icons'
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
} from '../../../hooks/use-reasons'
import { useTaxProviders } from '../../../hooks/use-tax-rates'
import {
  REASON_DEFAULTS,
  type ReasonFormValues,
  reasonFormSchema,
  taxExemptionReasonFormSchema,
} from '../../../schemas/reason'
import { SettingsListCard } from '../settings-list-card'
import { useMarketTaxProviders } from '../taxes/market-tax-providers'

/** One reason list: which kind, who may manage it, and how its card reads. */
export interface SectionConfig {
  kind: ReasonKind
  subject: string
  titleKey: string
  helpKey: string
  /** Tax exemption reasons carry the code a tax engine reads beside their name. */
  withCode?: boolean
}

/** A reason's code only when its list carries one, so the others send what they accept. */
function reasonParams(values: ReasonFormValues, withCode: boolean): ReasonParams {
  const { code, ...rest } = values
  return withCode ? { ...rest, code: code?.trim() } : rest
}

/** The code a reason in the table shows, for the one list that has them. */
function reasonCode(reason: Reason): string | undefined {
  return 'code' in reason ? reason.code : undefined
}

/** One reason list as a card: its rows, and the sheets that add and edit them. */
export function ReasonSection({
  kind,
  subject,
  titleKey,
  helpKey,
  withCode = false,
}: SectionConfig) {
  const { t } = useTranslation()
  const { data, isLoading, isError } = useReasons(kind)

  const [creating, setCreating] = useState(false)
  const [editing, setEditing] = useState<Reason | null>(null)

  const reasons = data?.data ?? []

  return (
    <>
      <SettingsListCard
        title={t(titleKey)}
        description={t(helpKey)}
        action={
          <Can I="create" a={subject}>
            <Button size="sm" onClick={() => setCreating(true)}>
              <PlusIcon className="size-4" />
              {t('admin.reasons.add_cta')}
            </Button>
          </Can>
        }
        isLoading={isLoading}
        isError={isError}
        isEmpty={reasons.length === 0}
        emptyIcon={<RotateCcwIcon />}
        emptyTitle={t('admin.reasons.empty')}
      >
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
      </SettingsListCard>

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
          <SheetDescription>
            {t(
              withCode
                ? 'admin.reasons.tax_exemption.create_description'
                : 'admin.reasons.create_description',
            )}
          </SheetDescription>
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
            <ReasonFormFields form={form} withCode={withCode} />
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
}: {
  form: UseFormReturn<ReasonFormValues>
  withCode: boolean
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
          placeholder={t(
            withCode
              ? 'admin.reasons.tax_exemption.name_placeholder'
              : 'admin.reasons.name_placeholder',
          )}
          {...form.register('name')}
        />
        {errors.name && <FieldError>{errors.name.message}</FieldError>}
      </Field>

      {withCode && <ReasonCodeField form={form} />}

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
function ReasonCodeField({ form }: { form: UseFormReturn<ReasonFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const { data } = useTaxProviders()
  const { permissions } = usePermissions()
  const marketProviders = useMarketTaxProviders()
  // Only engines a market actually taxes with: a store that has Avalara set
  // up but still taxes every market itself keeps free-text codes. Staff who
  // cannot see markets fall back to every engine the store has set up.
  const usedProviderIds = permissions.can('read', Subject.Market)
    ? new Set(marketProviders.map((group) => group.providerId))
    : null

  // Engines may share a code; each is offered once.
  const engineCodes = [
    ...new Map(
      (data?.data ?? [])
        .filter((provider) => provider.available)
        .filter((provider) => !usedProviderIds || usedProviderIds.has(provider.id))
        .flatMap((provider) => provider.exemption_reason_codes ?? [])
        .map((code) => [code.value, code]),
    ).values(),
  ]
  const codeInput = form.register('code')
  const help = engineCodes.length
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
          placeholder={t('admin.reasons.code_placeholder')}
          {...codeInput}
          onChange={(event) => {
            // Codes are saved in capitals, so show them that way while typing.
            const input = event.target
            const { selectionStart, selectionEnd } = input
            input.value = input.value.toUpperCase()
            input.setSelectionRange(selectionStart, selectionEnd)
            codeInput.onChange(event)
          }}
        />
      )}
      <FieldDescription>{help}</FieldDescription>
      {errors.code && <FieldError>{errors.code.message}</FieldError>}
    </Field>
  )
}

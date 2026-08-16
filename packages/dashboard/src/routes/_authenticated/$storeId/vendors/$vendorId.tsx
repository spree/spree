import { zodResolver } from '@hookform/resolvers/zod'
import type { Vendor } from '@spree/admin-sdk'
import {
  mapSpreeErrorsToForm,
  PageHeader,
  Slot,
  StoreDatePicker,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  DropdownMenuItem,
  ErrorState,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RelativeTime,
  ResourceLayout,
  RichTextEditor,
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
  StatusBadge,
  useConfirm,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import {
  BanIcon,
  MailIcon,
  PackageIcon,
  PauseIcon,
  PencilIcon,
  StoreIcon,
  UsersIcon,
} from 'lucide-react'
import { type ReactNode, useEffect, useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { ResourceImageField } from '../../../../components/spree/resource-image-field'
import {
  useApproveVendor,
  useDeleteVendor,
  useInviteVendor,
  useRejectVendor,
  useSuspendVendor,
  useUpdateVendor,
  useVendor,
} from '../../../../hooks/use-vendors'
import {
  PAYOUT_INTERVALS,
  TAX_REMITTANCES,
  VENDOR_DEFAULTS,
  type VendorFormValues,
  type VendorInviteValues,
  vendorFormSchema,
  vendorImageParams,
  vendorInviteSchema,
  vendorValuesToParams,
} from '../../../../schemas/vendor'

export const Route = createFileRoute('/_authenticated/$storeId/vendors/$vendorId')({
  component: VendorDetailPage,
})

function VendorDetailPage() {
  const { t } = useTranslation()
  const { vendorId } = Route.useParams()
  const { data: vendor, isLoading, error, refetch } = useVendor(vendorId)

  if (isLoading) return <p className="text-muted-foreground">{t('admin.common.loading')}</p>
  if (error || !vendor) {
    return (
      <ErrorState
        title={t('admin.vendors.detail.load_error')}
        error={error as Error | undefined}
        onRetry={() => refetch()}
      />
    )
  }

  return <VendorBody vendor={vendor} />
}

/**
 * A vendor's page is something you read first. The lifecycle sits in the
 * header, the profile below it, and every editable section opens its own
 * sheet — so arriving here shows you who the seller is rather than dropping
 * you into a form.
 */
function VendorBody({ vendor }: { vendor: Vendor }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const { permissions } = usePermissions()
  const confirm = useConfirm()
  const deleteMutation = useDeleteVendor()

  const [editingProfile, setEditingProfile] = useState(false)
  const [editingSettlement, setEditingSettlement] = useState(false)
  const [inviting, setInviting] = useState(false)

  const approveMutation = useApproveVendor(vendor.id)
  const suspendMutation = useSuspendVendor(vendor.id)
  const rejectMutation = useRejectVendor(vendor.id)

  const canEdit = permissions.can('update', Subject.Vendor)
  const status = vendor.status

  // Mirrors the workflow guards, so the operator is never offered a move the
  // server would refuse.
  const canInvite = ['pending', 'invited', 'canceled'].includes(status)
  const canApprove = ['onboarding', 'ready_for_review', 'suspended', 'rejected'].includes(status)
  const canSuspend = ['approved', 'onboarding', 'ready_for_review'].includes(status)
  const canReject = ['pending', 'invited', 'onboarding', 'ready_for_review'].includes(status)

  const busy =
    approveMutation.isPending || suspendMutation.isPending || rejectMutation.isPending || !canEdit

  async function handleDelete() {
    await deleteMutation.mutateAsync(vendor.id)
    navigate({ to: '/$storeId/vendors', params: { storeId } })
  }

  async function handleSuspend() {
    const ok = await confirm({
      title: t('admin.vendors.suspend_confirm.title'),
      message: t('admin.vendors.suspend_confirm.message', { name: vendor.name }),
      variant: 'destructive',
      confirmLabel: t('admin.vendors.actions.suspend'),
    })
    if (!ok) return
    await suspendMutation.mutateAsync(undefined).catch(() => undefined)
  }

  async function handleReject() {
    const ok = await confirm({
      title: t('admin.vendors.reject_confirm.title'),
      message: t('admin.vendors.reject_confirm.message', { name: vendor.name }),
      variant: 'destructive',
      confirmLabel: t('admin.vendors.actions.reject'),
    })
    if (!ok) return
    await rejectMutation.mutateAsync(undefined).catch(() => undefined)
  }

  // Approving is the move an operator comes here to make, so it is the button;
  // the rest live in the dropdown beside it.
  const primaryAction = canEdit ? (
    <>
      {canApprove && (
        <Button
          size="sm"
          disabled={busy}
          // The hook already surfaces the failure; catching keeps a rejected
          // request from also becoming an unhandled promise rejection, as the
          // suspend and reject handlers do.
          onClick={() => approveMutation.mutateAsync().catch(() => undefined)}
        >
          {status === 'suspended'
            ? t('admin.vendors.actions.reinstate')
            : t('admin.vendors.actions.approve')}
        </Button>
      )}
      {canInvite && (
        <Button
          size="sm"
          variant={canApprove ? 'outline' : 'default'}
          disabled={busy}
          onClick={() => setInviting(true)}
        >
          <MailIcon className="size-4" />
          {status === 'invited'
            ? t('admin.vendors.actions.reinvite')
            : t('admin.vendors.actions.invite')}
        </Button>
      )}
    </>
  ) : null

  const dropdownItems = canEdit ? (
    <>
      {canSuspend && (
        <DropdownMenuItem onClick={handleSuspend}>
          <PauseIcon className="size-4" />
          {t('admin.vendors.actions.suspend')}
        </DropdownMenuItem>
      )}
      {canReject && (
        <DropdownMenuItem onClick={handleReject}>
          <BanIcon className="size-4" />
          {t('admin.vendors.actions.reject')}
        </DropdownMenuItem>
      )}
    </>
  ) : null

  return (
    <>
      <ResourceLayout
        header={
          <PageHeader
            title={vendor.name}
            subtitle={vendor.contact_email ?? undefined}
            backTo="vendors"
            badges={<StatusBadge status={status} label={t(`admin.vendors.status.${status}`)} />}
            actions={primaryAction}
            dropdownItems={dropdownItems}
            resource={{ id: vendor.id }}
            onDelete={permissions.can('destroy', Subject.Vendor) ? handleDelete : undefined}
            deleteLabel={t('admin.vendors.detail.delete_label')}
          />
        }
        main={
          <>
            <VendorBrandCard
              vendor={vendor}
              canEdit={canEdit}
              onEdit={() => setEditingProfile(true)}
            />
            <Slot name="vendor.form_main" context={{ vendor, canEdit }} />
          </>
        }
        sidebar={
          <>
            <VendorStatusCard vendor={vendor} />
            <VendorAtAGlanceCard vendor={vendor} />
            <VendorContactCard vendor={vendor} />
            <VendorSettlementCard
              vendor={vendor}
              canEdit={canEdit}
              onEdit={() => setEditingSettlement(true)}
            />
            <Slot name="vendor.form_sidebar" context={{ vendor, canEdit }} />
          </>
        }
      />

      <EditProfileSheet vendor={vendor} open={editingProfile} onOpenChange={setEditingProfile} />
      <EditSettlementSheet
        vendor={vendor}
        open={editingSettlement}
        onOpenChange={setEditingSettlement}
      />
      {inviting && <InviteVendorSheet vendor={vendor} open onOpenChange={setInviting} />}
    </>
  )
}

/** One labelled value in a sidebar card, with a placeholder when unset. */
function ReadRow({ label, children }: { label: string; children: ReactNode }) {
  const { t } = useTranslation()
  return (
    <div className="flex items-start justify-between gap-3 text-sm">
      <span className="text-muted-foreground">{label}</span>
      <span className="text-right">
        {children ?? (
          <span className="text-muted-foreground">{t('admin.vendors.not_provided')}</span>
        )}
      </span>
    </div>
  )
}

/** Cover photo, logo and the seller's own description — the storefront face. */
function VendorBrandCard({
  vendor,
  canEdit,
  onEdit,
}: {
  vendor: Vendor
  canEdit: boolean
  onEdit: () => void
}) {
  const { t } = useTranslation()

  return (
    <Card className="overflow-hidden">
      {/* A vendor with no cover gets a slim band rather than a tall empty
          block. It uses --accent rather than --muted: muted is a deliberate
          "whisper" against white, which over a region this size disappears
          entirely and leaves the logo looking unanchored. */}
      <div className="relative">
        {vendor.cover_photo_url ? (
          <img src={vendor.cover_photo_url} alt="" className="h-40 w-full bg-accent object-cover" />
        ) : (
          <div className="h-20 w-full border-border border-b bg-accent" />
        )}
        {canEdit && (
          <Button size="sm" variant="outline" className="absolute top-3 right-3" onClick={onEdit}>
            <PencilIcon className="size-4" />
            {t('admin.actions.edit')}
          </Button>
        )}
      </div>

      {/* The logo straddles the band, so it needs more inset than CardContent's
          own padding gives — otherwise an 80px tile pulled up over a slim band
          reads as hanging off the card's corner. */}
      <CardContent className="flex flex-col gap-4 px-5 pb-5">
        {/* Positioned with its own z-index: the band above is `relative`, so a
            plain sibling paints underneath it and the band's edge cuts across
            the tile. The border belongs on the tile itself rather than a ring
            outside it, which over the band reads as a halo. */}
        <div className="-mt-10 relative z-10 flex size-20 items-center justify-center overflow-hidden rounded-xl border border-border bg-card shadow-sm">
          {/* The square logo is the one cropped for a tile like this; the main
              logo is the fallback, since a vendor may have set only one. */}
          {vendor.square_logo_url || vendor.logo_url ? (
            <img
              src={vendor.square_logo_url ?? vendor.logo_url ?? undefined}
              alt=""
              className="size-full object-cover"
            />
          ) : (
            <StoreIcon className="size-7 text-muted-foreground" />
          )}
        </div>

        {/* The name already sits in the page header; repeating it here would
            just be the same words twice. The handle is what the header lacks. */}
        <p className="text-muted-foreground text-sm">/{vendor.slug}</p>

        {vendor.about_html ? (
          // Server-sanitized on every write path (Spree::RichTextSanitizer),
          // which is what makes rendering it here safe.
          <div
            className="prose prose-sm max-w-none dark:prose-invert"
            // biome-ignore lint/security/noDangerouslySetInnerHtml: sanitized server-side
            dangerouslySetInnerHTML={{ __html: vendor.about_html }}
          />
        ) : (
          <p className="text-muted-foreground text-sm">{t('admin.vendors.detail.no_about')}</p>
        )}
      </CardContent>
    </Card>
  )
}

/** Where the vendor is, and what that means in plain words. */
function VendorStatusCard({ vendor }: { vendor: Vendor }) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.vendors.detail.status')}</CardTitle>
        <CardAction>
          <StatusBadge status={vendor.status} label={t(`admin.vendors.status.${vendor.status}`)} />
        </CardAction>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        <p className="text-muted-foreground text-sm">
          {t(`admin.vendors.status_help.${vendor.status}`, {
            defaultValue: t('admin.vendors.status_help.pending'),
          })}
        </p>
        {vendor.on_holiday && (
          <p className="text-muted-foreground text-sm">{t('admin.vendors.on_holiday_notice')}</p>
        )}
      </CardContent>
    </Card>
  )
}

/** The counts an operator scans for before opening anything else. */
function VendorAtAGlanceCard({ vendor }: { vendor: Vendor }) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.vendors.detail.at_a_glance')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <div className="flex items-center justify-between text-sm">
          <span className="flex items-center gap-2 text-muted-foreground">
            <PackageIcon className="size-4" />
            {t('admin.vendors.products_column')}
          </span>
          <span>{vendor.products_count}</span>
        </div>
        <div className="flex items-center justify-between text-sm">
          <span className="flex items-center gap-2 text-muted-foreground">
            <UsersIcon className="size-4" />
            {t('admin.vendors.team_column')}
          </span>
          <span>{vendor.users_count}</span>
        </div>
        <ReadRow label={t('admin.fields.created_at.label')}>
          <RelativeTime iso={vendor.created_at} />
        </ReadRow>
      </CardContent>
    </Card>
  )
}

function VendorContactCard({ vendor }: { vendor: Vendor }) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.vendors.detail.contact')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <ReadRow label={t('admin.fields.contact_email.label')}>
          {vendor.contact_email ? (
            <a href={`mailto:${vendor.contact_email}`}>{vendor.contact_email}</a>
          ) : null}
        </ReadRow>
        <ReadRow label={t('admin.fields.vendor.billing_email.label')}>
          {vendor.billing_email ? (
            <a href={`mailto:${vendor.billing_email}`}>{vendor.billing_email}</a>
          ) : null}
        </ReadRow>
      </CardContent>
    </Card>
  )
}

/** Operator-only: how and when this vendor gets paid, and who remits tax. */
function VendorSettlementCard({
  vendor,
  canEdit,
  onEdit,
}: {
  vendor: Vendor
  canEdit: boolean
  onEdit: () => void
}) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.vendors.detail.settlement')}</CardTitle>
        {canEdit && (
          <CardAction>
            <Button size="sm" variant="outline" onClick={onEdit}>
              <PencilIcon className="size-4" />
              {t('admin.actions.edit')}
            </Button>
          </CardAction>
        )}
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <ReadRow label={t('admin.fields.vendor.tax_remittance.label')}>
          {t(`admin.vendors.tax_remittance.${vendor.tax_remittance}`, {
            defaultValue: vendor.tax_remittance,
          })}
        </ReadRow>
        <ReadRow label={t('admin.fields.vendor.payouts_schedule_interval.label')}>
          {vendor.payouts_schedule_interval
            ? t(`admin.vendors.payout_interval.${vendor.payouts_schedule_interval}`)
            : t('admin.vendors.payout_interval.inherit')}
        </ReadRow>
        <ReadRow label={t('admin.fields.vendor.minimum_payout_amount.label')}>
          {vendor.minimum_payout_amount}
        </ReadRow>
        <ReadRow label={t('admin.fields.vendor.holiday_mode_until.label')}>
          {vendor.holiday_mode_until ? <RelativeTime iso={vendor.holiday_mode_until} /> : null}
        </ReadRow>
      </CardContent>
    </Card>
  )
}

/** The profile the vendor also maintains from their own panel. */
function EditProfileSheet({
  vendor,
  open,
  onOpenChange,
}: {
  vendor: Vendor
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const updateMutation = useUpdateVendor(vendor.id)

  const form = useForm<VendorFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(vendorFormSchema) as any,
    defaultValues: VENDOR_DEFAULTS,
  })

  // The sheet stays mounted across opens, so re-seed from the latest record
  // each time it opens rather than only on first mount.
  useEffect(() => {
    if (!open) return

    // Images reset to the empty triple: the persisted ones are passed to the
    // field as `serverUrl`, and the triple only carries what the operator
    // changes this time round.
    form.reset({
      ...VENDOR_DEFAULTS,
      name: vendor.name,
      slug: vendor.slug,
      contact_email: vendor.contact_email ?? '',
      billing_email: vendor.billing_email ?? '',
      about: vendor.about_html ?? '',
    })
  }, [open, vendor, form])

  async function onSubmit(values: VendorFormValues) {
    try {
      // Only this sheet's own fields — the settlement sheet owns the rest, and
      // sending them here would post this form's untouched defaults over them.
      const params = vendorValuesToParams(values)
      await updateMutation.mutateAsync({
        ...vendorImageParams(values),
        name: params.name,
        slug: params.slug,
        contact_email: params.contact_email,
        billing_email: params.billing_email,
        about: params.about,
      })
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const { errors } = form.formState

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.vendors.detail.edit_profile')}</SheetTitle>
          <SheetDescription>{t('admin.vendors.detail.edit_profile_description')}</SheetDescription>
        </SheetHeader>
        <form
          onSubmit={(event) => {
            form.handleSubmit(onSubmit)(event)
            event.stopPropagation()
          }}
          className="flex min-h-0 flex-1 flex-col"
        >
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <FieldGroup>
              {errors.root?.message && (
                <p className="text-destructive text-sm" role="alert">
                  {errors.root.message}
                </p>
              )}
              <ResourceImageField
                form={form}
                kind="logo"
                serverUrl={vendor.logo_url}
                square
                translationNamespace="admin.vendors"
                labelKey="logo_label"
                helpKey="logo_help"
              />
              <ResourceImageField
                form={form}
                kind="square_logo"
                serverUrl={vendor.square_logo_url}
                square
                translationNamespace="admin.vendors"
                labelKey="square_logo_label"
                helpKey="square_logo_help"
              />
              <ResourceImageField
                form={form}
                kind="cover_photo"
                serverUrl={vendor.cover_photo_url}
                translationNamespace="admin.vendors"
                labelKey="cover_photo_label"
                helpKey="cover_photo_help"
              />

              <Field>
                <FieldLabel htmlFor="vendor-name">{t('admin.fields.name.label')}</FieldLabel>
                <Input
                  id="vendor-name"
                  aria-invalid={!!errors.name || undefined}
                  {...form.register('name')}
                />
                <FieldError errors={[errors.name]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="vendor-slug">{t('admin.fields.slug.label')}</FieldLabel>
                <Input
                  id="vendor-slug"
                  aria-invalid={!!errors.slug || undefined}
                  {...form.register('slug')}
                />
                <FieldDescription>{t('admin.fields.vendor.slug.help')}</FieldDescription>
                <FieldError errors={[errors.slug]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="vendor-contact-email">
                  {t('admin.fields.contact_email.label')}
                </FieldLabel>
                <Input
                  id="vendor-contact-email"
                  type="email"
                  aria-invalid={!!errors.contact_email || undefined}
                  {...form.register('contact_email')}
                />
                <FieldDescription>{t('admin.fields.vendor.contact_email.help')}</FieldDescription>
                <FieldError errors={[errors.contact_email]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="vendor-billing-email">
                  {t('admin.fields.vendor.billing_email.label')}
                </FieldLabel>
                <Input
                  id="vendor-billing-email"
                  type="email"
                  aria-invalid={!!errors.billing_email || undefined}
                  {...form.register('billing_email')}
                />
                <FieldDescription>{t('admin.fields.vendor.billing_email.help')}</FieldDescription>
                <FieldError errors={[errors.billing_email]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="vendor-about">
                  {t('admin.fields.vendor.about.label')}
                </FieldLabel>
                <Controller
                  control={form.control}
                  name="about"
                  render={({ field }) => (
                    <RichTextEditor
                      id="vendor-about"
                      ariaLabel={t('admin.fields.vendor.about.label')}
                      value={field.value ?? ''}
                      onChange={field.onChange}
                    />
                  )}
                />
                <FieldDescription>{t('admin.fields.vendor.about.help')}</FieldDescription>
              </Field>
            </FieldGroup>
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
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditSettlementSheet({
  vendor,
  open,
  onOpenChange,
}: {
  vendor: Vendor
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const updateMutation = useUpdateVendor(vendor.id)

  const form = useForm<VendorFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(vendorFormSchema) as any,
    defaultValues: VENDOR_DEFAULTS,
  })

  useEffect(() => {
    if (!open) return

    form.reset({
      ...VENDOR_DEFAULTS,
      // Carried so the schema's required `name` still validates; the submit
      // below sends only this sheet's own fields.
      name: vendor.name,
      tax_remittance: (vendor.tax_remittance ?? 'vendor') as VendorFormValues['tax_remittance'],
      payouts_schedule_interval: (vendor.payouts_schedule_interval ??
        '') as VendorFormValues['payouts_schedule_interval'],
      minimum_payout_amount: vendor.minimum_payout_amount ?? '',
      holiday_mode_until: vendor.holiday_mode_until ?? '',
    })
  }, [open, vendor, form])

  async function onSubmit(values: VendorFormValues) {
    try {
      const params = vendorValuesToParams(values)
      await updateMutation.mutateAsync({
        tax_remittance: params.tax_remittance,
        payouts_schedule_interval: params.payouts_schedule_interval,
        minimum_payout_amount: params.minimum_payout_amount,
        holiday_mode_until: params.holiday_mode_until,
      })
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const { errors } = form.formState

  const remittanceOptions = TAX_REMITTANCES.map((value) => ({
    value,
    label: t(`admin.vendors.tax_remittance.${value}`),
  }))
  const intervalOptions = [
    { value: '', label: t('admin.vendors.payout_interval.inherit') },
    ...PAYOUT_INTERVALS.map((value) => ({
      value,
      label: t(`admin.vendors.payout_interval.${value}`),
    })),
  ]

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.vendors.detail.edit_settlement')}</SheetTitle>
          <SheetDescription>
            {t('admin.vendors.detail.edit_settlement_description')}
          </SheetDescription>
        </SheetHeader>
        <form
          onSubmit={(event) => {
            form.handleSubmit(onSubmit)(event)
            event.stopPropagation()
          }}
          className="flex min-h-0 flex-1 flex-col"
        >
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <FieldGroup>
              {errors.root?.message && (
                <p className="text-destructive text-sm" role="alert">
                  {errors.root.message}
                </p>
              )}

              <Field>
                <FieldLabel htmlFor="tax_remittance">
                  {t('admin.fields.vendor.tax_remittance.label')}
                </FieldLabel>
                <Controller
                  name="tax_remittance"
                  control={form.control}
                  render={({ field }) => (
                    <Select
                      items={remittanceOptions}
                      value={field.value ?? 'vendor'}
                      onValueChange={field.onChange}
                    >
                      <SelectTrigger id="tax_remittance" className="w-full">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {remittanceOptions.map((option) => (
                          <SelectItem key={option.value} value={option.value}>
                            {option.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                />
                <FieldDescription>{t('admin.fields.vendor.tax_remittance.help')}</FieldDescription>
              </Field>

              <Field>
                <FieldLabel htmlFor="payouts_schedule_interval">
                  {t('admin.fields.vendor.payouts_schedule_interval.label')}
                </FieldLabel>
                <Controller
                  name="payouts_schedule_interval"
                  control={form.control}
                  render={({ field }) => (
                    <Select
                      items={intervalOptions}
                      value={field.value ?? ''}
                      onValueChange={field.onChange}
                    >
                      <SelectTrigger id="payouts_schedule_interval" className="w-full">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {intervalOptions.map((option) => (
                          <SelectItem key={option.value || 'inherit'} value={option.value}>
                            {option.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                />
                <FieldDescription>
                  {t('admin.fields.vendor.payouts_schedule_interval.help')}
                </FieldDescription>
              </Field>

              <Field>
                <FieldLabel htmlFor="minimum_payout_amount">
                  {t('admin.fields.vendor.minimum_payout_amount.label')}
                </FieldLabel>
                <Input
                  id="minimum_payout_amount"
                  inputMode="decimal"
                  aria-invalid={!!errors.minimum_payout_amount || undefined}
                  {...form.register('minimum_payout_amount')}
                />
                <FieldDescription>
                  {t('admin.fields.vendor.minimum_payout_amount.help')}
                </FieldDescription>
                <FieldError errors={[errors.minimum_payout_amount]} />
              </Field>

              <Field>
                <FieldLabel>{t('admin.fields.vendor.holiday_mode_until.label')}</FieldLabel>
                <Controller
                  name="holiday_mode_until"
                  control={form.control}
                  render={({ field }) => (
                    <StoreDatePicker
                      value={field.value || null}
                      onChange={(next) => field.onChange(next ?? '')}
                      placeholder={t('admin.fields.vendor.holiday_mode_until.placeholder')}
                      includeTime
                      inline
                    />
                  )}
                />
                <FieldDescription>
                  {t('admin.fields.vendor.holiday_mode_until.help')}
                </FieldDescription>
              </Field>
            </FieldGroup>
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
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function InviteVendorSheet({
  vendor,
  open,
  onOpenChange,
}: {
  vendor: Vendor
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const inviteMutation = useInviteVendor(vendor.id)
  const form = useForm<VendorInviteValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(vendorInviteSchema) as any,
    defaultValues: { email: vendor.contact_email ?? '' },
  })

  async function onSubmit(values: VendorInviteValues) {
    try {
      await inviteMutation.mutateAsync(values)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const { errors } = form.formState

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.vendors.invite_sheet.title')}</SheetTitle>
          <SheetDescription>{t('admin.vendors.invite_sheet.description')}</SheetDescription>
        </SheetHeader>
        <form
          onSubmit={(event) => {
            // This sheet renders inside the detail page's own tree; without
            // stopping the bubble the browser would submit an outer form.
            form.handleSubmit(onSubmit)(event)
            event.stopPropagation()
          }}
          className="flex min-h-0 flex-1 flex-col"
        >
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <FieldGroup>
              {errors.root?.message && (
                <p className="text-destructive text-sm" role="alert">
                  {errors.root.message}
                </p>
              )}
              <Field>
                <FieldLabel htmlFor="invite-email">{t('admin.fields.email.label')}</FieldLabel>
                <Input
                  id="invite-email"
                  type="email"
                  autoFocus
                  aria-invalid={!!errors.email || undefined}
                  {...form.register('email')}
                />
                <FieldDescription>{t('admin.vendors.invite_sheet.email_help')}</FieldDescription>
                <FieldError errors={[errors.email]} />
              </Field>
            </FieldGroup>
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
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting
                ? t('admin.actions.saving')
                : t('admin.vendors.actions.send_invitation')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

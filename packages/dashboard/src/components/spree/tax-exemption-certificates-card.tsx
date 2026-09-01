import { zodResolver } from '@hookform/resolvers/zod'
import type { TaxExemptionCertificate } from '@spree/admin-sdk'
import {
  CountryCombobox,
  downloadFromApi,
  FileUploadField,
  formatFileSize,
  mapSpreeErrorsToForm,
  StateCombobox,
  StoreDatePicker,
  useAuth,
  useCountryStates,
  useStore,
} from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Combobox,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxInput,
  ComboboxItem,
  ComboboxList,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  StatusBadge,
  useConfirm,
} from '@spree/dashboard-ui'
import {
  BadgeCheckIcon,
  BanIcon,
  DownloadIcon,
  EllipsisVerticalIcon,
  PaperclipIcon,
  PlusIcon,
  TrashIcon,
} from '@spree/dashboard-ui/icons'
import { parseISO } from 'date-fns'
import { formatInTimeZone } from 'date-fns-tz'
import { useEffect, useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  useCreateTaxExemptionCertificate,
  useDeleteTaxExemptionCertificate,
  useRevokeTaxExemptionCertificate,
  useTaxExemptionCertificates,
  useVerifyTaxExemptionCertificate,
} from '../../hooks/use-companies'
import {
  TAX_EXEMPTION_CERTIFICATE_DEFAULTS,
  TAX_EXEMPTION_REASON_CODES,
  type TaxExemptionCertificateFormValues,
  taxExemptionCertificateFormSchema,
  taxExemptionCertificateValuesToParams,
} from '../../schemas/company'
import { JurisdictionLabel } from './jurisdiction-label'

/**
 * Certificate dates are days, not moments — render them in the store's
 * timezone without a time part so an expiry never reads as the day before.
 */
function StoreDate({ iso }: { iso: string }) {
  const { timezone } = useStore()
  return <>{formatInTimeZone(parseISO(iso), timezone, 'PP')}</>
}

/** One selectable exemption reason. */
interface ReasonOption {
  value: string
  label: string
}

/**
 * Evidence that this business's purchases are not taxed. Accepting or
 * withdrawing one is a decision rather than an edit, so each is its own action
 * — and a certificate that has been acted on is revoked, never deleted.
 */
export function TaxExemptionCertificatesCard({
  companyId,
  canEdit,
}: {
  companyId: string
  canEdit: boolean
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { token } = useAuth()
  const { data, isLoading } = useTaxExemptionCertificates(companyId)
  const verifyMutation = useVerifyTaxExemptionCertificate(companyId)
  const revokeMutation = useRevokeTaxExemptionCertificate(companyId)
  const deleteMutation = useDeleteTaxExemptionCertificate(companyId)
  const [addOpen, setAddOpen] = useState(false)

  const certificates = data?.data ?? []

  async function handleRevoke(certificate: TaxExemptionCertificate) {
    const ok = await confirm({
      title: t('admin.tax_exemption_certificates.revoke_confirm.title'),
      message: t('admin.tax_exemption_certificates.revoke_confirm.message', {
        number: certificate.certificate_number,
      }),
      variant: 'destructive',
      confirmLabel: t('admin.tax_exemption_certificates.revoke_action'),
    })
    if (!ok) return
    await revokeMutation.mutateAsync(certificate.id).catch(() => undefined)
  }

  async function handleDelete(certificate: TaxExemptionCertificate) {
    const ok = await confirm({
      title: t('admin.tax_exemption_certificates.delete_confirm.title'),
      message: t('admin.tax_exemption_certificates.delete_confirm.message', {
        number: certificate.certificate_number,
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(certificate.id).catch(() => undefined)
  }

  async function handleDownload(certificate: TaxExemptionCertificate) {
    if (!certificate.document_url) return
    // Streamed through the admin endpoint rather than a public blob URL, so
    // the request has to carry the admin's credentials.
    await downloadFromApi(
      token,
      certificate.document_url,
      certificate.document_filename ?? 'certificate',
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          {t('admin.tax_exemption_certificates.title')}
          {certificates.length > 0 && <Badge variant="outline">{certificates.length}</Badge>}
        </CardTitle>
        {canEdit && (
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
              <PlusIcon className="size-4" />
              {t('admin.tax_exemption_certificates.add_cta')}
            </Button>
          </CardAction>
        )}
      </CardHeader>

      {isLoading ? (
        <CardContent>
          <p className="text-muted-foreground text-sm">{t('admin.common.loading')}</p>
        </CardContent>
      ) : certificates.length === 0 ? (
        <CardContent>
          <p className="text-muted-foreground text-sm">
            {t('admin.tax_exemption_certificates.empty')}
          </p>
        </CardContent>
      ) : (
        <CardContent className="flex flex-col gap-3">
          {certificates.map((certificate) => (
            <div
              key={certificate.id}
              className="flex items-start justify-between gap-3 rounded-md border p-3"
            >
              <div className="flex min-w-0 flex-col gap-1">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="font-medium text-sm">{certificate.certificate_number}</span>
                  <StatusBadge
                    status={certificate.status}
                    label={t(`admin.tax_exemption_certificates.status.${certificate.status}`, {
                      defaultValue: certificate.status,
                    })}
                  />
                  {certificate.lapsed && certificate.status !== 'expired' && (
                    <StatusBadge
                      status="expired"
                      label={t('admin.tax_exemption_certificates.lapsed')}
                    />
                  )}
                </div>
                <span className="text-muted-foreground text-xs">
                  {t(`admin.tax_exemption_certificates.reason_codes.${certificate.reason_code}`, {
                    defaultValue: certificate.reason_code,
                  })}
                  {' · '}
                  <JurisdictionLabel
                    countryCode={certificate.country_code}
                    stateCode={certificate.state_code}
                  />
                </span>

                <dl className="mt-1 grid grid-cols-[auto_1fr] gap-x-3 gap-y-0.5 text-xs">
                  {certificate.issuing_authority && (
                    <>
                      <dt className="text-muted-foreground">
                        {t('admin.fields.issuing_authority.label')}
                      </dt>
                      <dd>{certificate.issuing_authority}</dd>
                    </>
                  )}
                  {certificate.issued_at && (
                    <>
                      <dt className="text-muted-foreground">{t('admin.fields.issued_at.label')}</dt>
                      <dd>
                        <StoreDate iso={certificate.issued_at} />
                      </dd>
                    </>
                  )}
                  <dt className="text-muted-foreground">{t('admin.fields.expires_at.label')}</dt>
                  <dd>
                    {certificate.expires_at ? (
                      <StoreDate iso={certificate.expires_at} />
                    ) : (
                      t('admin.tax_exemption_certificates.never_expires')
                    )}
                  </dd>
                  {certificate.verified_at && (
                    <>
                      <dt className="text-muted-foreground">
                        {t('admin.tax_exemption_certificates.verified_at')}
                      </dt>
                      <dd>
                        <StoreDate iso={certificate.verified_at} />
                      </dd>
                    </>
                  )}
                </dl>

                {certificate.document_filename ? (
                  <Button
                    type="button"
                    variant="link"
                    size="sm"
                    className="h-auto justify-start p-0 text-xs"
                    onClick={() => handleDownload(certificate)}
                  >
                    <PaperclipIcon className="size-3" />
                    {certificate.document_filename}
                    {certificate.document_byte_size ? (
                      <span className="text-muted-foreground">
                        ({formatFileSize(certificate.document_byte_size)})
                      </span>
                    ) : null}
                  </Button>
                ) : (
                  <span className="text-muted-foreground text-xs">
                    {t('admin.tax_exemption_certificates.no_document')}
                  </span>
                )}
              </div>

              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button variant="ghost" size="icon-xs">
                    <EllipsisVerticalIcon className="size-4" />
                    <span className="sr-only">{t('admin.actions.actions_menu')}</span>
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  {certificate.document_url && (
                    <DropdownMenuItem onClick={() => handleDownload(certificate)}>
                      <DownloadIcon className="size-4" />
                      {t('admin.tax_exemption_certificates.download_action')}
                    </DropdownMenuItem>
                  )}
                  {canEdit && certificate.status === 'pending' && (
                    <DropdownMenuItem
                      disabled={verifyMutation.isPending}
                      onClick={() =>
                        verifyMutation.mutateAsync(certificate.id).catch(() => undefined)
                      }
                    >
                      <BadgeCheckIcon className="size-4" />
                      {t('admin.tax_exemption_certificates.verify_action')}
                    </DropdownMenuItem>
                  )}
                  {canEdit && certificate.status !== 'revoked' && (
                    <DropdownMenuItem
                      variant="destructive"
                      disabled={revokeMutation.isPending}
                      onClick={() => handleRevoke(certificate)}
                    >
                      <BanIcon className="size-4" />
                      {t('admin.tax_exemption_certificates.revoke_action')}
                    </DropdownMenuItem>
                  )}
                  {canEdit && certificate.can_be_deleted && (
                    <DropdownMenuItem
                      variant="destructive"
                      onClick={() => handleDelete(certificate)}
                    >
                      <TrashIcon className="size-4" />
                      {t('admin.actions.delete')}
                    </DropdownMenuItem>
                  )}
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
          ))}
        </CardContent>
      )}

      {addOpen && <CertificateSheet companyId={companyId} open onOpenChange={setAddOpen} />}
    </Card>
  )
}

function CertificateSheet({
  companyId,
  open,
  onOpenChange,
}: {
  companyId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateTaxExemptionCertificate(companyId)
  const form = useForm<TaxExemptionCertificateFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(taxExemptionCertificateFormSchema) as any,
    defaultValues: TAX_EXEMPTION_CERTIFICATE_DEFAULTS,
  })

  useEffect(() => {
    if (open) form.reset(TAX_EXEMPTION_CERTIFICATE_DEFAULTS)
  }, [open, form])

  const countryCode = form.watch('country_code')
  const { states } = useCountryStates(countryCode)

  async function handleSubmit(values: TaxExemptionCertificateFormValues) {
    try {
      await createMutation.mutateAsync(taxExemptionCertificateValuesToParams(values))
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
          <SheetTitle>{t('admin.tax_exemption_certificates.add_title')}</SheetTitle>
          <SheetDescription>
            {t('admin.tax_exemption_certificates.dialog_description')}
          </SheetDescription>
        </SheetHeader>
        <form
          onSubmit={(event) => {
            form.handleSubmit(handleSubmit)(event)
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
                <FieldLabel htmlFor="certificate_number">
                  {t('admin.fields.certificate_number.label')}
                </FieldLabel>
                <Input
                  id="certificate_number"
                  autoFocus
                  aria-invalid={!!errors.certificate_number || undefined}
                  {...form.register('certificate_number')}
                />
                <FieldError errors={[errors.certificate_number]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="reason_code">{t('admin.fields.reason_code.label')}</FieldLabel>
                <Controller
                  name="reason_code"
                  control={form.control}
                  render={({ field }) => {
                    const reasonOptions = TAX_EXEMPTION_REASON_CODES.map((code) => ({
                      value: code,
                      label: t(`admin.tax_exemption_certificates.reason_codes.${code}`, {
                        defaultValue: code,
                      }),
                    }))
                    const selected = reasonOptions.find((o) => o.value === field.value) ?? null
                    return (
                      <Combobox
                        items={reasonOptions}
                        value={selected}
                        onValueChange={(option: ReasonOption | null) =>
                          field.onChange(option?.value ?? '')
                        }
                        itemToStringLabel={(option: ReasonOption | null) => option?.label ?? ''}
                        itemToStringValue={(option: ReasonOption | null) => option?.value ?? ''}
                      >
                        <ComboboxInput
                          id="reason_code"
                          placeholder={t('admin.tax_exemption_certificates.select_reason')}
                        />
                        <ComboboxContent>
                          <ComboboxEmpty>{t('admin.common.no_results')}</ComboboxEmpty>
                          <ComboboxList>
                            {(option: ReasonOption) => (
                              <ComboboxItem key={option.value} value={option}>
                                {option.label}
                              </ComboboxItem>
                            )}
                          </ComboboxList>
                        </ComboboxContent>
                      </Combobox>
                    )
                  }}
                />
                <FieldDescription>{t('admin.fields.reason_code.help')}</FieldDescription>
                <FieldError errors={[errors.reason_code]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="certificate-country">
                  {t('admin.fields.country.label')}
                </FieldLabel>
                <Controller
                  name="country_code"
                  control={form.control}
                  render={({ field }) => (
                    <CountryCombobox
                      value={field.value}
                      onValueChange={(iso) => {
                        field.onChange(iso)
                        form.setValue('state_code', '', { shouldDirty: true })
                      }}
                      placeholder={t('admin.jurisdiction.everywhere')}
                    />
                  )}
                />
                <FieldDescription>
                  {t('admin.fields.tax_exemption_certificate.country_code.help')}
                </FieldDescription>
              </Field>

              {countryCode && states.length > 0 && (
                <Field>
                  <FieldLabel htmlFor="certificate-state">
                    {t('admin.fields.state.label')}
                  </FieldLabel>
                  <Controller
                    name="state_code"
                    control={form.control}
                    render={({ field }) => (
                      <StateCombobox
                        countryCode={countryCode}
                        states={states}
                        value={field.value}
                        onValueChange={field.onChange}
                      />
                    )}
                  />
                </Field>
              )}

              <Field>
                <FieldLabel htmlFor="issued_at">{t('admin.fields.issued_at.label')}</FieldLabel>
                <Controller
                  name="issued_at"
                  control={form.control}
                  render={({ field }) => (
                    <StoreDatePicker inline value={field.value} onChange={field.onChange} />
                  )}
                />
              </Field>

              <Field>
                <FieldLabel htmlFor="expires_at">{t('admin.fields.expires_at.label')}</FieldLabel>
                <Controller
                  name="expires_at"
                  control={form.control}
                  render={({ field }) => (
                    <StoreDatePicker inline value={field.value} onChange={field.onChange} />
                  )}
                />
                <FieldDescription>
                  {t('admin.fields.tax_exemption_certificate.expires_at.help')}
                </FieldDescription>
              </Field>

              <Field>
                <FieldLabel htmlFor="issuing_authority">
                  {t('admin.fields.issuing_authority.label')}
                </FieldLabel>
                <Input id="issuing_authority" {...form.register('issuing_authority')} />
              </Field>

              <Field>
                <FieldLabel>{t('admin.fields.certificate_document.label')}</FieldLabel>
                <Controller
                  name="document_signed_id"
                  control={form.control}
                  render={({ field }) => (
                    <FileUploadField
                      value={{
                        signedId: field.value ?? null,
                        previewUrl: null,
                        cleared: false,
                      }}
                      onChange={(next) => field.onChange(next.signedId)}
                      accept="application/pdf,image/png,image/jpeg"
                    />
                  )}
                />
                <FieldDescription>{t('admin.fields.certificate_document.help')}</FieldDescription>
              </Field>
            </FieldGroup>
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting
                ? t('admin.actions.creating')
                : t('admin.actions.create')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

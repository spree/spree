import {
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
  Field,
  FieldError,
  FieldLabel,
  Input,
  Sheet,
  SheetContent,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  toastManager,
} from '@spree/dashboard-ui'
import type { Profile } from '@spree/seller-sdk'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useParams } from '@tanstack/react-router'
import { PencilIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'

/**
 * The registration kinds Spree ships strings for. Any string is accepted — a
 * kind means whatever the validator registered for it decides — so the list
 * seeds the picker rather than closing it, and a seller in a regime not listed
 * here can type their own.
 */
const TAX_IDENTIFIER_KINDS = ['eu_vat', 'gb_vat', 'ch_vat', 'au_abn', 'us_ein'] as const

/** What a seller with no registration on file starts on. */
const DEFAULT_KIND = 'eu_vat'

type KindOption = { value: string; label: string }

/** A 422 from the API, whose `details` name the attributes that were refused. */
function isSpreeValidationError(
  error: unknown,
): error is Error & { details?: Record<string, string[]> } {
  return error instanceof Error && 'details' in error
}

function errorMessage(error: unknown, fallback: string) {
  return error instanceof Error && error.message ? error.message : fallback
}

/**
 * The business behind the seller, as the marketplace's commission invoice
 * must address it: legal name, registration number, and the VAT number that
 * decides whether that invoice carries VAT or is reverse-charged.
 *
 * Separate from the billing address, which is only where post goes. Most of
 * what an invoice needs is not an address, and putting a VAT number in an
 * address form is what makes it get lost.
 */
export function SellerBusinessCard({ profile }: { profile: Profile }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const queryClient = useQueryClient()
  const [editing, setEditing] = useState(false)

  // Whichever registration the seller holds, not whichever one is European:
  // core format-checks eu_vat, so pinning the kind here would hand a British
  // or Swiss seller a rejection with no way to say what their number is.
  const vat = profile.tax_identifiers?.[0]

  const [legalName, setLegalName] = useState(profile.legal_name ?? '')
  const [registrationNumber, setRegistrationNumber] = useState(profile.registration_number ?? '')
  const [vatNumber, setVatNumber] = useState(vat?.value ?? '')
  const [vatKind, setVatKind] = useState(vat?.kind ?? DEFAULT_KIND)
  // Shown in the sheet rather than as a toast: the toast stack deliberately
  // sits below the sheet overlay, so a rejection raised here would be hidden
  // behind the very form that caused it.
  const [fieldErrors, setFieldErrors] = useState<Record<string, string[]>>({})
  const [formError, setFormError] = useState<string | null>(null)

  // Opening the sheet is the seller starting over, so it shows what is on file
  // rather than whatever they last typed. Without this the card never remounts:
  // abandoned edits survive a close, and an emptied VAT field would be sent as
  // a deliberate clear the next time they save anything at all.
  function setSheetOpen(open: boolean) {
    if (open) {
      setLegalName(profile.legal_name ?? '')
      setRegistrationNumber(profile.registration_number ?? '')
      setVatNumber(vat?.value ?? '')
      setVatKind(vat?.kind ?? DEFAULT_KIND)
      setFieldErrors({})
      setFormError(null)
    }
    setEditing(open)
  }

  const save = useMutation({
    mutationFn: () => {
      setFieldErrors({})
      setFormError(null)
      return sellerClient().profile.update({
        legal_name: legalName || null,
        registration_number: registrationNumber || null,
        tax_identifier: { kind: vatKind, value: vatNumber },
      })
    },
    onSuccess: (updated) => {
      queryClient.setQueryData(['seller', sellerId, 'profile'], updated)
      // A checklist kind may read these, so it has to re-evaluate.
      void queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'onboarding'] })
      setEditing(false)
      toastManager.add({ type: 'success', title: t('profile.saved') })
    },
    onError: (err) => {
      const details = isSpreeValidationError(err) ? err.details : undefined
      setFieldErrors(details ?? {})
      // A per-field message already sits under its own input, so the banner is
      // only for what has nowhere else to go.
      setFormError(details?.value?.length ? null : errorMessage(err, t('common.error')))
    },
  })

  const kindOptions: KindOption[] = TAX_IDENTIFIER_KINDS.map((kind) => ({
    value: kind,
    label: t(`profile.tax_identifier_kinds.${kind}`, { defaultValue: kind }),
  }))
  // A kind the seller typed themselves is not in the list, so it is offered back
  // as its own option rather than reading as an empty field.
  const selectedKind =
    kindOptions.find((option) => option.value === vatKind) ??
    (vatKind ? { value: vatKind, label: vatKind } : null)

  const rows = [
    { label: t('profile.legal_name'), value: profile.legal_name },
    { label: t('profile.registration_number'), value: profile.registration_number },
    {
      label: vat
        ? t(`profile.tax_identifier_kinds.${vat.kind}`, { defaultValue: vat.kind })
        : t('profile.vat_number'),
      value: vat?.value,
    },
  ]

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>{t('profile.business_details')}</CardTitle>
          <CardAction>
            <Button variant="outline" size="sm" onClick={() => setSheetOpen(true)}>
              <PencilIcon className="size-4" />
              {t('profile.edit')}
            </Button>
          </CardAction>
        </CardHeader>
        <CardContent className="flex flex-col gap-2 text-sm">
          {rows.map((row) => (
            <div key={row.label} className="flex justify-between gap-4">
              <span className="text-muted-foreground">{row.label}</span>
              <span className="text-right">{row.value || '—'}</span>
            </div>
          ))}
          {/* A number the seller believes is on file but which came back
              unverified is worth them knowing about. */}
          {vat?.validation_status && vat.validation_status !== 'verified' && (
            <p className="text-muted-foreground text-xs">
              {t(`profile.vat_status.${vat.validation_status}`, {
                defaultValue: vat.validation_status,
              })}
            </p>
          )}
        </CardContent>
      </Card>

      <Sheet open={editing} onOpenChange={setSheetOpen}>
        <SheetContent>
          <SheetHeader>
            <SheetTitle>{t('profile.business_details')}</SheetTitle>
          </SheetHeader>
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            {formError && (
              <p role="alert" className="text-destructive text-sm">
                {formError}
              </p>
            )}
            <Field>
              <FieldLabel htmlFor="legal-name">{t('profile.legal_name')}</FieldLabel>
              <Input
                id="legal-name"
                value={legalName}
                onChange={(event) => setLegalName(event.target.value)}
              />
            </Field>
            <Field>
              <FieldLabel htmlFor="registration-number">
                {t('profile.registration_number')}
              </FieldLabel>
              <Input
                id="registration-number"
                value={registrationNumber}
                onChange={(event) => setRegistrationNumber(event.target.value)}
              />
            </Field>
            <Field>
              <FieldLabel htmlFor="vat-kind">{t('profile.tax_identifier_kind')}</FieldLabel>
              {/* Combobox rather than Select: the kind is free text at the API,
                  so a seller whose regime is not listed can still type it. */}
              <Combobox
                items={kindOptions}
                value={selectedKind}
                onValueChange={(option: KindOption | null) => setVatKind(option?.value ?? '')}
                // Typing is how a seller records a regime this build has no
                // string for. The input is tracked separately from the
                // selection, so without this a kind matching no item is never
                // read and the previous one is saved instead. Only genuine
                // typing counts: picking an option also rewrites the input,
                // to the option's label, which is not what the API stores.
                onInputValueChange={(input: string, details: { reason?: string }) => {
                  if (details.reason === 'input-change') setVatKind(input)
                }}
                itemToStringLabel={(option: KindOption | null) => option?.label ?? ''}
                itemToStringValue={(option: KindOption | null) => option?.value ?? ''}
              >
                <ComboboxInput
                  id="vat-kind"
                  placeholder={t('profile.select_tax_identifier_kind')}
                />
                <ComboboxContent>
                  <ComboboxEmpty>{t('common.no_results')}</ComboboxEmpty>
                  <ComboboxList>
                    {(option: KindOption) => (
                      <ComboboxItem key={option.value} value={option}>
                        {option.label}
                      </ComboboxItem>
                    )}
                  </ComboboxList>
                </ComboboxContent>
              </Combobox>
            </Field>
            <Field>
              <FieldLabel htmlFor="vat-number">{t('profile.vat_number')}</FieldLabel>
              <Input
                id="vat-number"
                aria-invalid={fieldErrors.value?.length ? true : undefined}
                value={vatNumber}
                onChange={(event) => setVatNumber(event.target.value)}
              />
              <FieldError errors={fieldErrors.value?.map((message) => ({ message }))} />
            </Field>
          </div>
          <SheetFooter>
            <Button variant="outline" size="sm" onClick={() => setSheetOpen(false)}>
              {t('common.cancel')}
            </Button>
            <Button size="sm" disabled={save.isPending} onClick={() => save.mutate()}>
              {t('common.save')}
            </Button>
          </SheetFooter>
        </SheetContent>
      </Sheet>
    </>
  )
}

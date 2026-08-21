import {
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldLabel,
  Input,
  Sheet,
  SheetContent,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import type { Profile } from '@spree/seller-sdk'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useParams } from '@tanstack/react-router'
import { PencilIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { sellerClient } from '../api-client'

/** The registration kind this panel collects. */
const VAT_KIND = 'eu_vat'

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

  const vat = profile.tax_identifiers?.find((identifier) => identifier.kind === VAT_KIND)

  const [legalName, setLegalName] = useState(profile.legal_name ?? '')
  const [registrationNumber, setRegistrationNumber] = useState(profile.registration_number ?? '')
  const [vatNumber, setVatNumber] = useState(vat?.value ?? '')

  const save = useMutation({
    mutationFn: () =>
      sellerClient().profile.update({
        legal_name: legalName || null,
        registration_number: registrationNumber || null,
        tax_identifier: { kind: VAT_KIND, value: vatNumber },
      }),
    onSuccess: (updated) => {
      queryClient.setQueryData(['seller', sellerId, 'profile'], updated)
      // A checklist kind may read these, so it has to re-evaluate.
      void queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'onboarding'] })
      setEditing(false)
      toast.success(t('profile.saved'))
    },
    onError: (err) => toast.error(err instanceof Error ? err.message : t('common.error')),
  })

  const rows = [
    { label: t('profile.legal_name'), value: profile.legal_name },
    { label: t('profile.registration_number'), value: profile.registration_number },
    { label: t('profile.vat_number'), value: vat?.value },
  ]

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>{t('profile.business_details')}</CardTitle>
          <CardAction>
            <Button variant="outline" size="sm" onClick={() => setEditing(true)}>
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

      <Sheet open={editing} onOpenChange={setEditing}>
        <SheetContent>
          <SheetHeader>
            <SheetTitle>{t('profile.business_details')}</SheetTitle>
          </SheetHeader>
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
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
              <FieldLabel htmlFor="vat-number">{t('profile.vat_number')}</FieldLabel>
              <Input
                id="vat-number"
                value={vatNumber}
                onChange={(event) => setVatNumber(event.target.value)}
              />
            </Field>
          </div>
          <SheetFooter>
            <Button variant="outline" size="sm" onClick={() => setEditing(false)}>
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

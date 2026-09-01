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
  toastManager,
} from '@spree/dashboard-ui'
import { PencilIcon } from '@spree/dashboard-ui/icons'
import type { Profile } from '@spree/seller-sdk'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useParams } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'

function errorMessage(error: unknown, fallback: string) {
  return error instanceof Error && error.message ? error.message : fallback
}

/**
 * The business behind the seller, as the marketplace's commission invoice must
 * address it: the legal name and registration number.
 *
 * The tax registrations sit in their own card beside this one, on the same
 * panel a company's are managed from — a business trading in several regimes
 * holds a registration in each, so they are a collection rather than a field.
 *
 * Separate from the billing address, which is only where post goes.
 */
export function SellerBusinessCard({ profile }: { profile: Profile }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const queryClient = useQueryClient()
  const [editing, setEditing] = useState(false)

  const [legalName, setLegalName] = useState(profile.legal_name ?? '')
  const [registrationNumber, setRegistrationNumber] = useState(profile.registration_number ?? '')
  // Shown in the sheet rather than as a toast: the toast stack deliberately
  // sits below the sheet overlay, so a rejection raised here would be hidden
  // behind the very form that caused it.
  const [formError, setFormError] = useState<string | null>(null)

  // Opening the sheet is the seller starting over, so it shows what is on file
  // rather than whatever they last typed — the card never remounts, so an
  // abandoned edit would otherwise outlive the sheet that made it.
  function setSheetOpen(open: boolean) {
    if (open) {
      setLegalName(profile.legal_name ?? '')
      setRegistrationNumber(profile.registration_number ?? '')
      setFormError(null)
    }
    setEditing(open)
  }

  const save = useMutation({
    mutationFn: () => {
      setFormError(null)
      return sellerClient().profile.update({
        legal_name: legalName || null,
        registration_number: registrationNumber || null,
      })
    },
    onSuccess: (updated) => {
      queryClient.setQueryData(['seller', sellerId, 'profile'], updated)
      // A checklist kind may read these, so it has to re-evaluate.
      void queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'onboarding'] })
      setEditing(false)
      toastManager.add({ type: 'success', title: t('profile.saved') })
    },
    onError: (err) => setFormError(errorMessage(err, t('common.error'))),
  })

  const rows = [
    { label: t('profile.legal_name'), value: profile.legal_name },
    { label: t('profile.registration_number'), value: profile.registration_number },
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

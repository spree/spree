import type { Address } from '@spree/admin-sdk'
import { type FormEvent, useCallback, useState } from 'react'
import {
  CountryCombobox,
  StateCombobox,
  useCountryStates,
} from '@/components/spree/country-state-fields'
import { Button } from '@/components/ui/button'
import { Field, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'

export interface AddressParams {
  first_name: string
  last_name: string
  address1: string
  address2: string
  city: string
  postal_code: string
  country_iso: string
  state_abbr: string
  phone: string
  label?: string
  is_default_billing?: boolean
  is_default_shipping?: boolean
}

export function AddressFormDialog({
  address,
  open,
  onOpenChange,
  onSave,
  title = 'Edit Address',
  isPending = false,
  showLabel = false,
  showDefaultFlags = false,
}: {
  address: Address | null | undefined
  open: boolean
  onOpenChange: (open: boolean) => void
  onSave: (address: AddressParams) => void
  title?: string
  isPending?: boolean
  showLabel?: boolean
  showDefaultFlags?: boolean
}) {
  // The parent keys the dialog on the address id so a fresh instance mounts
  // for each open — that's what lets us seed `countryIso` from the address
  // once and forget about it.
  const [countryIso, setCountryIso] = useState<string>(() => address?.country_iso ?? '')
  const [stateAbbr, setStateAbbr] = useState<string>(() => address?.state_abbr ?? '')

  const { states, statesRequired } = useCountryStates(countryIso)
  const useStateCombobox = statesRequired && states.length > 0

  const handleCountryChange = useCallback((iso: string) => {
    setCountryIso(iso)
    // Clear the previously selected state — the combobox is keyed on the
    // country, but we still need the form field to reset across countries.
    setStateAbbr('')
  }, [])

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const fd = new FormData(e.currentTarget)
    onSave({
      first_name: fd.get('first_name') as string,
      last_name: fd.get('last_name') as string,
      address1: fd.get('address1') as string,
      address2: fd.get('address2') as string,
      city: fd.get('city') as string,
      postal_code: fd.get('postal_code') as string,
      country_iso: countryIso,
      state_abbr: useStateCombobox ? stateAbbr : (fd.get('state_abbr') as string),
      phone: fd.get('phone') as string,
      ...(showLabel && { label: (fd.get('label') as string) || undefined }),
      ...(showDefaultFlags && {
        is_default_billing: fd.get('is_default_billing') === 'on',
        is_default_shipping: fd.get('is_default_shipping') === 'on',
      }),
    })
  }

  // Prevent Enter in combobox inputs from submitting the form
  function handleKeyDown(e: React.KeyboardEvent) {
    const target = e.target as HTMLElement
    if (e.key === 'Enter' && target.getAttribute('role') === 'combobox') {
      e.preventDefault()
    }
  }

  return (
    <Sheet open={open} onOpenChange={(o) => onOpenChange(o as boolean)}>
      <SheetContent side="right">
        <SheetHeader>
          <SheetTitle>{title}</SheetTitle>
          <SheetDescription>Update the address details.</SheetDescription>
        </SheetHeader>
        <form
          onSubmit={handleSubmit}
          onKeyDown={handleKeyDown}
          className="flex flex-col flex-1 overflow-hidden"
        >
          <div className="flex-1 overflow-y-auto p-4">
            <FieldGroup>
              {showLabel && (
                <Field>
                  <FieldLabel htmlFor="addr-label">Label</FieldLabel>
                  <Input
                    id="addr-label"
                    name="label"
                    placeholder="e.g. Home, Office"
                    defaultValue={address?.label ?? ''}
                  />
                </Field>
              )}
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor="addr-fn">First name</FieldLabel>
                  <Input id="addr-fn" name="first_name" defaultValue={address?.first_name ?? ''} />
                </Field>
                <Field>
                  <FieldLabel htmlFor="addr-ln">Last name</FieldLabel>
                  <Input id="addr-ln" name="last_name" defaultValue={address?.last_name ?? ''} />
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor="addr-a1">Address</FieldLabel>
                <Input id="addr-a1" name="address1" defaultValue={address?.address1 ?? ''} />
              </Field>
              <Field>
                <FieldLabel htmlFor="addr-a2">Apartment, suite, etc.</FieldLabel>
                <Input id="addr-a2" name="address2" defaultValue={address?.address2 ?? ''} />
              </Field>
              <Field>
                <FieldLabel>Country</FieldLabel>
                <CountryCombobox value={countryIso} onValueChange={handleCountryChange} />
              </Field>
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor="addr-city">City</FieldLabel>
                  <Input id="addr-city" name="city" defaultValue={address?.city ?? ''} />
                </Field>
                <Field>
                  <FieldLabel>State / Province</FieldLabel>
                  {useStateCombobox ? (
                    <StateCombobox
                      countryIso={countryIso}
                      states={states}
                      value={stateAbbr}
                      onValueChange={setStateAbbr}
                    />
                  ) : (
                    <Input
                      id="addr-state"
                      name="state_abbr"
                      defaultValue={address?.state_abbr ?? ''}
                    />
                  )}
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor="addr-zip">Postal code</FieldLabel>
                <Input id="addr-zip" name="postal_code" defaultValue={address?.postal_code ?? ''} />
              </Field>
              <Field>
                <FieldLabel htmlFor="addr-phone">Phone</FieldLabel>
                <Input id="addr-phone" name="phone" defaultValue={address?.phone ?? ''} />
              </Field>
              {showDefaultFlags && (
                <>
                  <Field>
                    <label className="flex items-center gap-2 text-sm">
                      <input
                        type="checkbox"
                        name="is_default_billing"
                        defaultChecked={address?.is_default_billing}
                      />
                      Default billing address
                    </label>
                  </Field>
                  <Field>
                    <label className="flex items-center gap-2 text-sm">
                      <input
                        type="checkbox"
                        name="is_default_shipping"
                        defaultChecked={address?.is_default_shipping}
                      />
                      Default shipping address
                    </label>
                  </Field>
                </>
              )}
            </FieldGroup>
          </div>
          <SheetFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={isPending}>
              {isPending ? 'Saving...' : 'Save'}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

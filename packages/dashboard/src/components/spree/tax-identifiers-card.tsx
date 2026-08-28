import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  TaxIdentifiersCard as SharedTaxIdentifiersCard,
  type TaxIdentifier,
  type TaxIdentifierMutations,
} from '@spree/dashboard-ui'

export type { TaxIdentifier, TaxIdentifierMutations }

/**
 * The buyer's VAT or business number, wired to this dashboard's SDK.
 *
 * The panel itself lives in `@spree/dashboard-ui` so the seller panel renders
 * the same one: a seller manages registrations exactly as a company does, and
 * the two surfaces drifting is how the hardcoded kind and the hidden toast
 * ended up in only one of them. All this adds is the error mapper, which is
 * the one piece that knows which SDK raised the failure.
 */
export function TaxIdentifiersCard({
  mutations,
  ...props
}: Omit<Parameters<typeof SharedTaxIdentifiersCard>[0], 'mutations'> & {
  mutations: Omit<TaxIdentifierMutations, 'mapErrors'>
}) {
  return (
    <SharedTaxIdentifiersCard
      {...props}
      mutations={{ ...mutations, mapErrors: mapSpreeErrorsToForm }}
    />
  )
}

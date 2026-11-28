import { Money } from '@spree/dashboard-core'

/** A saved amount struck through, beside what an edit turns it into, in the row's own weight. */
export function MoneyChange({
  before,
  after,
  currency,
}: {
  before: string | null | undefined
  after: string | null | undefined
  currency: string
}) {
  return (
    <span className="flex items-center justify-end gap-2">
      <span className="font-normal text-muted-foreground line-through">
        <Money amount={before} currency={currency} />
      </span>
      <span>
        <Money amount={after} currency={currency} />
      </span>
    </span>
  )
}

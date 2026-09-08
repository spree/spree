import type { PriceList } from '@spree/admin-sdk'
import { ExportRecordButton, ImportButton, type PanelImport, Subject } from '@spree/dashboard-core'

/**
 * Export and import of one price list's prices as CSV, one rung per row. Sits
 * next to "Edit prices" wherever a list is edited — its own page and the
 * catalog that owns it — so a merchant working an agreement never leaves it
 * to move its figures in bulk (docs/plans/6.0-volume-pricing.md).
 *
 * The export is fixed to this list, and the import is bound to it before the
 * sheet opens: the file never names a list, so neither does the merchant.
 */
export function PriceListCsvButtons({
  priceList,
  onImportCreated,
  size,
}: {
  priceList: PriceList
  /** Receives the created import so the page can open the wizard for it. */
  onImportCreated: (imp: PanelImport) => void
  size?: 'sm' | 'default'
}) {
  return (
    <>
      <ImportButton
        type="price_list_prices"
        subject={Subject.PriceList}
        params={{ price_list_id: priceList.id }}
        onCreated={onImportCreated}
        size={size}
      />
      <ExportRecordButton
        type="price_list_prices"
        searchParams={{ price_list_id_eq: priceList.id }}
        size={size}
      />
    </>
  )
}

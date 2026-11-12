# Whether tax sits inside a price is the market's setting now, and the column is
# read once by `spree:markets:backfill_tax_inclusive`. New rates leave it empty,
# so that step, which every later upgrade runs again, never mistakes one for a
# rate whose tax was added on top. The column is dropped in 6.1.
class RemoveDefaultFromSpreeTaxRatesIncludedInPrice < ActiveRecord::Migration[8.1]
  def change
    change_column_default :spree_tax_rates, :included_in_price, from: false, to: nil
  end
end

class AddCountryAndStateToSpreeTaxRates < ActiveRecord::Migration[8.1]
  def change
    # Merchants think "Germany charges 19% VAT", not in zones. A rate now names
    # its jurisdiction directly: nil country means everywhere, and a country
    # with no state means the whole country.
    #
    # Zones were also the reason a tax line could not say which country taxed
    # it — one zone can span several. Existing rows are converted by
    # `spree:migrate_tax_zones`, which splits a multi-country zone into one rate
    # per country, before `zone_id` comes off.
    add_reference :spree_tax_rates, :country, null: true
    add_reference :spree_tax_rates, :state, null: true
  end
end

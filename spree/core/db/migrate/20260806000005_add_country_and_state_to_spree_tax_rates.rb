class AddCountryAndStateToSpreeTaxRates < ActiveRecord::Migration[8.1]
  def change
    # Merchants think "Germany charges 19% VAT", not in zones. A rate now names
    # its jurisdiction directly: nil country means everywhere, and a country
    # with no state means the whole country.
    #
    # Stored as codes rather than references to Country and State, which are on
    # their way out — and "DE"/"NY" is what a merchant recognises anyway. Same
    # shape as the jurisdiction snapshot on spree_tax_lines.
    #
    # Zones were also the reason a tax line could not say which country taxed
    # it — one zone can span several. Existing rows are converted by
    # `spree:migrate_tax_zones`, which splits a multi-country zone into one rate
    # per country, before `zone_id` comes off.
    add_column :spree_tax_rates, :country_code, :string
    add_column :spree_tax_rates, :state_code, :string

    add_index :spree_tax_rates, [:country_code, :state_code]
  end
end

class AddTaxDisplayAndDefaultCountryCodeToSpreeMarkets < ActiveRecord::Migration[8.1]
  def change
    change_table :spree_markets, bulk: true do |t|
      t.string :tax_display
      t.string :default_country_code
    end
  end
end

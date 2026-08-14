class AddTaxProviderToSpreeMarkets < ActiveRecord::Migration[8.1]
  def change
    # Which tax engine computes for this market, as a class name. A market is a
    # regional commerce operation, and the right engine is a regional question:
    # US sales tax needs a jurisdiction database, EU VAT is rate configuration.
    # Nil falls back to the store-wide default.
    add_column :spree_markets, :tax_provider, :string
  end
end

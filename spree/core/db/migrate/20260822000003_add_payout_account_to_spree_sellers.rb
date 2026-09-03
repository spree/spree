class AddPayoutAccountToSpreeSellers < ActiveRecord::Migration[8.1]
  def change
    # Whether the provider that pays this seller says it may yet send them
    # money — a Stripe Express account reports `payouts_enabled`, and can
    # withdraw it again when documents expire. Nil until a provider has said.
    #
    # The account itself is not a column here: it is the seller's identity in
    # an external system, which is what Spree::ExternalReference records.
    add_column :spree_sellers, :payouts_enabled_at, :datetime
  end
end

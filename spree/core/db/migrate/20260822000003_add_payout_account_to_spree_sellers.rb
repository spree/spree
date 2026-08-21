class AddPayoutAccountToSpreeSellers < ActiveRecord::Migration[8.1]
  def change
    # The seller's account with whichever provider pays them, and whether that
    # provider says it may yet send money.
    #
    # Deliberately provider-agnostic columns rather than `stripe_account_id`:
    # the payout provider is pluggable, and a marketplace paying by SEPA batch
    # or PayPal has an account reference too. Which provider the reference
    # belongs to is the store's payout provider, so it is not repeated here.
    add_column :spree_sellers, :payout_account_reference, :string
    # Set from the provider's own account status — a Stripe Express account
    # says when it is payouts_enabled. Nil until a provider has been asked.
    add_column :spree_sellers, :payouts_enabled_at, :datetime

    add_index :spree_sellers, :payout_account_reference
  end
end

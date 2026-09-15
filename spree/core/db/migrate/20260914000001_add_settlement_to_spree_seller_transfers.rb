# What a seller actually received, when their account settles in a currency
# other than the one the sale was priced in.
#
# This records a conversion the provider performed and reported. Spree still
# holds no exchange rates and converts nothing itself.
#
# Required rather than nullable: every query that groups or sums by settlement
# reads these columns directly, so a null row would fall out of balances and
# out of payout selection without saying so.
class AddSettlementToSpreeSellerTransfers < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_seller_transfers, :settled_amount, :decimal, precision: 10, scale: 2, null: false
    add_column :spree_seller_transfers, :settled_currency, :string, null: false

    add_index :spree_seller_transfers, [:seller_id, :settled_currency, :status],
              name: 'index_seller_transfers_on_seller_and_settled_currency'
  end
end

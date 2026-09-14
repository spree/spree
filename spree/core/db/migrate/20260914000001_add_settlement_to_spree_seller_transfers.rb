# What a seller actually received, when their account settles in a currency
# other than the one the sale was priced in.
#
# This records a conversion the provider performed and reported. Spree still
# holds no exchange rates and converts nothing itself.
#
# The columns are NOT NULL, because every query that groups or sums by
# settlement reads them directly — a null row would fall out of balances and
# out of payout selection without saying so. A row starts out settling in the
# currency it was sold in, which is the truth outright for a provider that
# converts nothing, and a provider that does converts overwrites both.
#
# The columns are seeded here rather than by a rake task: they are introduced
# by this migration, in a release that has not shipped, so this is a new
# column's initial value rather than a transformation of data anyone holds.
class AddSettlementToSpreeSellerTransfers < ActiveRecord::Migration[8.1]
  def change
    add_column :spree_seller_transfers, :settled_amount, :decimal, precision: 10, scale: 2
    add_column :spree_seller_transfers, :settled_currency, :string

    reversible do |direction|
      direction.up do
        execute(<<~SQL.squish)
          UPDATE spree_seller_transfers
          SET settled_amount = amount, settled_currency = currency
          WHERE settled_amount IS NULL OR settled_currency IS NULL
        SQL
      end
    end

    change_column_null :spree_seller_transfers, :settled_amount, false
    change_column_null :spree_seller_transfers, :settled_currency, false

    add_index :spree_seller_transfers, [:seller_id, :settled_currency, :status],
              name: 'index_seller_transfers_on_seller_and_settled_currency'
  end
end

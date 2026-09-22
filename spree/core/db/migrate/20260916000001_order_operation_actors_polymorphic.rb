# Makes the order-operation "who did this" associations polymorphic, so a
# write made with a secret API key records the key rather than nobody.
# See docs/plans/6.0-action-actors.md.
class OrderOperationActorsPolymorphic < ActiveRecord::Migration[8.1]
  ACTORS = {
    spree_orders: %i[created_by approver canceler],
    spree_refunds: %i[refunder],
    spree_returns: %i[created_by],
    spree_exchanges: %i[created_by],
    spree_claims: %i[created_by],
    spree_stock_receipts: %i[received_by]
  }.freeze

  def change
    ACTORS.each do |table, names|
      names.each do |name|
        # Nullable with no default: the type is data, filled by
        # `rake spree:upgrade:backfill_actor_types`. Until it runs, the
        # transitional reader resolves these rows through the admin user
        # class — the only thing they could ever have pointed at.
        add_column table, :"#{name}_type", :string

        # Named for the pair so it reads apart from the `_id` index that
        # already exists on most of these columns.
        add_index table, [:"#{name}_type", :"#{name}_id"],
                  name: "index_#{table}_on_#{name}_actor"
      end
    end
  end
end

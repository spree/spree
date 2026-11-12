# Makes a store credit's issuer polymorphic, so a credit issued with a secret
# API key — a return an integration refunds to store credit — records the key
# rather than failing. See docs/plans/6.0-action-actors.md.
class StoreCreditActorPolymorphic < ActiveRecord::Migration[8.1]
  def change
    # Nullable with no default: the type is data, filled by
    # `rake spree:upgrade:backfill_actor_types`. Until it runs, the
    # transitional reader resolves these rows through the admin user class.
    add_column :spree_store_credits, :created_by_type, :string
    add_index :spree_store_credits, [:created_by_type, :created_by_id],
              name: 'index_spree_store_credits_on_created_by_actor'
  end
end

class AddDeletedAtToStoreCreditEvents < ActiveRecord::Migration
  def change
    add_column :spree_store_credit_events, :deleted_at, :datetime
  end
end

class AddTimestampsToStoreCreditEvents < ActiveRecord::Migration
  def change
    add_column :spree_store_credit_events, :created_at, :datetime
    add_column :spree_store_credit_events, :updated_at, :datetime
  end
end

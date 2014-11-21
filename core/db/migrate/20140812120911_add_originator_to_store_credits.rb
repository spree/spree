class AddOriginatorToStoreCredits < ActiveRecord::Migration
  def change
    add_column :spree_store_credit_events, :originator_id, :integer
    add_column :spree_store_credit_events, :originator_type, :string
  end
end

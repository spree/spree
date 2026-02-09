# This migration comes from spree (originally 20260115120000)
class CreateSpreeCustomerGroups < ActiveRecord::Migration[7.0]
  def change
    create_table :spree_customer_groups do |t|
      t.references :store, null: false, index: true
      t.string :name, null: false
      t.text :description
      t.timestamps
      t.datetime :deleted_at
    end

    add_index :spree_customer_groups, [:store_id, :name], unique: true, where: 'deleted_at IS NULL'
    add_index :spree_customer_groups, :deleted_at
  end
end

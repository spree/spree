# This migration comes from spree (originally 20260115120001)
class CreateSpreeCustomerGroupUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :spree_customer_group_users do |t|
      t.references :customer_group, null: false, index: true
      t.references :user, polymorphic: true, null: false, index: true
      t.timestamps
    end

    add_index :spree_customer_group_users,
              [:customer_group_id, :user_id, :user_type],
              unique: true,
              name: 'index_spree_customer_group_users_unique'
  end
end

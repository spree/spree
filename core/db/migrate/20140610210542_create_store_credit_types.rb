class CreateStoreCreditTypes < ActiveRecord::Migration
  def change
    create_table :spree_store_credit_types do |t|
      t.string :name
      t.integer :priority
      t.timestamps
    end

    add_column :spree_store_credits, :type_id, :integer

    add_index :spree_store_credits, :type_id
    add_index :spree_store_credit_types, :priority

    default_type = Spree::StoreCreditType.create!(name: 'Promotional', priority: 1)
    Spree::StoreCredit.update_all(type_id: default_type.id)
  end
end

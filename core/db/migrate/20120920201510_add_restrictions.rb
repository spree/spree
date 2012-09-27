class AddRestrictions < ActiveRecord::Migration
  def change
    create_table :spree_restrictions do |t|
      t.integer :product_id, :references => :spree_products
      t.integer :role_id, :references => :spree_roles
    end
    add_index :spree_restrictions, ["product_id", "role_id"]
  end
end

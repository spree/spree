class ProductGroupsAndScopes < ActiveRecord::Migration
  def self.up
    create_table :product_groups do |t|
      t.string :name, :permalink, :order
    end

    create_table :product_scopes do |t|
      t.string   :name
      t.text     :arguments
      t.references :product_group
    end

    add_index :product_groups, :name
    add_index :product_groups, :permalink
    add_index :product_scopes, :name
    add_index :product_scopes, :product_group_id
  end

  def self.down
    drop_table :product_groups
    drop_table :product_scopes
  end
end

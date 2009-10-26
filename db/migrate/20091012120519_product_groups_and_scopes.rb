class ProductGroupsAndScopes < ActiveRecord::Migration
  def self.up
    create_table(:product_groups) do |t|
      t.column :name,       :string
      t.column :permalink,  :string
      t.column :order,      :string
    end

    create_table(:product_scopes) do |t|
      t.column :product_group_id, :integer
      t.column :name,             :string
      t.column :arguments,        :text
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

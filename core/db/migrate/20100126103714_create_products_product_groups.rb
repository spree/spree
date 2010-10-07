class CreateProductsProductGroups < ActiveRecord::Migration
  def self.up
    create_table :product_groups_products, :id => false do |t|
      t.references :product
      t.references :product_group
    end
  end
#product_group_memberships
  def self.down
    drop_table :product_groups_products
  end
end

class CreateProductsProductGroups < ActiveRecord::Migration
  def change
    create_table :product_groups_products, :id => false do |t|
      t.references :product
      t.references :product_group
    end
  end
end

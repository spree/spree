class AddVariantCountToSpreeProducts < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_products, :variant_count, :integer, default: 0, null: false
  end
end

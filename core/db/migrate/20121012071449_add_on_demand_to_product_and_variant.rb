class AddOnDemandToProductAndVariant < ActiveRecord::Migration[4.2]
  def change
  	add_column :spree_products, :on_demand, :boolean, default: false
  	add_column :spree_variants, :on_demand, :boolean, default: false
  end
end

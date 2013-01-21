class AddPositionToProductProperties < ActiveRecord::Migration
  def change
    add_column :spree_product_properties, :position, :integer, :default => 0
  end
end


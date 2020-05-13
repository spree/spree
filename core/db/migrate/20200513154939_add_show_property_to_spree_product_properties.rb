class AddShowPropertyToSpreeProductProperties < ActiveRecord::Migration[6.0]
  def change
      add_column :spree_product_properties, :show_property, :boolean, default: true
  end
end

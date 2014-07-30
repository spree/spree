class AddUncollapsibleLineItemToSpreeProduct < ActiveRecord::Migration
  def change
    add_column :spree_products, :uncollapsible_line_item, :boolean, default: false
  end
end

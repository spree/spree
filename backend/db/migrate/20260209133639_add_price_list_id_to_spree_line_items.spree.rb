# This migration comes from spree (originally 20251110120003)
class AddPriceListIdToSpreeLineItems < ActiveRecord::Migration[7.0]
  def change
    add_reference :spree_line_items, :price_list, null: true
  end
end

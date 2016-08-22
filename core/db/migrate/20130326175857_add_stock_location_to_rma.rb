class AddStockLocationToRma < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_return_authorizations, :stock_location_id, :integer
  end
end

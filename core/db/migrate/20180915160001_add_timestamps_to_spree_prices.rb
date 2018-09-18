class AddTimestampsToSpreePrices < ActiveRecord::Migration[5.2]
  def up
    add_timestamps :spree_prices, default: Time.current
    change_column_default :spree_prices, :created_at, nil
    change_column_default :spree_prices, :updated_at, nil
  end

  def down
    remove_column :spree_prices, :created_at
    remove_column :spree_prices, :updated_at
  end
end

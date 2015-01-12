class UpdateOrdersFromNilToDefaultCurrency < ActiveRecord::Migration
  def up
    Spree::Order.where(currency: nil).update_all(currency: Spree::Config[:currency])
  end

  def down
  end
end

class AddDeafultValueForStoreDefaultCurrency < ActiveRecord::Migration[6.0]
  def change
    Spree::Store.where(default_currency: nil).update_all(default_currency: Spree::Config[:currency])
  end
end

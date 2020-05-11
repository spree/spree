class AddSupportedCurrenciesToStore < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:spree_stores, :supported_currencies)
      add_column :spree_stores, :supported_currencies, :string
      Spree::Store.all.each do |store|
        store.update_attribute(:supported_currencies, store.default_currency)
      end
    end
  end
end

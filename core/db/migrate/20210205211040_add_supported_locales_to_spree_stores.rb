class AddSupportedLocalesToSpreeStores < ActiveRecord::Migration[5.2]
  def change
    unless column_exists?(:spree_stores, :supported_locales)
      add_column :spree_stores, :supported_locales, :string
      Spree::Store.reset_column_information
      Spree::Store.all.each do |store|
        store.update_attribute(:supported_locales, store.default_locale)
      end
    end
  end
end

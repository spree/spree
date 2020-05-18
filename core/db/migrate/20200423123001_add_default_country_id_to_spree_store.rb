class AddDefaultCountryIdToSpreeStore < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:spree_stores, :default_country_id)
      add_column :spree_stores, :default_country_id, :integer
      Spree::Store.reset_column_information
      Spree::Store.update_all(default_country_id: Spree::Config[:default_country_id])
    end
  end
end

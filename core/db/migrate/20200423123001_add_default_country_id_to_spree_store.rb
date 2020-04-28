class AddDefaultCountryIdToSpreeStore < ActiveRecord::Migration[6.0]
  def change
    unless column_exists?(:spree_stores, :default_country_id)
      add_column :spree_stores, :default_country_id, :integer
    end
  end
end

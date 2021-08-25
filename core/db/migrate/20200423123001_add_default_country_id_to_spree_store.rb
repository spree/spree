class AddDefaultCountryIdToSpreeStore < ActiveRecord::Migration[5.2]
  def change
    unless column_exists?(:spree_stores, :default_country_id)
      add_column :spree_stores, :default_country_id, :integer
      Spree::Store.reset_column_information

      default_country = Spree::Country.find_by(iso: Spree::Config[:default_country_iso])
      Spree::Store.update_all(default_country_id: default_country.id) if default_country.present?
    end
  end
end

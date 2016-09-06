class AddZipcodeRequiredToSpreeCountries < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_countries, :zipcode_required, :boolean, default: true
    Spree::Country.reset_column_information
    Spree::Country.where(iso: Spree::Address::NO_ZIPCODE_ISO_CODES).update_all(zipcode_required: false)
  end
end

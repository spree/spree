class AddDescriptionToSpreeCatalogs < ActiveRecord::Migration[8.1]
  def change
    # What the agreement is, in the operator's own words — never shown to a
    # shopper, like a price list's.
    add_column :spree_catalogs, :description, :text
  end
end

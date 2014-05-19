class AddDeletedAtToSpreeCountries < ActiveRecord::Migration
  def change
    add_column :spree_countries, :deleted_at, :datetime
  end
end

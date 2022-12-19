class EnableTaxonomiesWithoutName < ActiveRecord::Migration[7.0]
  def change
    change_column_null :spree_taxonomies, :name, true
  end
end

class AllowNullTaxonomyName < ActiveRecord::Migration[6.1]
  def change
    change_column_null :spree_taxonomies, :name, true
  end
end

class ChangeTaxonNameNullToTrue < ActiveRecord::Migration[6.1]
  def change
    change_column_null :spree_taxons, :name, true
  end
end

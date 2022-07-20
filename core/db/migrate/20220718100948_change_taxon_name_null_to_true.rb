class ChangeTaxonNameNullToTrue < ActiveRecord::Migration[7.0]
  def change
    change_column_null :spree_taxons, :name, true
  end
end

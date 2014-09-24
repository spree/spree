class AddCodeToSpreeTaxCategories < ActiveRecord::Migration
  def change
    add_column :spree_tax_categories, :tax_code, :string
  end
end

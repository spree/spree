class AddCodeToSpreeTaxCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_tax_categories, :tax_code, :string
  end
end

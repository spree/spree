class AddDefaultToTaxCategories < ActiveRecord::Migration
  def change
    add_column :tax_categories, :is_default, :boolean, :default => false
  end
end

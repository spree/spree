class AddDefaultToTaxCategories < ActiveRecord::Migration
  def self.up
    add_column :tax_categories, :is_default, :boolean, :default => false
  end

  def self.down
    remove_column :tax_categories, :is_default
  end
end
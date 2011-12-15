class RemoveDefaultTaxCategory < ActiveRecord::Migration
  def up
    remove_column :spree_tax_categories, :is_default
  end

  def down
  end
end

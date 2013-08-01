class AddGtinColumnToSpreeVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :gtin, :string
    add_index :spree_variants, :gtin
  end
end

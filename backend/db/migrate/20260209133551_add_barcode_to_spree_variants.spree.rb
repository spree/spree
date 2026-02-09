# This migration comes from spree (originally 20220222083546)
class AddBarcodeToSpreeVariants < ActiveRecord::Migration[5.2]
  def change
    add_column :spree_variants, :barcode, :string
    add_index :spree_variants, :barcode
  end
end

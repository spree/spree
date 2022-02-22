class AddBarcodeToSpreeVariants < ActiveRecord::Migration[7.0]
  def change
    add_column :spree_variants, :barcode, :string
    add_index :spree_variants, :barcode
  end
end

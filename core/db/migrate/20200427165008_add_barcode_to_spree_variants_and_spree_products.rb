class AddBarcodeToSpreeVariantsAndSpreeProducts < ActiveRecord::Migration[6.0]
  def change
    add_column :spree_variants, :barcode, :string
    add_column :spree_products, :barcode, :string
  end
end

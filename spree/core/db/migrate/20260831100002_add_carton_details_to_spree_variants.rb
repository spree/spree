class AddCartonDetailsToSpreeVariants < ActiveRecord::Migration[8.1]
  def change
    # The rest of the packing chain around +units_per_carton+, which
    # docs/plans/6.0-b2b-quantity-rules.md already added. Geometry lives on
    # the referenced carton row; only the per-product packing facts sit here.
    add_reference :spree_variants, :carton_package_type, index: true
    add_column :spree_variants, :carton_weight, :decimal, precision: 8, scale: 2
    add_column :spree_variants, :cartons_per_pallet, :integer
  end
end

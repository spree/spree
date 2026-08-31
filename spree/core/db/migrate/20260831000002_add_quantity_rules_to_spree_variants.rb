class AddQuantityRulesToSpreeVariants < ActiveRecord::Migration[8.1]
  def change
    # The base purchasing rules every cart obeys. Empty means today's
    # behaviour — buy one at a time, in units.
    add_column :spree_variants, :minimum_order_quantity, :integer
    add_column :spree_variants, :order_multiple, :integer

    # Commercial purchase vocabulary — 'unit' (nil) or 'carton'. Stored
    # quantities stay units at every level; this only changes what a buyer
    # is shown and stepped by.
    add_column :spree_variants, :purchase_unit, :string

    # The carton divisor. The rest of the packing chain
    # (carton_package_type_id, carton_weight, cartons_per_pallet) belongs to
    # docs/plans/6.0-b2b-wholesale-shipping.md and lands with it.
    add_column :spree_variants, :units_per_carton, :integer
  end
end

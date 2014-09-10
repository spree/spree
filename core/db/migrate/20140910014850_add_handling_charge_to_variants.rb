class AddHandlingChargeToVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :handling_charge, :decimal, precision: 10, scale: 2, default: 0.0
  end
end

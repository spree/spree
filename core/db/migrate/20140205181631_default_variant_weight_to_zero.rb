class DefaultVariantWeightToZero < ActiveRecord::Migration[4.2]
  def up
    Spree::Variant.unscoped.where(weight: nil).update_all("weight = 0.0")

    change_column :spree_variants, :weight, :decimal, precision: 8, scale: 2, default: 0.0
  end

  def down
    change_column :spree_variants, :weight, :decimal, precision: 8, scale: 2
  end
end

class AddWeightAndDimensionUnitsToSpreeVariants < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_variants, :weight_unit, :string
    add_column :spree_variants, :dimensions_unit, :string
  end
end

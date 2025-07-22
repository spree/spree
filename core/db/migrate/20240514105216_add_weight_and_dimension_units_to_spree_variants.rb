class AddWeightAndDimensionUnitsToSpreeVariants < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_variants, :weight_unit, :string, if_not_exists: true
    add_column :spree_variants, :dimensions_unit, :string, if_not_exists: true
  end
end

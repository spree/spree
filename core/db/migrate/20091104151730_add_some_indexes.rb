class AddSomeIndexes < ActiveRecord::Migration
  def change
    add_index :taxons, :permalink
    add_index :taxons, :parent_id
    add_index :taxons, :taxonomy_id
    add_index :assets, :viewable_id
    add_index :assets, [:viewable_type, :type]
    add_index :product_properties, :product_id
    add_index :option_values_variants, [:variant_id, :option_value_id]
  end
end

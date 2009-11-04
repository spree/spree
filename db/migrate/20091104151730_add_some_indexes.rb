class AddSomeIndexes < ActiveRecord::Migration
  def self.up
    add_index(:taxons, :permalink)
    add_index(:taxons, :parent_id)
    add_index(:taxons, :taxonomy_id)
    add_index(:assets, :viewable_id)
    add_index(:assets, [:viewable_type, :type])
    add_index(:product_properties, :product_id)
    add_index(:option_values_variants, [:variant_id, :option_value_id])
  end

  def self.down
    remove_index(:taxons, :permalink)
    remove_index(:taxons, :parent_id)
    remove_index(:taxons, :taxonomy_id)
    remove_index(:assets, :viewable_id)
    remove_index(:assets, [:viewable_type, :type])
    remove_index(:product_properties, :product_id)
    remove_index(:option_values_variants, [:variant_id, :option_value_id])
  end
end

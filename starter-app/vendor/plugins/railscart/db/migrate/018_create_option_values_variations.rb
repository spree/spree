class CreateOptionValuesVariations < ActiveRecord::Migration
  def self.up
    create_table :option_values_variations, :id=>false do |t| 
      t.integer :variation_id
      t.integer :option_value_id
    end
  end

  def self.down
    drop_table :option_values_variations
  end
end
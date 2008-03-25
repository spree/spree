class CreateOptionValuesVariants < ActiveRecord::Migration
  def self.up
    create_table :option_values_variants, :id=>false do |t| 
      t.integer :variant_id
      t.integer :option_value_id
    end
  end

  def self.down
    drop_table :option_values_variants
  end
end
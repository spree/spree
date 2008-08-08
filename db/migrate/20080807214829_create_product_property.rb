class CreateProductProperty < ActiveRecord::Migration
  def self.up
    rename_table :property_values, :product_properties
    #change_table :product_properties do |t|
    #  t.integer :position
    #end
  end

  def self.down
    rename_table :product_properties, :property_values
    #change_table :property_values do |t|
    #  t.remove :position
    #end
  end
end
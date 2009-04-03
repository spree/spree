class CreateShippingMethods < ActiveRecord::Migration
  def self.up
    create_table :shipping_methods do |t|
      t.references :zone
      t.string :shipping_calculator
      t.string :name
      t.timestamps
    end
  end

  def self.down
    drop_table :shipping_methods
  end
end

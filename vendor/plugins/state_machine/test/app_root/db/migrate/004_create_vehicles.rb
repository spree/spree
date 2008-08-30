class CreateVehicles < ActiveRecord::Migration
  def self.up
    create_table :vehicles do |t|
      t.references :highway, :null => false
      t.references :auto_shop, :null => false
      t.boolean :seatbelt_on, :null => false
      t.integer :insurance_premium, :null => false
      t.string :state, :null => false
      t.string :type
    end
  end
  
  def self.down
    drop_table :vehicles
  end
end

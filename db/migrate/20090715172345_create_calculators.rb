class CreateCalculators < ActiveRecord::Migration
  def self.up
    create_table :calculators do |t|
      t.string :type
      t.references :calculable, :polymorphic => true, :null => false
      t.timestamps
    end          
    change_table :shipping_methods do |t|
      t.remove :shipping_calculator
    end                                        
    ShippingMethod.all.each do |shipping_method|  
      Calculator::FlatRate.create(:calculable => shipping_method)
    end    
  end

  def self.down
    drop_table :calculators
    change_table :shipping_methods do |t|
      t.string :shipping_calculator
    end
  end
end

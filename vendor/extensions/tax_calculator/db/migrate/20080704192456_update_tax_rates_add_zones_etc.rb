class UpdateTaxRatesAddZonesEtc < ActiveRecord::Migration
  def self.up
    change_table :tax_rates do |t|
      t.rename :state_id, :zone_id
      t.integer :tax_type
      t.references :property_value
    end    
  end

  def self.down
    change_table :tax_rates do |t|
      t.rename :zone_id, :state_id
      t.remove_column :tax_type
      t.remove_column :property_value
    end    
  end
end

class DropTaxTreatments < ActiveRecord::Migration
  def self.up
    drop_table :tax_treatments
    drop_table :categories_tax_treatments
    drop_table :products_tax_treatments    
  end

  def self.down
    # No going back.
  end
end
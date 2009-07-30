class RemoveTaxType < ActiveRecord::Migration
  def self.up 
    change_table :tax_rates do |t|
      t.remove :tax_type
    end
  end

  def self.down
    change_table :tax_rates do |t|
      t.integer :tax_type
    end
  end
end

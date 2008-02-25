class CreateVariations < ActiveRecord::Migration
  def self.up
    create_table :variations do |t| 
      t.integer :product_id
    end
  end

  def self.down
    drop_table :variations
  end
end
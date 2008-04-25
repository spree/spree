class CreateVariants < ActiveRecord::Migration
  def self.up
    create_table :variants do |t| 
      t.integer :product_id
      t.string :sku, :default => "", :null => false
      t.decimal :price, :precision => 8, :scale => 2, :null => false
    end
  end

  def self.down
    drop_table :variants
  end
end
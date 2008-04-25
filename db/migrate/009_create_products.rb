class CreateProducts < ActiveRecord::Migration
  def self.up
	  create_table :products do |t|
	    t.string :name, :default => "", :null => false
	    t.text :description
	    t.decimal :master_price, :precision => 8, :scale => 2
	    t.integer :category_id
      t.integer :viewable_id
      t.timestamps
    end
  end

  def self.down
    drop_table "products"
  end
end
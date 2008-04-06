class CreateProducts < ActiveRecord::Migration
  def self.up
	  create_table :products do |t|
	    t.string :name, :default => "", :null => false
	    t.string :description
	    t.decimal :price, :precision => 8, :scale => 2, :null => false
	    t.integer :category_id
      t.integer :viewable_id
      t.timestamps
    end
  end

  def self.down
    drop_table "products"
  end
end
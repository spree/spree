class CreateProducts < ActiveRecord::Migration
  def self.up
	  create_table "products",  :force => true do |t|
      t.column "name",        :string,  :limit => 100,                               :default => "",  :null => false
      t.column "description", :text                                                 
      t.column "price",       :decimal, :precision => 8, :scale => 2,                 :null => false
      t.column "category_id", :integer
      t.column "width",       :float,                                                :default => 0.0, :null => false
      t.column "height",      :float,                                                :default => 0.0, :null => false
      t.column "depth",       :float,                                                :default => 0.0, :null => false
      t.column "weight",      :float,                                                :default => 0.0, :null => false
      t.integer :viewable_id
      t.timestamps
    end
  end

  def self.down
    drop_table "products"
  end
end
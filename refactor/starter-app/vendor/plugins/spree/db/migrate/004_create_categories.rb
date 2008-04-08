class CreateCategories < ActiveRecord::Migration
  def self.up
	  create_table "categories", :force => true do |t|
	    t.column "name",      :string,  :default => "", :null => false
	    t.column "parent_id", :integer
      t.column "position",  :integer, :null => false
      t.column :created_at,   :datetime
      t.column :updated_at,   :datetime
	  end
  end

  def self.down
    drop_table "categories"
  end
end
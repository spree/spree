class CreateOptionValues < ActiveRecord::Migration
  def self.up
	  create_table :option_values do |t| 
      t.integer :option_type_id
      t.string :name
      t.integer :position
      t.string :presentation
      t.timestamps
	  end
  end

  def self.down
    drop_table :option_values
  end
end
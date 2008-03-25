class CreateVariants < ActiveRecord::Migration
  def self.up
    create_table :variants do |t| 
      t.integer :product_id
    end
  end

  def self.down
    drop_table :variants
  end
end
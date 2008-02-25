class CreateProductOptionTypes < ActiveRecord::Migration
  def self.up
    create_table :product_option_types do |t|
      t.integer :product_id
      t.integer :option_type_id
      t.integer :position
      t.timestamps
    end
  end

  def self.down
    drop_table :product_option_types
  end
end
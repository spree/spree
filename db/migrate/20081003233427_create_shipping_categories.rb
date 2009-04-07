class CreateShippingCategories < ActiveRecord::Migration
  def self.up
    create_table :shipping_categories do |t|
      t.string :name
      t.timestamps
    end
    
    add_column :products, :shipping_category_id, :integer, :default => nil
  end

  def self.down
    drop_table :shipping_categories
    remove_column :products, :shipping_category_id
  end
end

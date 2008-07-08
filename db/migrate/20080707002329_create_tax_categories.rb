class CreateTaxCategories < ActiveRecord::Migration
  def self.up
    create_table :tax_categories, :force => true do |t|
      t.string :name
      t.string :description
      t.timestamps
    end
    
    change_table :products do |t|
      t.references :tax_category
    end
    
  end

  def self.down
    drop_table :tax_categories
    change_table :products do |t|
      t.remove :tax_category_id
    end
  end
end

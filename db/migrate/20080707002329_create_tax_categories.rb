class CreateTaxCategories < ActiveRecord::Migration
  def self.up
    create_table :tax_categories, :force => true do |t|
      t.string :name
      t.string :description
      t.timestamps
    end
  end

  def self.down
    drop_table :tax_categories
  end
end

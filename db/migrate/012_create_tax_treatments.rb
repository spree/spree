class CreateTaxTreatments < ActiveRecord::Migration
  def self.up
    create_table :tax_treatments do |t|
      t.column :name, :string
    end

    create_table :products_tax_treatments, :id => false do |t|
      t.column :product_id, :integer
      t.column :tax_treatment_id, :integer
    end

    create_table :categories_tax_treatments, :id => false do |t|
      t.column :category_id, :integer
      t.column :tax_treatment_id, :integer
    end
  end

  def self.down
    # Don't drop these since they are now dropped by migration 025
    #drop_table :tax_treatments
    #drop_table :categories_tax_treatments
    #drop_table :products_tax_treatments
  end
end

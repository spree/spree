class CreateSpreeStoreCreditCategories < ActiveRecord::Migration
  def change
    create_table :spree_store_credit_categories do |t|
      t.string :name
      t.timestamps null: false
    end
  end
end

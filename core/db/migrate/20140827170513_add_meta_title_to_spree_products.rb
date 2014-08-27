class AddMetaTitleToSpreeProducts < ActiveRecord::Migration
  def change
    change_table :spree_products do |t|
      t.string   :meta_title
    end
  end
end

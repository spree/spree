class ChangeMetaDescriptionOnSpreeProductsToText < ActiveRecord::Migration
  def change
    change_column :spree_products, :meta_description, :text, :limit => nil
  end
end

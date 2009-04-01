class MetaDataFieldsForProducts < ActiveRecord::Migration
  def self.up
    add_column "products", "meta_description", :string
    add_column "products", "meta_keywords", :string
  end

  def self.down
    remove_column "products", "meta_description"
    remove_column "products", "meta_keywords"
  end
end
